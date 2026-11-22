-- tests/run.lua
-- Capture this before loading other Lua files.
local testsDir = _SCRIPT_DIR
local repoRoot = path.getabsolute("..", testsDir)

local resourcegen = dofile(path.join(repoRoot, "Init.lua"))

local fixturesDir = path.join(testsDir, "Fixtures")
local assetsDir = path.join(fixturesDir, "Assets")
local flatAssetsDir = path.join(fixturesDir, "FlatAssets")
local outputDir = path.join(testsDir, ".tmp")

os.mkdir(outputDir)

-- ---------------------------------------------------------------------------
-- Test helpers
-- ---------------------------------------------------------------------------

local passed = 0
local failed = 0

local function AssertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "Values are not equal") .. "\nExpected:\n" .. tostring(expected) .. "\nActual:\n" ..
                  tostring(actual), 2)
    end
end

---Asserts that a string contains the expected text.
---On failure, prints the complete content with line numbers.
---@param value string
---@param expected string
---@param message? string
local function AssertContains(value, expected, message)
    if not value:find(expected, 1, true) then
        local lines = {}
        local lineNumber = 1

        for line in (value .. "\n"):gmatch("(.-)\n") do
            lines[#lines + 1] = string.format("%4d | %s", lineNumber, line)
            lineNumber = lineNumber + 1
        end

        error((message or "Expected text was not found") .. "\nMissing: " .. expected .. "\n\nActual content:\n" ..
                  table.concat(lines, "\n"), 2)
    end
end

---Asserts that a string does not contain the unexpected text.
---On failure, prints the complete content with line numbers.
---@param value string
---@param unexpected string
---@param message? string
local function AssertNotContains(value, unexpected, message)
    if value:find(unexpected, 1, true) then
        local lines = {}
        local lineNumber = 1

        for line in (value .. "\n"):gmatch("(.-)\n") do
            lines[#lines + 1] = string.format("%4d | %s", lineNumber, line)
            lineNumber = lineNumber + 1
        end

        error((message or "Unexpected text was found") .. "\nFound: " .. unexpected .. "\n\nActual content:\n" ..
                  table.concat(lines, "\n"), 2)
    end
end

local function ReadFile(filePath)
    local content = io.readfile(filePath)

    if content == nil then
        error("Could not read file: " .. filePath, 2)
    end

    return content
end

local function RunTest(name, callback)
    io.write("[TEST] " .. name .. " ... ")

    local ok, err = pcall(callback)

    if ok then
        passed = passed + 1
        io.write("✓ PASS\n")
    else
        failed = failed + 1
        io.write("FAIL\n")
        io.write(tostring(err) .. "\n")
    end
end

local function Generate(options)
    return resourcegen.GenerateResources(options)
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

RunTest("generates nested namespaces and virtual paths", function()
    local outputFile = path.join(outputDir, "Nested.ixx")

    local written = Generate({
        rootDir = assetsDir,
        uriPrefix = "editor://",
        outFile = outputFile,
        namespace = "Test::Resources",
        moduleName = "Test.Resources"
    })

    AssertEqual(written, true, "Expected the output file to be written")

    local content = ReadFile(outputFile)

    AssertContains(content, "export module Test.Resources;")

    AssertContains(content, "export namespace Test::Resources::Icons::Dark")

    AssertContains(content, 'Camera = "editor://Icons/Dark/Camera.png";')

    AssertContains(content, 'Camera = "editor://Icons/Light/Camera.png";')

    AssertContains(content, 'Save = "editor://Icons/Light/Save.png";')

    AssertContains(content, 'Root = "editor://root.png";')

    -- The default extension is .png, so the font must not be generated.
    AssertNotContains(content, "Regular")
end)

RunTest("supports flat namespace generation", function()
    local outputFile = path.join(outputDir, "Flat.ixx")

    Generate({
        rootDir = flatAssetsDir,
        uriPrefix = "editor://",
        outFile = outputFile,
        namespace = "Test::Resources",
        moduleName = "Test.Resources.Flat",
        namespaceFromPath = false
    })

    local content = ReadFile(outputFile)

    AssertContains(content, "export namespace Test::Resources\n")
    AssertContains(content, 'Camera = "editor://Camera.png";')
    AssertContains(content, 'Save = "editor://Save.png";')

    AssertNotContains(content, "Test::Resources::Icons")
end)

RunTest("filters files by configured extensions", function()
    local outputFile = path.join(outputDir, "Fonts.ixx")

    Generate({
        rootDir = assetsDir,
        uriPrefix = "editor://",
        outFile = outputFile,
        namespace = "Test::Resources",
        moduleName = "Test.Resources.Fonts",
        extensions = {".ttf"}
    })

    local content = ReadFile(outputFile)

    AssertContains(content, "Regular")
    AssertNotContains(content, "Camera")
    AssertNotContains(content, "Save")
end)

RunTest("does not rewrite unchanged output", function()
    local outputFile = path.join(outputDir, "Unchanged.ixx")

    local options = {
        rootDir = assetsDir,
        uriPrefix = "editor://",
        outFile = outputFile,
        namespace = "Test::Resources",
        moduleName = "Test.Resources.Unchanged"
    }

    local firstWrite = Generate(options)
    local secondWrite = Generate(options)

    AssertEqual(firstWrite, true)
    AssertEqual(secondWrite, false)
end)

RunTest("rejects duplicate generated identifiers", function()
    local duplicateDir = path.join(fixturesDir, "Duplicates")
    local outputFile = path.join(outputDir, "Duplicates.ixx")

    local ok, err = pcall(function()
        Generate({
            rootDir = duplicateDir,
            uriPrefix = "editor://",
            outFile = outputFile,
            namespace = "Test::Resources",
            moduleName = "Test.Resources.Duplicates"
        })
    end)

    AssertEqual(ok, false, "Expected duplicate identifiers to be rejected")
    AssertContains(tostring(err), "Duplicate generated resource identifier")
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------

io.write("\n")
io.write("Test results: " .. passed .. " passed, " .. failed .. " failed\n")

if failed > 0 then
    error("Premake-ResourceGen tests failed", 0)
end
