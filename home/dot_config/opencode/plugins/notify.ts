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

// `session.idle` only gives `sessionID`, so keep the latest useful context here
// and render it when the session finishes.
const sessions = new Map<string, SessionContext>()

// OpenCode permission payloads differ between published plugin types and newer
// runtime/docs. Normalize the small shared shape we need for notifications.
type PermissionLike = {
  sessionID: string
  title?: string
  type?: string
  permission?: string
  pattern?: string | string[]
  patterns?: string[]
}

type PermissionAskedEvent = {
  type: "permission.asked"
  properties: PermissionLike
}

function projectName(directory: string): string {
  const parts = directory.replace(/[\\/]+$/, "").split(/[\\/]/)
  return parts[parts.length - 1] ?? ""
}

function clip(text: string, max = 140): string {
  const trimmed = text.replace(/\s+/g, " ").trim()
  if (max <= 3) return trimmed.slice(0, max)
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
  if (permission.title) return permission.title

  const kind = permission.type ?? permission.permission ?? "permission"
  const pattern = Array.isArray(permission.pattern)
    ? permission.pattern.join(", ")
    : permission.pattern ?? permission.patterns?.join(", ") ?? "*"
  return `${kind} (${pattern})`
}

function isPermissionAskedEvent(
  event: { type: string; properties?: unknown },
): event is PermissionAskedEvent {
  if (event.type !== "permission.asked") return false
  if (typeof event.properties !== "object" || event.properties === null) return false
  return typeof (event.properties as PermissionLike).sessionID === "string"
}

async function notify(
  $: Parameters<Plugin>[0]["$"],
  session: SessionContext,
  body: string,
): Promise<void> {
  try {
    await $`${NOTIFY_BIN} -t ${titleFor(session)} -b ${body}`
  } catch (error) {
    console.error("notify.ts: agent-notify failed", error)
  }
}

async function notifyPermission(
  $: Parameters<Plugin>[0]["$"],
  permission: PermissionLike,
): Promise<void> {
  const session = getSession(permission.sessionID, "")
  session.pendingPermission = permissionBody(permission)
  await notify($, session, `Permission required: ${session.pendingPermission}`)
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
        await notifyPermission($, event.properties)
        return
      }

      // Newer OpenCode runtimes emit `permission.asked` before the published
      // `@opencode-ai/plugin` package types fully catch up.
      const permissionAskedEvent = event as { type: string; properties?: unknown }
      if (isPermissionAskedEvent(permissionAskedEvent)) {
        await notifyPermission($, permissionAskedEvent.properties)
        return
      }

      if (event.type === "session.error") {
        const sessionID = event.properties.sessionID
        const session = sessionID ? getSession(sessionID, "") : { project: "" }
        const body = session.lastText ? `Session error after: ${session.lastText}` : "Session error"
        try {
          await notify($, session, body)
        } finally {
          if (sessionID) sessions.delete(sessionID)
        }
        return
      }

      if (event.type === "session.idle") {
        const session = getSession(event.properties.sessionID, "")
        try {
          await notify($, session, idleBody(session))
        } finally {
          sessions.delete(event.properties.sessionID)
        }
      }
    },
    "permission.ask": async (input) => {
      await notifyPermission($, input)
    },
  }
}
