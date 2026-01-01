-- Mason Tool Installer Configuration
-- This file aggregates formatters, linters, and LSP configurations from a central source
-- and automatically installs required tools via Mason package manager.
--
-- Dependencies:
--   - configs.lsp: Central configuration module containing formatters, linters, and LSP configs
--   - mason-tool-installer: Plugin that handles automatic installation of tools via Mason
--
-- The configuration follows these steps:
--   1. Extract formatter configurations and build list of servers to install
--   2. Extract linter configurations and build list of servers to install
--   3. Extract LSP configurations and build list of language servers to install
--   4. Pass aggregated list to mason-tool-installer for automatic installation

-- Import configuration modules with error handling
local log = require('utils.log')

local ok, lsp_config = pcall(require, 'configs.lsp')
if not ok then
  log.error('Failed to load configs.lsp module for mason-tool-installer')
  return
end

local formatters = lsp_config.formatters or {}
local linters = lsp_config.linters or {}
local lspconfigs = lsp_config.lspconfigs or {}

-- ========================================
-- Formatter Configuration Aggregation
-- ========================================
-- Build list of formatter servers to ensure are installed
local ensure_installed_formatters = {}

-- Iterate through formatter configurations and extract server names
-- Each formatter config may specify multiple servers in a 'servers' field
for _, formatter in ipairs(formatters) do
  if vim.islist(formatter.servers) then
    vim.list_extend(ensure_installed_formatters, formatter.servers)
  end
end

-- Build mapping of file types to formatters
local formatters_by_ft = {}

-- Aggregate formatter-to-filetype mappings from configurations
-- Uses 'keep' strategy to preserve existing mappings (first one wins)
for _, formatter in ipairs(formatters) do
  if type(formatter.formatters_by_ft) == 'table' then
    formatters_by_ft = vim.tbl_extend('keep', formatters_by_ft, formatter.formatters_by_ft)
  end
end

-- ========================================
-- Linter Configuration Aggregation
-- ========================================
-- Build list of linter servers to ensure are installed
-- Starts empty as no default linters are specified
local ensure_installed_linters = {}

-- Iterate through linter configurations and extract server names
-- Each linter config may specify multiple servers in a 'servers' field
for _, linter in ipairs(linters) do
  if vim.islist(linter.servers) then
    vim.list_extend(ensure_installed_linters, linter.servers)
  end
end

-- Build mapping of file types to linters
-- Starts empty as no default linters are specified
local linters_by_ft = {}

-- Aggregate linter-to-filetype mappings from configurations
-- Uses 'keep' strategy to preserve existing mappings (first one wins)
for _, linter in ipairs(linters) do
  if type(linter.linters_by_ft) == 'table' then
    linters_by_ft = vim.tbl_extend('keep', linters_by_ft, linter.linters_by_ft)
  end
end

-- ========================================
-- LSP Configuration Aggregation
-- ========================================
-- Build list of LSP servers to ensure are installed
local ensure_installed_lsps = {}

-- Iterate through LSP configurations and extract Mason package names
-- Each LSP config specifies its Mason package name in 'mason_package' field
for _, lspconfig in pairs(lspconfigs) do
  local package_name = lspconfig.mason_package
  -- Only add valid package names to the installation list
  if type(package_name) == 'string' and package_name ~= '' then
    -- Add package to installation list
    ensure_installed_lsps[#ensure_installed_lsps + 1] = package_name
  end
end

-- ========================================
-- Final Configuration
-- ========================================
-- Combine all tool lists into single installation list
-- Mason-tool-installer will handle deduplication automatically
local ensure_installed = {}
vim.list_extend(ensure_installed, ensure_installed_formatters)
vim.list_extend(ensure_installed, ensure_installed_linters)
vim.list_extend(ensure_installed, ensure_installed_lsps)

-- Initialize mason-tool-installer with aggregated configuration
-- This will automatically install all specified tools on startup
require('mason-tool-installer').setup({ ensure_installed = ensure_installed })
