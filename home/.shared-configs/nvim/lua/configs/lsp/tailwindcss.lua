local function root(bufnr)
  -- v4 projects declare the package without needing tailwind.config.*.
  return require('utils.tool_root').find(bufnr, {
    'tailwind.config.js',
    'tailwind.config.cjs',
    'tailwind.config.mjs',
    'tailwind.config.ts',
    'tailwind.config.cts',
    'tailwind.config.mts',
  }, 'tailwindcss')
end

---@type dotfiles.lsp.Language
return {
  filetypes = {
    'html',
    'css',
    'scss',
    'sass',
    'less',
    'postcss',
    'php',
    'blade',
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'vue',
    'svelte',
    'astro',
    'markdown',
    'mdx',
  },
  condition = function(bufnr)
    return root(bufnr) ~= nil
  end,
  server_tools = { tailwindcss = { 'tailwindcss-language-server' } },
  tools = { 'tailwindcss-language-server', 'rustywind' },
  servers = {
    tailwindcss = {
      -- Use the same project gate after installation; a .git directory alone is insufficient.
      root_dir = function(bufnr, on_dir)
        local dir = root(bufnr)
        if dir then
          on_dir(dir)
        end
      end,
    },
  },
}
