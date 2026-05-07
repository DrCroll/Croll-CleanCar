--[[
    Progress + notify bridge (client).
]]

local ClientQBCore
local ClientESX

local function tryQBCore()
    if ClientQBCore then
        return true
    end
    local res = (CleanCarBridge.DetectFramework() == "qbx") and CleanCarBridge.CoreQbx() or CleanCarBridge.CoreQb()
    local ok, core = pcall(function()
        return exports[res]:GetCoreObject()
    end)
    if ok and core then
        ClientQBCore = core
        return true
    end
    return false
end

local function tryESX()
    if ClientESX then
        return true
    end
    local ok, esx = pcall(function()
        return exports["es_extended"]:getSharedObject()
    end)
    if ok and esx then
        ClientESX = esx
        return true
    end
    return false
end

CreateThread(function()
    Wait(0)
    tryQBCore()
    tryESX()
    for _ = 1, 120 do
        if tryQBCore() or tryESX() then
            break
        end
        Wait(50)
    end
end)

---@return boolean success
function CleanCarBridge.ProgressBar(label, durationMs, animDict, animName, canCancel)
    local duration = math.floor(tonumber(durationMs) or 3000)
    local labelText = label or "…"
    canCancel = canCancel ~= false
    local anim = animDict and animName and {
        dict = animDict,
        clip = animName,
        flag = 49,
    } or nil
    local disable = { move = true, car = true, combat = true, mouse = false }

    if GetResourceState("ox_lib") == "started" then
        local ok, res = pcall(function()
            return exports.ox_lib:progressBar({
                duration = duration,
                label = labelText,
                canCancel = canCancel,
                disable = disable,
                anim = anim or {},
            })
        end)
        if ok then
            return res == true
        end
    end

    local fw = CleanCarBridge.DetectFramework()
    if (fw == "qb" or fw == "qbx") and tryQBCore() and ClientQBCore and ClientQBCore.Functions and ClientQBCore.Functions.Progressbar then
        local done, success = false, false
        ClientQBCore.Functions.Progressbar("croll_cleancar", labelText, duration, false, canCancel, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, animDict and {
            animDict = animDict,
            anim = animName,
            flags = 49,
        } or {}, {}, nil, function()
            success = true
            done = true
        end, function()
            success = false
            done = true
        end)
        while not done do
            Wait(25)
        end
        return success
    end

    if animDict and animName then
        RequestAnimDict(animDict)
        local t = GetGameTimer()
        while not HasAnimDictLoaded(animDict) and GetGameTimer() - t < 5000 do
            Wait(10)
        end
        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, 8.0, -1, 49, 0.0, false, false, false)
        end
    end
    local endAt = GetGameTimer() + duration
    local ped = PlayerPedId()
    while GetGameTimer() < endAt do
        if canCancel and IsControlJustPressed(0, 73) then
            ClearPedTasks(ped)
            return false
        end
        Wait(100)
    end
    ped = PlayerPedId()
    ClearPedTasks(ped)
    return true
end

function CleanCarBridge.Notify(msg, ntype)
    ntype = ntype or "inform"
    if GetResourceState("ox_lib") == "started" then
        pcall(function()
            exports.ox_lib:notify({ description = tostring(msg), type = ntype })
        end)
        return
    end
    local fw = CleanCarBridge.DetectFramework()
    if (fw == "qb" or fw == "qbx") and tryQBCore() and ClientQBCore and ClientQBCore.Functions and ClientQBCore.Functions.Notify then
        ClientQBCore.Functions.Notify(msg, ntype)
        return
    end
    if fw == "esx" and tryESX() and ClientESX and ClientESX.ShowNotification then
        ClientESX.ShowNotification(tostring(msg))
        return
    end
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(tostring(msg))
    EndTextCommandThefeedPostTicker(false, false)
end
