if vim.fn.executable('ansible') == 0 then
  require('utils.log').info('Ansible support requires an ansible installation')
  return {}
end

vim.filetype.add({
  pattern = {
    ['.*/playbooks/.*%.ya?ml'] = 'yaml.ansible', -- yaml files under /playbooks/ directory
    ['.*%.ansible%.ya?ml'] = 'yaml.ansible', -- files with the following double extension: .ansible.yml or .ansible.yaml.
    ['site%.ya?ml'] = 'yaml.ansible', -- notable yaml names recognized by ansible like site.yml or site.yaml
    ['.*playbook.*%.ya?ml'] = 'yaml.ansible', -- yaml files having playbook in their filename: *playbook*.yml or *playbook*.yaml
  },
})

---@type dotfiles.lsp.Language
local M = {
  parsers = { 'yaml' },
  tools = { 'ansible-language-server' },
  servers = { ansiblels = {} },
}

-- ansible-lint is not supported on Windows.
if require('utils.common').IS_WINDOWS then
  M.servers.ansiblels = {
    settings = {
      validation = {
        lint = {
          enabled = false,
        },
      },
    },
  }
else
  table.insert(M.tools, 'ansible-lint')
end

return M
