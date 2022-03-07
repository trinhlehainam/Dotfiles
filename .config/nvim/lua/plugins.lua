local execute = vim.api.nvim_command

local fn = vim.fn

local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'

if fn.empty(fn.glob(install_path)) > 0 then
  fn.system({'git', 'clone', 'https://github.com/wbthomason/packer.nvim', install_path})
  execute 'packadd packer.nvim'
end

-- Only required if you have packer configured as `opt`
--vim.cmd [[packadd packer.nvim]]
-- Only if your version of Neovim doesn't have https://github.com/neovim/neovim/pull/12632 merged
--vim._update_package_paths()

require('packer').startup(function(use)
    -- Packer manager
    use 'wbthomason/packer.nvim'
    -- Best Color Schemes
    use 'morhetz/gruvbox'
    -- Icon
    use 'kyazdani42/nvim-web-devicons'
    use 'folke/which-key.nvim'
    -- Utils
    use 'nvim-lua/plenary.nvim'
    -- Better Syntax Support
    use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
    use 'norcalli/nvim-colorizer.lua'
    use 'lukas-reineke/indent-blankline.nvim'
    use 'b3nj5m1n/kommentary'
    use 'kyazdani42/nvim-tree.lua'
    use 'hoob3rt/lualine.nvim'
    use 'akinsho/nvim-bufferline.lua'
    use 'folke/todo-comments.nvim'
    use 'nvim-telescope/telescope.nvim'
    -- Snippet
    use 'L3MON4D3/LuaSnip'
    -- Completion
    use 'neovim/nvim-lspconfig'
    use 'ray-x/lsp_signature.nvim'
    use 'tjdevries/colorbuddy.nvim'
    use 'onsails/lspkind-nvim'
    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/cmp-nvim-lua'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'saadparwaiz1/cmp_luasnip'
    use 'windwp/nvim-autopairs'

    use 'lewis6991/gitsigns.nvim'
    -- Formating, Linting, etc
    use 'jose-elias-alvarez/null-ls.nvim'
    use 'folke/trouble.nvim'
    -- Highlight search
    use 'kevinhwang91/nvim-hlslens'
    -- Fancy notification
    use 'rcarriga/nvim-notify'

    use 'wakatime/vim-wakatime'
end)
