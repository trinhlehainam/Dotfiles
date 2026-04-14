import type { Plugin } from "@opencode-ai/plugin"

const NOTIFY_BIN = process.env.OPENCODE_NOTIFY_BIN ?? `${process.env.HOME}/.local/bin/agent-notify`
const NOTIFY_DISABLED =
  process.env.OPENCODE_AGENT_NOTIFY_DISABLED === "1" ||
  process.env.OPENCODE_NOTIFY_TRANSPORT === "host-nvim"

export const NotifyPlugin: Plugin = async () => {
  if (NOTIFY_DISABLED) return {}

  return {
    event: async ({ event }) => {
      try {
        const json = JSON.stringify(event)
        const proc = Bun.spawn([NOTIFY_BIN, "--format", "opencode-event", "--stdin"], {
          stdin: "pipe",
        })
        proc.stdin.write(json)
        proc.stdin.end()
        await proc.exited
      } catch (error) {
        console.error("notify.ts: agent-notify failed", error)
      }
    },
  }
}
