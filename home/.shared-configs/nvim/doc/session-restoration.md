# Session restoration

auto-session restores saved sessions at startup or through `<leader>wr`.
`<leader>ws` saves a session and `<leader>wa` toggles automatic saving.

## Swap protection

Neovim's `:mksession` scripts recreate special buffers, including Markdown Reader
views, by naming an empty placeholder with `:file`. This can open a swap file
before the buffer's no-swap options are restored. A stale swap for a Reader URI
then interrupts restoration and causes auto-session to disable automatic saving.

The `BufFilePre` hook in `lua/plugins/auto-session.lua` disables swap only when
auto-session is restoring and the buffer still has no name. At this event the
new name is not yet available through `nvim_buf_get_name`, so a Reader URI check
would miss the placeholder. Regular files restored with `:edit` retain normal
swap protection, including warnings about existing swap files. No stale swap
files are deleted by this hook.

The guard uses auto-session's `restore_in_progress` flag because the plugin clears
it after sourcing either a successful or a failing session script. Neovim's
`g:SessionLoad` can remain set after a failure; using it would also disable swap
when the user later names an ordinary buffer. The guard applies to restores
through auto-session, not sessions loaded manually with `:source`.

## Markdown Reader recovery

`lua/plugins/markdown-table-wrap.lua` loads the Reader plugin on `SessionLoadPre`
as well as on Markdown filetypes. A saved Reader view may be the only visible
buffer, so Markdown filetype detection alone cannot register its recovery hooks
in time. The plugin's `SessionLoadPost` hook finds the placeholder and schedules
replacement with its source file after the session script finishes. The source
keeps swap protection; the temporary Reader view does not need a swap file.

## Verification

Run `make test` from `home/.shared-configs/nvim/`; see the
[test setup](../tests/README.md) for required local plugin checkouts.
`auto_session_spec.lua` covers stale placeholder swaps, normal file swap
protection, renaming a named buffer during restore, and recovery after a failed
restore. `reader_session_spec.lua` starts an isolated Neovim with the real
lazy.nvim and Reader plugins, restores a session
without a Markdown startup file, and checks the recovered source and its swap
option. When upgrading these plugins, keep both tests passing.

`restore_in_progress` is internal auto-session state. If the stale-placeholder
or failed-restore test fails after an upgrade, first check that the field still
exists and is cleared after both successful and failed restores. A flag set by `pre_restore`
and cleared by `post_restore` hooks is not equivalent: a failed restore can
return before the post hook runs.
