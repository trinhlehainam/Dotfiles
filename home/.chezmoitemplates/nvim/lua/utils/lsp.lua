local M = {
	---@type fun(client: lsp.Client, bufnr: integer)
	on_attach = nil,
}

--- nvim-cmp supports additional completion capabilities, so broadcast that to servers
--- @return lsp.ClientCapabilities
local function get_cmp_capabilities()
	local hascmplsp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
	local capabilities = vim.lsp.protocol.make_client_capabilities()
	if not hascmplsp then
		require("utils.log").error("cmp_nvim_lsp is not installed")
		return capabilities
	end
	capabilities = cmp_nvim_lsp.default_capabilities(capabilities)

	return capabilities
end

---This function gets run when an LSP connects to a particular buffer.
---@param client lsp.Client
---@param bufnr number
local function on_attach(client, bufnr)
	-- NOTE: Remember that lua is a real programming language, and as such it is possible
	-- to define small helper and utility functions so you don't have to repeat yourself
	-- many times.
	--
	-- In this case, we create a function that lets us more easily define mappings specific
	-- for LSP related items. It sets the mode, buffer and description for us each time.
	local nmap = require("utils.common").create_nmap(bufnr)

	nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
	nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")

	nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
	nmap("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
	nmap("gI", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
	nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
	nmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
	nmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

	-- See `:help K` for why this keymap
	if vim.fn.has("nvim-0.10.0") == 0 then
		nmap("K", vim.lsp.buf.hover, "Hover Documentation")
	end

	-- Lesser used LSP functionality
	nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
	nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
	nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
	nmap("<leader>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, "[W]orkspace [L]ist Folders")

	-- Create a command `:Format` local to the LSP buffer
	vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
		local hasconform, conform = pcall(require, "conform")
		if hasconform then
			conform.format({ async = true, bufnr = bufnr })
		else
			vim.lsp.buf.format()
		end
	end, { desc = "Format current buffer with LSP" })

	-- Create a command `:Lint` local to the LSP buffer
	vim.api.nvim_buf_create_user_command(bufnr, "Lint", function(_)
		local haslint, lint = pcall(require, "lint")
		if haslint then
			lint.try_lint()
		end
	end, { desc = "Lint current buffer with LSP" })

	local hasnavic, navic = pcall(require, "nvim-navic")
	if not hasnavic then
		return
	end

	-- INFO: https://github.com/SmiteshP/nvim-navic?tab=readme-ov-file#%EF%B8%8F-setup
	if client.server_capabilities.documentSymbolProvider then
		navic.attach(client, bufnr)
	end
end

M.on_attach = on_attach
M.get_cmp_capabilities = get_cmp_capabilities

return M
