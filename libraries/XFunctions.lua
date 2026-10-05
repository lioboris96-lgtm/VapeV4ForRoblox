local XFunctions = {}

function XFunctions:SetGlobalData(key, value)
    getgenv()[key] = value
    shared[key] = value
end

return XFunctions
