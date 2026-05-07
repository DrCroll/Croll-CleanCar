local reqId = 0
local pending = {}

RegisterNetEvent("PGN-CarClean:client:canCleanResult", function(rid, ok, errKey)
    local fn = pending[rid]
    if fn then
        pending[rid] = nil
        fn(ok == true, errKey, nil)
    end
end)

RegisterNetEvent("PGN-CarClean:client:finishCleanResult", function(rid, ok, errKey, netId)
    local fn = pending[rid]
    if fn then
        pending[rid] = nil
        fn(ok == true, errKey, netId)
    end
end)

local function nextReqId()
    reqId = reqId + 1
    if reqId > 100000000 then
        reqId = 1
    end
    return reqId
end

local function waitRpc(triggerEvent, netId, timeoutMs)
    local id = nextReqId()
    local done = false
    local okOut, errOut, netOut
    pending[id] = function(ok, errKey, nid)
        okOut = ok
        errOut = errKey
        netOut = nid
        done = true
    end
    TriggerServerEvent(triggerEvent, netId, id)
    local t = GetGameTimer()
    while not done and GetGameTimer() - t < (timeoutMs or 8000) do
        Wait(25)
    end
    if not done then
        pending[id] = nil
        return false, "err_generic", nil
    end
    return okOut, errOut, netOut
end

local function AttachSpongeToHand(playerPed)
    local spongeModel = `prop_sponge_01`
    RequestModel(spongeModel)
    local t = GetGameTimer()
    while not HasModelLoaded(spongeModel) and GetGameTimer() - t < 5000 do
        Wait(10)
    end
    if not HasModelLoaded(spongeModel) then
        return nil
    end
    local boneIndex = GetPedBoneIndex(playerPed, 57005)
    local sponge = CreateObject(spongeModel, 1.0, 1.0, 1.0, true, true, true)
    AttachEntityToEntity(sponge, playerPed, boneIndex, 0.12, 0.0, 0.0, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    return sponge
end

local function applyCleanVisual(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end
    SetVehicleDirtLevel(vehicle, 0.0)
    WashDecalsFromVehicle(vehicle, 1.0)
end

RegisterNetEvent("PGN-CarClean:client:tryCleanVehicle", function(_item)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, tonumber(Config.MaxDistance) or 5.0, 0, 70)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        CleanCarBridge.Notify(CleanCarLocale("err_no_vehicle"), "error")
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    local canStart, errStart = waitRpc("PGN-CarClean:server:canClean", netId, 8000)
    if not canStart then
        if errStart then
            CleanCarBridge.Notify(CleanCarLocale(errStart), "error")
        else
            CleanCarBridge.Notify(CleanCarLocale("err_generic"), "error")
        end
        return
    end

    local animDict = "amb@world_human_maid_clean@"
    local animName = "base"
    RequestAnimDict(animDict)
    local dt = GetGameTimer()
    while not HasAnimDictLoaded(animDict) and GetGameTimer() - dt < 5000 do
        Wait(10)
    end

    local sponge = AttachSpongeToHand(playerPed)
    local cleanDuration = tonumber(Config.CleanDurationMs) or 5000
    local ticks = 50
    local tickTime = cleanDuration / ticks
    local dirtLevel = GetVehicleDirtLevel(vehicle)
    local dirtStep = (dirtLevel > 0.01) and (dirtLevel / ticks) or 0.0

    CreateThread(function()
        for _ = 1, ticks do
            if DoesEntityExist(vehicle) and dirtStep > 0.0 then
                local currentDirt = GetVehicleDirtLevel(vehicle)
                SetVehicleDirtLevel(vehicle, math.max(0.0, currentDirt - dirtStep))
            end
            Wait(tickTime)
        end
    end)

    local progressOk = CleanCarBridge.ProgressBar(
        CleanCarLocale("progress_cleaning"),
        cleanDuration,
        animDict,
        animName,
        true
    )

    ClearPedTasks(playerPed)
    if sponge and DoesEntityExist(sponge) then
        DeleteEntity(sponge)
    end

    if not progressOk then
        return
    end

    local finishedOk, errEnd, netIdRet = waitRpc("PGN-CarClean:server:finishClean", netId, 8000)

    if finishedOk then
        local veh = netIdRet and NetworkGetEntityFromNetworkId(netIdRet) or vehicle
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            applyCleanVisual(veh)
        end
        CleanCarBridge.Notify(CleanCarLocale("notify_cleaned"), "success")
        return
    end

    if errEnd then
        CleanCarBridge.Notify(CleanCarLocale(errEnd), "error")
    else
        CleanCarBridge.Notify(CleanCarLocale("err_generic"), "error")
    end
end)
