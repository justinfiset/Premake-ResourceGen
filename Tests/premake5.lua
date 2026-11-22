local testsDir = _SCRIPT_DIR

newaction {
    trigger = "test",
    description = "Run Premake-ResourceGen tests",

    execute = function()
        dofile(path.join(testsDir, "run.lua"))
    end
}
