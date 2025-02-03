local LanguageSetting = require("configs.lsp.base")
local LspConfig = require("configs.lsp.lspconfig")
local M = LanguageSetting:new()

local common = require("utils.common")

M.treesitter.filetypes = { "yaml" }

-- INFO: https://github.com/ansible/vscode-ansible?tab=readme-ov-file#without-file-inspection
-- INFO: https://docs.ansible.com/ansible/latest/tips_tricks/sample_setup.html#sample-directory-layout
vim.filetype.add({
	pattern = {
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible", -- yaml files under /playbooks/ directory
		[".*%.ansible%.ya?ml"] = "yaml.ansible", -- files with the following double extension: .ansible.yml or .ansible.yaml.
		["site%.ya?ml"] = "yaml.ansible", -- notable yaml names recognized by ansible like site.yml or site.yaml
		[".*playbook.*%.ya?ml"] = "yaml.ansible", -- yaml files having playbook in their filename: *playbook*.yml or *playbook*.yaml
	},
})

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
