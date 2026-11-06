---@type dotfiles.lsp.Language
return {
  filetypes = { 'rust' },
  parsers = { 'rust', 'toml' },
  -- Rustaceanvim owns startup; codelldb installs only when debugging starts.
  tools = { 'rust-analyzer' },
  debug_tools = { 'codelldb' },
  on_ready = function(bufnr)
    if vim.api.nvim_buf_get_name(bufnr) ~= '' then
      require('rustaceanvim.lsp').start(bufnr)
    end
  end,
  neotest = function()
    return require('rustaceanvim.neotest')
  end,
}
