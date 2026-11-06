local M = {}
local configured = false

function M.setup()
  if configured then
    return
  end
  configured = true
  local languages = require('configs.lsp')
  local mason = require('mason-registry')
  local installer = require('utils.mason_install')
  local enabled = {}
  local pending = {}

  local function enable_ready(servers)
    local ready = {}
    for name in vim.spairs(servers) do
      if not enabled[name] then
        local installed = true
        for _, package in ipairs(languages.server_tools[name] or {}) do
          installed = installed and installer.is_ready(package)
        end
        if installed then
          enabled[name] = true
          ready[#ready + 1] = name
        end
      end
    end
    if #ready > 0 then
      -- Native enable checks existing buffers and reuses clients; never replay all FileType hooks.
      vim.lsp.enable(ready)
    end
  end

  local function matches(buf, language)
    return vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ''
      and vim.tbl_contains(language.filetypes, vim.bo[buf].filetype)
      and (not language.condition or language.condition(buf))
  end

  local function activate(buf, installed_package)
    if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= '' then
      return
    end
    for _, language in ipairs(languages.by_filetype[vim.bo[buf].filetype] or {}) do
      pending[language] = pending[language] or {}
      local relevant = not installed_package
        or (language.on_ready and vim.tbl_contains(language.tools or {}, installed_package))
      if relevant and matches(buf, language) and not pending[language][buf] then
        pending[language][buf] = true
        installer.ensure(language.tools or {}, function(success)
          pending[language][buf] = nil
          enable_ready(language.servers or {})
          if success and language.on_ready and matches(buf, language) then
            vim.api.nvim_buf_call(buf, function()
              language.on_ready(buf)
            end)
          end
        end)
      end
    end
  end

  local function catch_up(installed_package)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      activate(buf, installed_package)
    end
  end

  -- A manual :MasonInstall retry also activates servers and plugin-owned buffers.
  mason:on(
    'package:install:success',
    vim.schedule_wrap(function(pkg)
      enable_ready(languages.servers)
      catch_up(pkg.name)
    end)
  )
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('dotfiles-language-install', { clear = true }),
    callback = function(event)
      activate(event.buf)
    end,
  })
  enable_ready(languages.servers)
  catch_up()
end

return M
