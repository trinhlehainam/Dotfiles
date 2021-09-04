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
    use 'folke/which-key.nvim'
    use 'nvim-lua/plenary.nvim'
    -- Better Syntax Support
    use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
    use 'norcalli/nvim-colorizer.lua'
    use 'lukas-reineke/indent-blankline.nvim'
    use 'windwp/nvim-autopairs'
    use 'b3nj5m1n/kommentary'
    use 'kyazdani42/nvim-web-devicons'
    use 'hoob3rt/lualine.nvim'
    use 'akinsho/nvim-bufferline.lua'
    use 'folke/todo-comments.nvim'
    use 'hrsh7th/nvim-compe'
    use 'neovim/nvim-lspconfig'
    use 'glepnir/lspsaga.nvim'
    use 'wakatime/vim-wakatime'
end)
