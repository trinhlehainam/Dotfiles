--- @class custom.LspConfig
local M = {}

--- Create a new LSP configuration instance
--- @param server string? The name of the LSP server used for Neovim LSP to enable the server (e.g., "lua_ls", "typescript-language-server", "pyright")
--- @param mason_package MasonToolEntry? The name of the server package registered in Mason, used to tell Mason what LSP server binary to install (e.g., "lua-language-server", "typescript-language-server", "pyright")
--- @return custom.LspConfig A new LspConfig instance with the specified server and Mason package configuration
---
--- @usage
--- -- Basic usage with server name only
--- local lua_config = LspConfig:new("lua_ls")
---
--- -- Full configuration with both server and Mason package
--- local ts_config = LspConfig:new("tsserver", "typescript-language-server")
---
--- -- Configure LSP server settings
--- ts_config.config = {
---   on_attach = function(client, bufnr)
---     -- Custom attach logic
---   end,
---   settings = {
---     typescript = {
---       inlayHints = {
---         includeInlayParameterNameHints = "all"
---       }
---     }
---   }
--- }
function M:new(server, mason_package)
  local t = setmetatable({}, { __index = M })
  t.server = server
  t.mason_package = mason_package
  t.config = {}
  t.setup = nil
  return t
end

return M
