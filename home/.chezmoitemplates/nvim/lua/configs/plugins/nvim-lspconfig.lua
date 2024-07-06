-- INFO: make sure to setup neodev BEFORE lspconfig
local neodev = require("neodev")
neodev.setup({})

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
-- Prefer Telescope Diagnostic
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

vim.diagnostic.config({
	virtual_text = false,
})

-- Custom Diagnostic Signs
local signs = { Error = "", Warn = "", Hint = "", Info = "" }
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

-- Putting vim lsp settings inside on_attach is no longer a best pratice
-- Instead use `LspAttach` event in an autocmd
-- See https://vinnymeller.com/posts/neovim_nightly_inlay_hints/#rust-toolsnvim-inlay-hints
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(args)
		local log = require("utils.log")

		if vim.version.range("<0.10.0"):has(vim.version()) then
			log.info("Current Neovim version: " .. vim.inspect(vim.version()))
			log.warn("Inlay hints require Neovim >=0.10")
			return
		end

		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client.server_capabilities.inlayHintProvider then
			vim.keymap.set("n", "th",
				function()
					vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
				end,
				{ buffer = args.buf, desc = "[T]oggle inlay [h]ints" })
		end
		-- whatever other lsp config you want
	end
})

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
--  See https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local servers = {
	dockerls = {},
	powershell_es = {},
	html = {},
	lua_ls = {
		Lua = {
			workspace = { checkThirdParty = false },
			telemetry = { enable = false },
			completion = { callSnippet = "Replace" },
		},
	},
}

local lspconfigs = require('configs.lsp').lspconfigs

local on_attach = require('utils.lsp').on_attach

---@class custom.LspSetupHandler
---@field use_masonlsp_setup boolean
---@field setup? custom.LspConfig.Setup

---@type table<string, custom.LspSetupHandler>
local setup_handlers = {}

for server_name, _ in pairs(servers) do
	setup_handlers[server_name] = {
		use_masonlsp_setup = true,
	}
end

for _, lspconfig in pairs(lspconfigs) do
	local server_name = lspconfig.server
	if type(server_name) ~= "string" or server_name == "" then
		goto continue
	end
	servers[server_name] = lspconfig.settings

	local setup = lspconfig.setup
	local use_masonlsp_setup = lspconfig.use_masonlsp_setup
	setup_handlers[server_name] = {
		use_masonlsp_setup = use_masonlsp_setup,
		setup = setup
	}

	::continue::
end

local capabilities = require("utils.lsp").get_cmp_capabilities()

-- Setup mason so it can manage external tooling
require('mason').setup({
	inlay_hints = { enalbed = true },
})

-- Ensure the servers above are installed
local mason_lspconfig = require('mason-lspconfig')
mason_lspconfig.setup {
	ensure_installed = vim.tbl_keys(servers),
}

local lspconfig = require('lspconfig')
mason_lspconfig.setup_handlers {
	function(server_name)
		if vim.tbl_get(setup_handlers, server_name) == nil then
			return
		end
		local use_masonlsp_setup = setup_handlers[server_name].use_masonlsp_setup
		if not use_masonlsp_setup then
			return
		end

		local setup = setup_handlers[server_name].setup
		if type(setup) == "function" then
			setup(capabilities, on_attach)
		else
			lspconfig[server_name].setup {
				capabilities = capabilities,
				on_attach = on_attach,
				settings = servers[server_name],
			}
		end
	end,
}
-- Language server for Postgres written in Rust
-- NOTE: This framework is not production ready yet, check back later
-- lspconfig.postgres_lsp.setup{}
--
