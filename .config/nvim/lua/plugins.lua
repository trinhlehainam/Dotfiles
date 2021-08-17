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
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'
    -- Color Schemes
    use 'morhetz/gruvbox' 
    use 'ryanoasis/vim-devicons'
    -- Better Syntax Support
    use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
    -- File Explorer
    use 'scrooloose/nerdcommenter'
    use 'windwp/nvim-autopairs'
    use 'hrsh7th/nvim-compe'
    use 'vim-airline/vim-airline'
    use 'vim-airline/vim-airline-themes'
    use 'wakatime/vim-wakatime'
end)
