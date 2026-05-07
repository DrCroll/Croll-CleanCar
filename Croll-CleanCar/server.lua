local cooldownUntil = {}
local lastRpcAt = {}

local ENTITY_VEHICLE = 2

local function sanitizeItemKey(name)
    name = tostring(name or ""):sub(1, 64)
    if name == "" or not name:match("^[%w%-_]+$") then
        return nil
    end
    return name
end

local function clampedMaxDistance()
    local raw = tonumber(Config.MaxDistance) or 5.0
    local clamp = Config.ServerMaxDistanceClamp or {}
    local lo = tonumber(clamp.min) or 1.0
    local hi = tonumber(clamp.max) or 25.0
    return math.max(lo, math.min(raw, hi))
end

local function nowMs()
    return GetGameTimer()
end

local function rpcRateOk(src)
    local gap = tonumber(Config.MinServerRpcIntervalMs) or 250
    local t = nowMs()
    local last = lastRpcAt[src]
    if last and (t - last) < gap then
        return false
    end
    lastRpcAt[src] = t
    return true
end

local function vehicleEntityFromNet(netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then
        return nil
    end
    if GetEntityType(veh) ~= ENTITY_VEHICLE then
        return nil
    end
    return veh
end

local function pedVehicleDistanceOk(src, veh)
    local maxDist = clampedMaxDistance()
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return false
    end
    local pc = GetEntityCoords(ped)
    local vc = GetEntityCoords(veh)
    local slack = 1.0
    return #(pc - vc) <= maxDist + slack
end

local function canUseClean(src, netId)
    netId = tonumber(netId)
    if not tonumber(src) or not netId or netId < 1 then
        return false, "err_generic"
    end
    local itemName = sanitizeItemKey(Config.ItemName)
    if not itemName then
        return false, "err_generic"
    end
    local cd = tonumber(Config.CleanCooldownMs) or 1500
    local t = nowMs()
    local untilT = cooldownUntil[src]
    if untilT and t < untilT then
        return false, "err_cooldown"
    end
    if CleanCarBridge.GetItemCount(src, itemName) < 1 then
        return false, "err_no_item"
    end
    local veh = vehicleEntityFromNet(netId)
    if not veh then
        return false, "err_vehicle_invalid"
    end
    if not pedVehicleDistanceOk(src, veh) then
        return false, "err_too_far"
    end
    cooldownUntil[src] = t + cd
    return true, nil
end

local function finishClean(src, netId)
    netId = tonumber(netId)
    if not tonumber(src) or not netId or netId < 1 then
        return false, "err_generic"
    end
    local itemName = sanitizeItemKey(Config.ItemName)
    if not itemName then
        return false, "err_generic"
    end
    if CleanCarBridge.GetItemCount(src, itemName) < 1 then
        return false, "err_no_item"
    end
    local veh = vehicleEntityFromNet(netId)
    if not veh then
        return false, "err_vehicle_invalid"
    end
    if not pedVehicleDistanceOk(src, veh) then
        return false, "err_too_far"
    end
    if not CleanCarBridge.ConsumeCleanCharge(src, itemName) then
        return false, "err_generic"
    end
    return true, nil
end

RegisterNetEvent("PGN-CarClean:server:canClean", function(netId, rid)
    local src = source
    rid = tonumber(rid)
    if not rid or rid < 1 or rid > 100000000 then
        return
    end
    if not rpcRateOk(src) then
        TriggerClientEvent("PGN-CarClean:client:canCleanResult", src, rid, false, "err_rate_limit")
        return
    end
    netId = tonumber(netId)
    local ok, key = canUseClean(src, netId)
    TriggerClientEvent("PGN-CarClean:client:canCleanResult", src, rid, ok, key)
end)

RegisterNetEvent("PGN-CarClean:server:finishClean", function(netId, rid)
    local src = source
    rid = tonumber(rid)
    if not rid or rid < 1 or rid > 100000000 then
        return
    end
    if not rpcRateOk(src) then
        TriggerClientEvent("PGN-CarClean:client:finishCleanResult", src, rid, false, "err_rate_limit", netId)
        return
    end
    netId = tonumber(netId)
    local ok, key = finishClean(src, netId)
    TriggerClientEvent("PGN-CarClean:client:finishCleanResult", src, rid, ok, key, netId)
end)

AddEventHandler("playerDropped", function()
    local src = source
    cooldownUntil[src] = nil
    lastRpcAt[src] = nil
end)

AddEventHandler("onResourceStop", function(resName)
    if resName ~= GetCurrentResourceName() then
        return
    end
    cooldownUntil = {}
    lastRpcAt = {}
end)

local registeredItem = sanitizeItemKey(Config.ItemName)
if registeredItem then
    CleanCarBridge.RegisterUsableItem(registeredItem, function(source, item)
        TriggerClientEvent("PGN-CarClean:client:tryCleanVehicle", source, item)
    end)
else
    print("^1[Croll-CleanCar]^7 Config.ItemName must be alphanumeric with optional _ or - (max 64 chars).")
end
