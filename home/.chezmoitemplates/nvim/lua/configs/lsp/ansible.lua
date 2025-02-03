local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

local common = require("utils.common")

M.treesitter.filetypes = { "yaml" }

-- INFO: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ansiblels
local ansiblels = LspConfig:new("ansiblels")
ansiblels.server = "ansiblels"

-- NOTE: ansible-lint is not supported on Windows
-- INFO: https://ansible.readthedocs.io/projects/lint/installing/
if common.IS_WINDOWS then
	ansiblels.settings = {
		validation = {
			lint = {
				enabled = false,
			},
		},
	}
else
	-- INFO: https://github.com/ansible/ansible-lint
	M.linterconfig.servers = { "ansible-lint" }
end

M.lspconfigs = { ansiblels }

return M
