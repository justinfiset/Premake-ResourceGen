---Shared helpers for the generators.
---Only standard Lua except `WriteLinesToFile`, which uses Premake's io/os/path libraries.
---Appends every element of `source` to `target`.
---@param target string[]
---@param source string[]
local function AppendAll(target, source)
    for _, value in ipairs(source) do
        target[#target + 1] = value
    end
end

---Writes the lines to the file, but only if the content changed.
---@param filePath string Absolute path of the file to write.
---@param lines string[] Lines without line endings.
---@return boolean written True if the file was written.
local function WriteLinesToFile(filePath, lines)
    local content = table.concat(lines, "\n") .. "\n"

    if io.readfile(filePath) == content then
        return false
    end

    os.mkdir(path.getdirectory(filePath))

    local ok, err = io.writefile(filePath, content)
    if not ok then
        error("Failed to write file '" .. filePath .. "': " .. tostring(err), 2)
    end

    return true
end

---Raises a clear error when a required option is missing or of the wrong type.
---@param opts table
---@param name string
---@param expectedType string
local function RequireOption(opts, name, expectedType)
    local value = opts[name]

    if type(value) ~= expectedType then
        error("Missing or invalid option '" .. name .. "' (expected " .. expectedType .. ", got " .. type(value) .. ")",
            3)
    end
end

return {
    AppendAll = AppendAll,
    WriteLinesToFile = WriteLinesToFile,
    RequireOption = RequireOption
}
