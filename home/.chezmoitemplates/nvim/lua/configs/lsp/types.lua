---LuaLS Anotations
--- INFO: https://github.com/LuaLS/lua-language-server/wiki/Annotations

---@alias custom.NeotestAdapterSetup fun(): neotest.Adapter

---@class custom.TreeSitter
---@field filetypes? string[]

---@class custom.LspConfig
-- Use `mason-lspconfig` to install LSP
-- Reference available LSP that can be installed by `mason-lspconfig` here:
-- https://github.com/williamboman/mason-lspconfig.nvim?tab=readme-ov-file#available-lsp-servers
---@field server? string
---@field config vim.lsp.Config

---@class custom.DapConfig
-- Use `mason-nvim-dap` to install DAP
-- Reference available DAP that can be installed by `mason-nvim-dap` here:
-- https://github.com/jay-babu/mason-nvim-dap.nvim/blob/main/lua/mason-nvim-dap/mappings/source.lua
---@field type? string
--- Use `mason-nvim-dap` handlers to configure DAP
--- https://github.com/jay-babu/mason-nvim-dap.nvim?tab=readme-ov-file#advanced-customization
---@field setup? fun()
---@field use_masondap_default_setup boolean

-- Use `conform.nvim` to automatically configure Formatter commands
-- Reference available Formatter that can be configured by `conform.nvim` here:
-- https://github.com/stevearc/conform.nvim?tab=readme-ov-file#formatters
---@class custom.FormatterConfig
-- Installed by `mason.nvim`
---@field servers? string[]
---@field formatters_by_ft? table<string, table>

-- Use `nvim-lint` to automatically configure Linter commands
-- Reference available Linter that can be configured by `nvim-lint` here:
-- https://github.com/mfussenegger/nvim-lint?tab=readme-ov-file#available-linters
---@class custom.LinterConfig
-- Installed by `mason.nvim`
---@field servers? string[]
---@field linters_by_ft? table<string, table>

---@class custom.LanguageSetting
---@field treesitter custom.TreeSitter
---@field lspconfigs custom.LspConfig[]
---@field dapconfig custom.DapConfig
---@field formatterconfig custom.FormatterConfig
---@field linterconfig custom.LinterConfig
---@field after_masonlsp_setup? fun()
--- https://github.com/nvim-neotest/neotest?tab=readme-ov-file#supported-runners
---@field neotest_adapter_setup? custom.NeotestAdapterSetup
--- rustaceanvim requires vim.g.rustaceanvim to override default configurations at plugin initialization
---@field plugin_setups? table<string, fun()>

--- @class custom.Lsp
--- @field treesitters custom.TreeSitter[]
--- @field lspconfigs custom.LspConfig[]
--- @field dapconfigs table<string, custom.DapConfig>
--- @field formatters custom.FormatterConfig[]
--- @field linters custom.LinterConfig[]
--- @field after_masonlsp_setups fun()[]
--- @field get_neotest_adapters fun(): custom.NeotestAdapterSetup[]
--- @field plugin_setups table<string, fun()>
