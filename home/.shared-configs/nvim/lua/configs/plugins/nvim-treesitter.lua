local ts = require('nvim-treesitter')
local merge_unique = require('utils.common').merge_unique_strings
local ui_parsers = require('configs.plugins.noice').parsers
local parsers = merge_unique({
  'c',
  'lua',
  'vim',
  'vimdoc',
  'query',
  'markdown',
  'markdown_inline',
  'dockerfile',
  'sql',
}, require('configs.lsp').parsers)
parsers = merge_unique(parsers, ui_parsers)

-- Upstream installs query dependencies; these are common embedded languages.
-- Keep this bounded: a Markdown code fence must not download an arbitrary toolchain.
local companions = {
  html = { 'javascript', 'css', 'jsdoc', 'regex' },
  javascript = { 'jsdoc', 'regex' },
  typescript = { 'jsdoc', 'regex' },
  tsx = { 'jsdoc', 'regex' },
  php = { 'html', 'javascript', 'css', 'phpdoc', 'jsdoc', 'regex' },
  vue = { 'javascript', 'typescript', 'tsx', 'css', 'scss', 'jsdoc', 'regex' },
  markdown = { 'markdown_inline' },
}
local enabled, available = {}, {}
for _, parser in ipairs(parsers) do
  enabled[parser] = true
end
for _, parser in ipairs(ts.get_available()) do
  available[parser] = true
end
local pending, queued, failed = {}, {}, {}
local waiting_buffers = {} ---@type table<integer, string>
local running = false
local activate

local function has_parser(parser)
  local ok, loaded = pcall(vim.treesitter.language.add, parser)
  return ok and loaded
end

local function catch_up()
  for buf in pairs(waiting_buffers) do
    if not vim.api.nvim_buf_is_loaded(buf) then
      waiting_buffers[buf] = nil
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    activate(buf)
  end
end

local function flush()
  local batch = {}
  for parser in pairs(queued) do
    if has_parser(parser) then
      pending[parser] = nil
    else
      batch[#batch + 1] = parser
    end
  end
  queued = {}
  table.sort(batch)
  if #batch == 0 then
    running = false
    catch_up()
    return
  end
  -- One batch at a time also avoids overlapping upstream query dependencies.
  -- await(callback) is nonblocking; wait() would block startup.
  ts.install(batch):await(vim.schedule_wrap(function()
    -- Neovim caches nonexistent runtime directories. A fresh install creates site/;
    -- invalidate that cache so the first parser and its queries are visible now.
    vim.o.runtimepath = vim.o.runtimepath
    if next(waiting_buffers) then
      -- Drop Neovim's weak memo of missing injection languages, once per install batch.
      collectgarbage('collect')
    end
    local failures = {}
    for _, parser in ipairs(batch) do
      pending[parser] = nil
      if not has_parser(parser) then
        failed[parser] = true
        failures[#failures + 1] = parser
      end
    end
    if #failures > 0 then
      vim.notify(
        ('Could not install parsers: %s. See :TSLog; retry with :TSInstall %s'):format(
          table.concat(failures, ', '),
          table.concat(failures, ' ')
        ),
        vim.log.levels.WARN
      )
    end
    running = false
    if next(queued) then
      running = true
      vim.schedule(flush)
    end
    catch_up()
  end))
end

---@param wanted string[]
---@return boolean waiting
local function request(wanted)
  local waiting = false
  for _, parser in ipairs(wanted) do
    if not has_parser(parser) and available[parser] and not failed[parser] then
      waiting = true
      if not pending[parser] then
        pending[parser], queued[parser] = true, true
      end
    end
  end
  if next(queued) and not running then
    running = true
    vim.schedule(flush)
  end
  return waiting
end

activate = function(buf)
  local waited = waiting_buffers[buf]
  waiting_buffers[buf] = nil
  if not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  -- Resolve aliases (sh → bash, yaml.ansible → yaml, typescriptreact → tsx).
  local parser = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not parser or not enabled[parser] then
    return
  end
  if vim.bo[buf].buftype == '' then
    local wanted = merge_unique({ parser }, companions[parser])
    if request(wanted) then
      waiting_buffers[buf] = parser
      return
    end
  end
  if has_parser(parser) then
    if waited == parser then
      -- Context/indent plugins may have parsed this tree before its companions existed.
      assert(vim.treesitter.get_parser(buf, parser)):invalidate(true)
    end
    vim.treesitter.start(buf, parser)
  end
end

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('dotfiles-treesitter', { clear = true }),
  callback = function(event)
    activate(event.buf)
  end,
})
-- Noice needs these small UI grammars independently of the project language.
request(ui_parsers)
catch_up()
