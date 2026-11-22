--- Generator: generates C++ resource constants from files.
return function(common)
    local RequireOption = common.RequireOption
    local WriteLinesToFile = common.WriteLinesToFile

    ---@class ResourceOptions
    ---@field rootDir string Absolute path of the folder to scan.
    ---@field uriPrefix string Virtual path prefix, e.g. "editor://".
    ---@field outFile string Absolute path of the generated .ixx file.
    ---@field namespace string Base C++ namespace for generated constants.
    ---                              Accepts both "." and "::" separators.
    ---@field moduleName string Name of the generated C++ module.
    ---@field extensions? string[] Extensions to include. Default: { ".png" }.
    ---@field namespaceFromPath? boolean Generate nested namespaces from directory paths. Default: true.

    local DEFAULT_EXTENSIONS = {".png"}

    ---------------------------------------------------------------------------
    -- File discovery
    ---------------------------------------------------------------------------

    ---Finds every matching file under a folder.
    ---Results are sorted to guarantee deterministic output.
    ---@param rootDir string Absolute root directory.
    ---@param extensions string[] File extensions to include.
    ---@return string[]
    local function GetResourceFiles(rootDir, extensions)
        local files = {}

        for _, extension in ipairs(extensions) do
            local matches = os.matchfiles(rootDir .. "/**" .. extension)

            for _, file in ipairs(matches) do
                files[#files + 1] = file
            end
        end

        table.sort(files)

        return files
    end

    ---Returns a file path relative to a root folder.
    ---Normalizes path separators to forward slashes.
    ---@param filePath string
    ---@param rootDir string
    ---@return string
    local function GetRelativePath(filePath, rootDir)
        local relative = path.getrelative(rootDir, filePath)
        return (relative:gsub("\\", "/"))
    end

    ---------------------------------------------------------------------------
    -- Identifier generation
    ---------------------------------------------------------------------------

    ---Converts a string into a PascalCase C++ identifier.
    ---
    ---Non-alphanumeric characters are treated as word separators.
    ---Identifiers starting with a digit are prefixed with an underscore.
    ---
    ---Examples:
    ---  "new_folder" -> "NewFolder"
    ---  "my-icon"    -> "MyIcon"
    ---  "123_items"  -> "_123Items"
    ---
    ---@param value string
    ---@return string
    local function GenerateIdentifier(value)
        local name = ""

        for part in value:gmatch("[%w]+") do
            name = name .. part:sub(1, 1):upper() .. part:sub(2)
        end

        if name == "" then
            error("Cannot generate a C++ identifier from '" .. value .. "'", 3)
        end

        if name:match("^%d") then
            name = "_" .. name
        end

        return name
    end

    ---Converts a namespace string into a valid C++ namespace path.
    ---
    ---Both "." and "::" are accepted as namespace separators.
    ---
    ---Examples:
    ---  "Test.Resources"       -> "Test::Resources"
    ---  "Test::Editor.Resources" -> "Test::Editor::Resources"
    ---
    ---Each namespace segment is converted to PascalCase.
    ---
    ---@param namespace string
    ---@return string
    local function GenerateNamespace(namespace)
        local segments = {}

        for segment in namespace:gmatch("[^.:]+") do
            segments[#segments + 1] = GenerateIdentifier(segment)
        end

        if #segments == 0 then
            error("Cannot generate a C++ namespace from '" .. namespace .. "'", 3)
        end

        return table.concat(segments, "::")
    end

    ---Generates a C++ identifier from a resource filename.
    ---
    ---The file extension is removed before generating the identifier.
    ---
    ---Examples:
    ---  "Camera.png"       -> "Camera"
    ---  "main_menu.png"    -> "MainMenu"
    ---
    ---@param relativePath string
    ---@return string
    local function GenerateConstantName(relativePath)
        local fileName = relativePath:match("([^/]+)$") or relativePath
        local withoutExtension = fileName:gsub("%.[^%.]+$", "")

        return GenerateIdentifier(withoutExtension)
    end

    --- Removes trailing path separators without modifying URI schemes.
    ---@param value string
    ---@return string
    local function NormalizeUriPrefix(value)
        local scheme, pathPart = value:match("^([%w+%.%-]+://)(.*)$")

        if scheme then
            pathPart = pathPart:gsub("^/+", ""):gsub("/+$", "")
            return scheme .. pathPart
        end

        return (value:gsub("/+$", ""))
    end

    ---------------------------------------------------------------------------
    -- Namespace generation
    ---------------------------------------------------------------------------

    ---Generates the namespace for a resource based on its relative path.
    ---
    ---When namespaceFromPath is enabled, directory names are converted into
    ---additional nested namespaces.
    ---
    ---Examples:
    ---  Base namespace: "Test::Resources"
    ---  Relative path:  "Icons/Dark/Camera.png"
    ---
    ---  namespaceFromPath = true:
    ---      Test::Resources::Icons::Dark
    ---
    ---  namespaceFromPath = false:
    ---      Test::Resources
    ---
    ---@param baseNamespace string
    ---@param relativePath string
    ---@param namespaceFromPath boolean
    ---@return string
    local function GenerateResourceNamespace(baseNamespace, relativePath, namespaceFromPath)
        if not namespaceFromPath then
            return baseNamespace
        end

        local directory = relativePath:match("^(.*)/[^/]+$")

        if not directory then
            return baseNamespace
        end

        local segments = {}

        for segment in directory:gmatch("[^/]+") do
            segments[#segments + 1] = GenerateIdentifier(segment)
        end

        if #segments == 0 then
            return baseNamespace
        end

        return baseNamespace .. "::" .. table.concat(segments, "::")
    end

    ---------------------------------------------------------------------------
    -- C++ code generation
    ---------------------------------------------------------------------------

    ---Escapes a string for use as a C++ string literal.
    ---
    ---Handles quotes, backslashes, control characters and common escape
    ---sequences to ensure generated C++ code remains valid.
    ---
    ---@param value string
    ---@return string
    local function EscapeCppString(value)
        local escapes = {
            ["\\"] = "\\\\",
            ['"'] = '\\"',
            ["\n"] = "\\n",
            ["\r"] = "\\r",
            ["\t"] = "\\t"
        }

        return (value:gsub('[%z\1-\31\\"]', function(char)
            return escapes[char] or string.format("\\%03o", char:byte())
        end))
    end

    ---Creates the beginning of the generated C++ module.
    ---@param moduleName string
    ---@return string[]
    local function GenerateModuleStart(moduleName)
        return {"// Auto-generated C++ module: " .. moduleName, "// Do not edit this file manually.", "",
                "export module " .. moduleName .. ";", ""}
    end

    ---Creates a resource constant inside its corresponding namespace.
    ---
    ---@param namespace string
    ---@param constantName string
    ---@param virtualPath string
    ---@return string[]
    local function GenerateResourceConstant(namespace, constantName, virtualPath)
        return {"export namespace " .. namespace, "{",
                '    inline constexpr const char* ' .. constantName .. ' = "' .. EscapeCppString(virtualPath) .. '";',
                "}", ""}
    end

    ---------------------------------------------------------------------------
    -- Resource generation
    ---------------------------------------------------------------------------

    ---Generates a C++ module containing constants for discovered resources.
    ---
    ---Resources are discovered recursively under rootDir. Each resource is
    ---assigned a C++ namespace and constant name based on its relative path.
    ---
    ---The virtual path is constructed from uriPrefix and the relative path.
    ---
    ---Duplicate fully qualified identifiers are rejected to prevent
    ---ambiguous or invalid generated C++ declarations.
    ---
    ---@param opts ResourceOptions
    ---@return boolean written Whether the output file was modified.
    local function GenerateResources(opts)
        if type(opts) ~= "table" then
            error("GenerateResources expects an options table", 2)
        end

        -- Required options
        RequireOption(opts, "rootDir", "string")
        RequireOption(opts, "uriPrefix", "string")
        RequireOption(opts, "outFile", "string")
        RequireOption(opts, "namespace", "string")
        RequireOption(opts, "moduleName", "string")

        -- Optional options
        local extensions = opts.extensions or DEFAULT_EXTENSIONS
        local namespaceFromPath = opts.namespaceFromPath

        if namespaceFromPath == nil then
            namespaceFromPath = true
        end

        -- Validate optional options
        if type(extensions) ~= "table" then
            error("Option 'extensions' must be a table", 2)
        end

        if type(namespaceFromPath) ~= "boolean" then
            error("Option 'namespaceFromPath' must be a boolean", 2)
        end

        for _, extension in ipairs(extensions) do
            if type(extension) ~= "string" then
                error("Every entry in 'extensions' must be a string", 2)
            end

            if extension == "" then
                error("Resource extensions cannot be empty", 2)
            end

            if extension:sub(1, 1) ~= "." then
                error("Resource extensions must start with '.': " .. extension, 2)
            end
        end

        -- Normalize the base namespace into valid C++ syntax.
        local baseNamespace = GenerateNamespace(opts.namespace)

        -- Discover resources in a deterministic order.
        local files = GetResourceFiles(opts.rootDir, extensions)

        -- Normalize the URI prefix by removing trailing separators.
        local uriPrefix = NormalizeUriPrefix(opts.uriPrefix)

        local lines = GenerateModuleStart(opts.moduleName)

        -- Maps fully qualified identifiers to their originating file.
        local seen = {}

        for _, file in ipairs(files) do
            local relativePath = GetRelativePath(file, opts.rootDir)

            -- Generate the resource namespace and identifier.
            local namespace = GenerateResourceNamespace(baseNamespace, relativePath, namespaceFromPath)

            local constantName = GenerateConstantName(relativePath)
            local qualifiedName = namespace .. "::" .. constantName

            -- Reject duplicate identifiers while preserving the original
            -- source path in the error message.
            local previousPath = seen[qualifiedName]

            if previousPath then
                error("Duplicate generated resource identifier '" .. qualifiedName .. "' (from '" .. relativePath ..
                          "', previously generated from '" .. previousPath .. "')", 2)
            end

            seen[qualifiedName] = relativePath

            -- Construct the virtual resource path.
            local virtualPath

            if uriPrefix == "" then
                virtualPath = relativePath
            elseif uriPrefix:match("://$") then
                virtualPath = uriPrefix .. relativePath
            else
                virtualPath = uriPrefix .. "/" .. relativePath
            end

            -- Append the generated C++ declaration.
            common.AppendAll(lines, GenerateResourceConstant(namespace, constantName, virtualPath))
        end

        -- Write only when the generated content differs from the existing file.
        return WriteLinesToFile(opts.outFile, lines)
    end

    return {
        GenerateResources = GenerateResources
    }
end
