---@class dotfiles.project.FilesAssociationPattern
---@field filetype string
---@field has_slash boolean
---@field path_pattern string
---@field raw string

---@class dotfiles.project.FilesAssociations
---@field extensions table<string, string>
---@field filenames table<string, string>
---@field patterns dotfiles.project.FilesAssociationPattern[]

---@class dotfiles.project.FiletypeSettings
---@field insert_spaces? boolean
---@field tab_size? number
---@field detect_indentation? boolean
---@field format_on_save? boolean

---@alias dotfiles.project.FiletypeSettingsMap table<string, dotfiles.project.FiletypeSettings>

return {}
