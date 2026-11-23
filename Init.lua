local root = _SCRIPT_DIR

local common = dofile(path.join(root, "Source/Common.lua"))
local resources = dofile(path.join(root, "Source/Resources.lua"))(common)

local registeredTasks = {}
local actionRegistered = false

local resourcegen = {
    GenerateResources = resources.GenerateResources,
    WriteLinesToFile = common.WriteLinesToFile
}

---Registers a resource generation task.
---@param options table Resource generation options.
function resourcegen.RegisterAction(options)
    registeredTasks[#registeredTasks + 1] = options

    if actionRegistered then
        return
    end

    actionRegistered = true

    newaction {
        trigger = "resourcegen",
        description = "Generate embedded resources",

        execute = function()
            for _, task in ipairs(registeredTasks) do
                print("Generating resources: " .. task.moduleName)
                resourcegen.GenerateResources(task)
            end
        end
    }
end

return resourcegen
