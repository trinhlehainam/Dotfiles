---@class ProjectFilesAssociationPattern
---@field filetype string
---@field has_slash boolean
---@field path_pattern string
---@field raw string

---@class ProjectFilesAssociations
---@field extensions table<string, string>
---@field filenames table<string, string>
---@field patterns ProjectFilesAssociationPattern[]

---@class ProjectFiletypeSettings
---@field insert_spaces? boolean
---@field tab_size? number
---@field detect_indentation? boolean
---@field format_on_save? boolean

---@alias ProjectFiletypeSettingsMap table<string, ProjectFiletypeSettings>

return {}
