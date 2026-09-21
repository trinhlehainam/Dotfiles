---@class dotfiles.project.FilesAssociationPattern
---@field filetype string
---@field has_slash boolean
---@field matcher vim.lpeg.Pattern
---@field raw string
---@field priority integer

---@class dotfiles.project.FiletypeSettings
---@field insert_spaces? boolean
---@field tab_size? number
---@field detect_indentation? boolean
---@field format_on_save? boolean

---@alias dotfiles.project.FiletypeSettingsMap table<string, dotfiles.project.FiletypeSettings>
