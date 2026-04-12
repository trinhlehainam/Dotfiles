import type { Plugin } from "@opencode-ai/plugin"

const NOTIFY_BIN = `${process.env.HOME}/.local/bin/agent-notify`

type SessionContext = {
  project: string
  cwd?: string
  model?: string
  lastText?: string
  lastTool?: string
  pendingPermission?: string
}

const sessions = new Map<string, SessionContext>()

type PermissionLike = {
  sessionID: string
  type?: string
  permission?: string
  pattern?: string | string[]
  patterns?: string[]
}

function projectName(directory: string): string {
  const parts = directory.replace(/[\\/]+$/, "").split(/[\\/]/)
  return parts[parts.length - 1] ?? ""
}

function clip(text: string, max = 140): string {
  const trimmed = text.replace(/\s+/g, " ").trim()
  return trimmed.length > max ? `${trimmed.slice(0, max - 3)}...` : trimmed
}

function getSession(sessionID: string, project: string): SessionContext {
  const current = sessions.get(sessionID)
  if (current) return current
  const created: SessionContext = { project }
  sessions.set(sessionID, created)
  return created
}

function titleFor(session: SessionContext): string {
  const project = projectName(session.cwd ?? session.project) || session.project
  return project ? `OpenCode — ${project}` : "OpenCode"
}

function idleBody(session: SessionContext): string {
  const detail = session.lastText ?? session.lastTool ?? "Task complete"
  return session.model ? `${session.model} · ${detail}` : detail
}

function permissionBody(permission: PermissionLike): string {
  const kind = permission.type ?? permission.permission ?? "permission"
  const pattern = Array.isArray(permission.pattern)
    ? permission.pattern.join(", ")
    : permission.pattern ?? permission.patterns?.join(", ") ?? "*"
  return `${kind} (${pattern})`
}

export const NotifyPlugin: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "message.updated" && event.properties.info.role === "assistant") {
        const info = event.properties.info
        const session = getSession(info.sessionID, projectName(info.path.cwd))
        session.cwd = info.path.cwd
        session.model = `${info.providerID}/${info.modelID}`
      }

      if (event.type === "message.part.updated") {
        const { part } = event.properties
        const session = getSession(part.sessionID, "")

        if (part.type === "text" && part.time?.end) {
          session.lastText = clip(part.text)
        }

        if (part.type === "tool" && (part.state.status === "completed" || part.state.status === "error")) {
          session.lastTool = `${part.tool} ${part.state.status}`
        }
      }

      if (event.type === "permission.updated") {
        const session = getSession(event.properties.sessionID, "")
        session.pendingPermission = permissionBody(event.properties)
        await $`${NOTIFY_BIN} -t ${titleFor(session)} -b ${`Permission required: ${session.pendingPermission}`}`
        return
      }

      const permissionAsked = event as { type: string; properties: PermissionLike }
      if (permissionAsked.type === "permission.asked") {
        const session = getSession(permissionAsked.properties.sessionID, "")
        session.pendingPermission = permissionBody(permissionAsked.properties)
        await $`${NOTIFY_BIN} -t ${titleFor(session)} -b ${`Permission required: ${session.pendingPermission}`}`
        return
      }

      if (event.type === "session.error") {
        const sessionID = event.properties.sessionID
        const session = sessionID ? getSession(sessionID, "") : { project: "" }
        const body = session.lastText ? `Session error after: ${session.lastText}` : "Session error"
        await $`${NOTIFY_BIN} -t ${titleFor(session)} -b ${body}`
        if (sessionID) sessions.delete(sessionID)
        return
      }

      if (event.type === "session.idle") {
        const session = getSession(event.properties.sessionID, "")
        await $`${NOTIFY_BIN} -t ${titleFor(session)} -b ${idleBody(session)}`
        sessions.delete(event.properties.sessionID)
      }
    },
    "permission.ask": async (input) => {
      const session = getSession(input.sessionID, "")
      session.pendingPermission = permissionBody(input)
      await $`${NOTIFY_BIN} -t ${titleFor(session)} -b ${`Permission required: ${session.pendingPermission}`}`
    },
  }
}
