local obsidian = require('utils.obsidian')

local function is_vault()
  return obsidian.is_vault(0)
end

return {
  'obsidian-nvim/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  ft = 'markdown',
  cond = is_vault,
  --- https://github.com/obsidian-nvim/obsidian.nvim/blob/main/lua/obsidian/config/default.lua
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- this will be removed in the next major release
    ui = { enable = false }, -- avoid conflict with render-markdown.nvim
    frontmatter = {
      enabled = false,
    },
    statusline = {
      enabled = false,
    },
    workspaces = {
      {
        name = vim.fs.basename(obsidian.vault_root(0) or vim.fn.getcwd()) or 'dynamic',
        path = function()
          return obsidian.vault_root(0) or vim.fn.getcwd()
        end,
      },
    },
    picker = {
      name = 'snacks.pick',
    },
    attachments = {},
  },
  init = function()
    local group = vim.api.nvim_create_augroup('ObsidianFooterToggle', { clear = true })

    local function set_footer_state(buf, enabled)
      if not vim.api.nvim_buf_is_valid(buf) or not vim.b[buf].obsidian_buffer then
        return
      end

      local state = rawget(_G, 'Obsidian')
      if not (state and state.opts and state.opts.footer) then
        return
      end

      state.opts.footer.enabled = enabled

      if not enabled then
        pcall(vim.api.nvim_del_augroup_by_name, 'obsidian_footer')
        vim.api.nvim_buf_clear_namespace(
          buf,
          vim.api.nvim_create_namespace('ObsidianFooter'),
          0,
          -1
        )
        return
      end

      require('obsidian.footer').start()
      vim.api.nvim_buf_call(buf, function()
        vim.api.nvim_exec_autocmds('User', {
          pattern = 'ObsidianNoteEnter',
          group = 'obsidian_footer',
        })
      end)
    end

    vim.api.nvim_create_autocmd('InsertEnter', {
      group = group,
      callback = function(ev)
        set_footer_state(ev.buf, false)
      end,
    })

    vim.api.nvim_create_autocmd('InsertLeave', {
      group = group,
      callback = function(ev)
        set_footer_state(ev.buf, true)
      end,
    })
  end,
  keys = {
    {
      '<leader>sf',
      function()
        if not is_vault() then
          return
        end
        vim.cmd('Obsidian quick_switch')
      end,
      desc = 'Obsidian: Quick switch',
    },
    {
      '<leader>sg',
      function()
        if not is_vault() then
          return
        end
        vim.cmd('Obsidian search')
      end,
      desc = 'Obsidian: Grep notes',
    },
  },
}
