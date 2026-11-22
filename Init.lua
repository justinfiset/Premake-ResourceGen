---Entry point of Premake-ResourceGen.
---
---Usage from a consumer's `premake5.lua`:
---
---    local resourcegen = dofile(path.join(_MAIN_SCRIPT_DIR, "vendor/Premake-ResourceGen/init.lua"))
---    resourcegen.GenerateResources({ ... })
---
---Capture the directory at load time because `_SCRIPT_DIR` changes
---depending on the script being executed.
local root = _SCRIPT_DIR

local common = dofile(path.join(root, "Source/Common.lua"))
local resources = dofile(path.join(root, "Source/Resources.lua"))(common)

return {
    GenerateResources = resources.GenerateResources,
    WriteLinesToFile = common.WriteLinesToFile
}
