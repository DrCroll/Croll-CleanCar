--[[
    Framework + inventory bridge (standalone). Optional: delegate to Croll-Bridge when running.
]]

local ESXObj

local function sanitizeItemKey(name)
    name = tostring(name or ""):sub(1, 64)
    if name == "" or not name:match("^[%w%-_]+$") then
        return nil
    end
    return name
end

local function coreResQbx()
    return CleanCarBridge.CoreQbx()
end

local function coreResQb()
    return CleanCarBridge.CoreQb()
end

local invCache
local invCacheAt = 0
local invCfgKey = ""
local INV_CACHE_MS = 6000

local function detectInventoryUncached()
    local inv = Config.Inventory
    if type(inv) == "string" and inv ~= "" and inv ~= "auto" then
        return inv
    end
    if GetResourceState("ox_inventory") == "started" then
        return "ox"
    end
    if GetResourceState("origen_inventory") == "started" then
        return "origen"
    end
    if GetResourceState("tgiann-inventory") == "started" then
        return "tgiann"
    end
    if GetResourceState("codem-inventory") == "started" then
        return "codem"
    end
    local fw = CleanCarBridge.DetectFramework()
    if fw == "esx" then
        return "esx"
    end
    return "qb"
end

function CleanCarBridge.DetectInventory()
    local k = tostring(Config.Inventory or "")
    local t = GetGameTimer()
    if invCfgKey == k and invCache and (t - invCacheAt) < INV_CACHE_MS then
        return invCache
    end
    invCache = detectInventoryUncached()
    invCfgKey = k
    invCacheAt = t
    return invCache
end

local extBridgeCache
local extBridgeAt = 0
local extBridgeKey = ""

function CleanCarBridge.UseExternalBridge()
    local k = tostring(Config.ExternalBridge)
    local t = GetGameTimer()
    if extBridgeKey == k and extBridgeCache ~= nil and (t - extBridgeAt) < 5000 then
        return extBridgeCache
    end
    local mode = Config.ExternalBridge
    local result = false
    if mode == "none" or mode == false then
        result = false
    elseif mode == "croll-bridge" then
        result = GetResourceState("Croll-Bridge") == "started"
    elseif mode == "auto" or mode == true or mode == nil then
        result = GetResourceState("Croll-Bridge") == "started"
    end
    extBridgeKey = k
    extBridgeCache = result
    extBridgeAt = t
    return result
end

AddEventHandler("onResourceStart", function(name)
    if name == "ox_inventory"
        or name == "origen_inventory"
        or name == "tgiann-inventory"
        or name == "codem-inventory"
    then
        invCacheAt = 0
    end
    if name == "Croll-Bridge" then
        extBridgeAt = 0
    end
end)

function CleanCarBridge.GetESX()
    if ESXObj then
        return ESXObj
    end
    local ok, obj = pcall(function()
        return exports["es_extended"]:getSharedObject()
    end)
    if ok and obj then
        ESXObj = obj
    end
    return ESXObj
end

function CleanCarBridge.GetQBCore()
    local fw = CleanCarBridge.DetectFramework()
    local res = (fw == "qbx") and coreResQbx() or coreResQb()
    local ok, core = pcall(function()
        return exports[res]:GetCoreObject()
    end)
    return ok and core or nil
end

function CleanCarBridge.GetQBPlayer(source)
    local src = tonumber(source)
    if not src then
        return nil
    end
    local fw = CleanCarBridge.DetectFramework()
    if fw == "qbx" then
        local ok, pl = pcall(function()
            return exports[coreResQbx()]:GetPlayer(src)
        end)
        return ok and pl or nil
    end
    local qb = CleanCarBridge.GetQBCore()
    if qb and qb.Functions and qb.Functions.GetPlayer then
        return qb.Functions.GetPlayer(src)
    end
    return nil
end

function CleanCarBridge.GetESXPlayer(source)
    local ESX = CleanCarBridge.GetESX()
    if not ESX or not ESX.GetPlayerFromId then
        return nil
    end
    return ESX.GetPlayerFromId(source)
end

function CleanCarBridge.GetItemCount(source, itemName)
    itemName = sanitizeItemKey(itemName)
    if not itemName then
        return 0
    end
    local src = tonumber(source)
    if not src then
        return 0
    end

    if CleanCarBridge.UseExternalBridge() then
        local ok, n = pcall(function()
            return exports["Croll-Bridge"]:GetItemCount(src, itemName)
        end)
        if ok then
            return math.floor(tonumber(n) or 0)
        end
        return 0
    end

    local inv = CleanCarBridge.DetectInventory()

    if inv == "ox" then
        local ok, n = pcall(function()
            return exports.ox_inventory:GetItemCount(src, itemName)
        end)
        if ok then
            return math.floor(tonumber(n) or 0)
        end
        return 0
    end

    if inv == "origen" then
        local ok, has = pcall(function()
            return exports.origen_inventory:HasItem(src, itemName)
        end)
        if ok and has then
            return 1
        end
        local ok2, n = pcall(function()
            return exports.origen_inventory:GetItemCount(src, itemName)
        end)
        if ok2 and n ~= nil then
            return math.floor(tonumber(n) or 0)
        end
        return 0
    end

    if inv == "tgiann" then
        local ok, n = pcall(function()
            return exports["tgiann-inventory"]:GetItemCount(src, itemName)
        end)
        if ok then
            return math.floor(tonumber(n) or 0)
        end
        local ok2, has = pcall(function()
            return exports["tgiann-inventory"]:HasItem(src, itemName, 1)
        end)
        if ok2 and has then
            return 1
        end
        return 0
    end

    if inv == "codem" then
        local ok, has = pcall(function()
            return exports["codem-inventory"]:HasItem(src, itemName, 1)
        end)
        if ok and has then
            return 1
        end
        local ok2, n = pcall(function()
            return exports["codem-inventory"]:GetItemCount(src, itemName)
        end)
        if ok2 and n ~= nil then
            return math.floor(tonumber(n) or 0)
        end
        return 0
    end

    if inv == "esx" then
        local xPlayer = CleanCarBridge.GetESXPlayer(src)
        if not xPlayer then
            return 0
        end
        local it = xPlayer.getInventoryItem and xPlayer.getInventoryItem(itemName)
        return math.floor(tonumber((it and it.count) or 0))
    end

    local Player = CleanCarBridge.GetQBPlayer(src)
    if not Player or not Player.Functions or not Player.Functions.GetItemByName then
        return 0
    end
    local it = Player.Functions.GetItemByName(itemName)
    return math.floor(tonumber((it and it.amount) or 0))
end

function CleanCarBridge.RemoveItem(source, itemName, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 100 then
        return false
    end
    itemName = sanitizeItemKey(itemName)
    if not itemName then
        return false
    end
    local src = tonumber(source)
    if not src then
        return false
    end

    if CleanCarBridge.UseExternalBridge() then
        local ok, res = pcall(function()
            return exports["Croll-Bridge"]:RemoveItem(src, itemName, amount)
        end)
        return ok and res == true
    end

    local inv = CleanCarBridge.DetectInventory()

    if inv == "ox" then
        local ok, res = pcall(function()
            return exports.ox_inventory:RemoveItem(src, itemName, amount)
        end)
        return ok and res ~= false and res ~= nil
    end

    if inv == "origen" then
        local ok, res = pcall(function()
            return exports.origen_inventory:RemoveItem(src, itemName, amount)
        end)
        return ok and res ~= false and res ~= nil
    end

    if inv == "tgiann" then
        local ok, res = pcall(function()
            return exports["tgiann-inventory"]:RemoveItem(src, itemName, amount)
        end)
        return ok and res ~= false and res ~= nil
    end

    if inv == "codem" then
        local ok, res = pcall(function()
            return exports["codem-inventory"]:RemoveItem(src, itemName, amount)
        end)
        return ok and res ~= false and res ~= nil
    end

    if inv == "esx" then
        local xPlayer = CleanCarBridge.GetESXPlayer(src)
        if not xPlayer or not xPlayer.removeInventoryItem then
            return false
        end
        return xPlayer.removeInventoryItem(itemName, amount) == true
    end

    local Player = CleanCarBridge.GetQBPlayer(src)
    if not Player or not Player.Functions or not Player.Functions.RemoveItem then
        return false
    end
    local ok, res = pcall(function()
        return Player.Functions.RemoveItem(itemName, amount)
    end)
    return ok and res ~= false and res ~= nil
end

local durabilityFallbackWarned = false

local function durabilityFallbackRemove(src, itemName)
    if not durabilityFallbackWarned then
        durabilityFallbackWarned = true
        print("^3[Croll-CleanCar]^7 Durability is enabled but metadata consume is only wired for ox_inventory; removing one full item per clean.")
    end
    return CleanCarBridge.RemoveItem(src, itemName, 1)
end

local function sanitizeMetaKey(key)
    key = tostring(key or ""):sub(1, 48)
    if key == "" or not key:match("^[%w_]+$") then
        return "cleancar_uses"
    end
    return key
end

--- Uses one clean charge: decrements metadata uses on ox_inventory, or removes one item when disabled / unsupported.
---@return boolean
function CleanCarBridge.ConsumeCleanCharge(source, itemName)
    itemName = sanitizeItemKey(itemName)
    if not itemName then
        return false
    end
    local src = tonumber(source)
    if not src then
        return false
    end

    local D = Config.Durability
    if type(D) ~= "table" or not D.Enabled then
        return CleanCarBridge.RemoveItem(src, itemName, 1)
    end

    local maxUses = math.floor(tonumber(D.MaxUses) or 5)
    if maxUses < 2 then
        maxUses = 2
    end
    local metaKey = sanitizeMetaKey(D.MetadataKey)

    if GetResourceState("ox_inventory") ~= "started" then
        return durabilityFallbackRemove(src, itemName)
    end

    local inv = CleanCarBridge.DetectInventory()
    if inv ~= "ox" then
        return durabilityFallbackRemove(src, itemName)
    end

    local okSlots, slots = pcall(function()
        return exports.ox_inventory:GetSlotsWithItem(src, itemName)
    end)
    if not okSlots or not slots then
        return false
    end

    local slotData = slots[1]
    if not slotData then
        for _, s in pairs(slots) do
            slotData = s
            break
        end
    end
    if not slotData or not slotData.slot then
        return false
    end

    local slot = slotData.slot
    local meta = slotData.metadata
    if type(meta) ~= "table" then
        meta = {}
    end

    local remaining = meta[metaKey]
    if remaining == nil then
        remaining = maxUses
    else
        remaining = math.floor(tonumber(remaining) or maxUses)
    end

    if remaining < 1 then
        local okRm, res = pcall(function()
            return exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)
        end)
        return okRm and res ~= false and res ~= nil
    end

    remaining = remaining - 1

    if remaining <= 0 then
        local okRm, res = pcall(function()
            return exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)
        end)
        return okRm and res ~= false and res ~= nil
    end

    local newMeta = {}
    for k, v in pairs(meta) do
        newMeta[k] = v
    end
    newMeta[metaKey] = remaining

    local okSet = pcall(function()
        exports.ox_inventory:SetMetadata(src, slot, newMeta)
    end)
    return okSet
end

local qbxHandlers = {}

local function tryBindQbxUseables()
    local res = coreResQbx()
    if GetResourceState(res) ~= "started" then
        return false
    end
    for itemName, handler in pairs(qbxHandlers) do
        pcall(function()
            exports[res]:CreateUseableItem(itemName, function(source, item)
                handler(source, CleanCarNormalizeItem(item))
            end)
        end)
    end
    return true
end

local qbHandlers = {}

local function tryBindQbUseables()
    local qb = CleanCarBridge.GetQBCore()
    if not qb or not qb.Functions or not qb.Functions.CreateUseableItem then
        return false
    end
    for itemName, handler in pairs(qbHandlers) do
        pcall(function()
            qb.Functions.CreateUseableItem(itemName, function(source, item)
                handler(source, CleanCarNormalizeItem(item))
            end)
        end)
    end
    return true
end

local esxHandlers = {}

local function tryBindEsxUseables()
    local ESX = CleanCarBridge.GetESX()
    if not ESX or not ESX.RegisterUsableItem then
        return false
    end
    for itemName, handler in pairs(esxHandlers) do
        pcall(function()
            ESX.RegisterUsableItem(itemName, function(source)
                handler(source, nil)
            end)
        end)
    end
    return true
end

local function registerUseableDeferred_qbx(itemName, handler)
    local trimmed = itemName:gsub("^%s*(.-)%s*$", "%1")
    local lower = trimmed:lower()
    qbxHandlers[lower] = handler
    if trimmed ~= lower then
        qbxHandlers[trimmed] = handler
    end
    if tryBindQbxUseables() then
        return
    end
    CreateThread(function()
        local n = 0
        local res = coreResQbx()
        while n < 200 do
            if GetResourceState(res) == "started" and tryBindQbxUseables() then
                return
            end
            n = n + 1
            Wait(50)
        end
    end)
end

local function registerUseableDeferred_qb(itemName, handler)
    local trimmed = itemName:gsub("^%s*(.-)%s*$", "%1")
    local lower = trimmed:lower()
    qbHandlers[lower] = handler
    if trimmed ~= lower then
        qbHandlers[trimmed] = handler
    end
    if tryBindQbUseables() then
        return
    end
    CreateThread(function()
        local n = 0
        while n < 200 do
            if tryBindQbUseables() then
                return
            end
            n = n + 1
            Wait(50)
        end
    end)
end

local function registerUseableDeferred_esx(itemName, handler)
    local trimmed = itemName:gsub("^%s*(.-)%s*$", "%1")
    local lower = trimmed:lower()
    esxHandlers[lower] = handler
    if trimmed ~= lower then
        esxHandlers[trimmed] = handler
    end
    if tryBindEsxUseables() then
        return
    end
    CreateThread(function()
        local n = 0
        while n < 200 do
            if tryBindEsxUseables() then
                return
            end
            n = n + 1
            Wait(50)
        end
    end)
end

function CleanCarBridge.RegisterUsableItem(itemName, handler)
    if CleanCarBridge.UseExternalBridge() then
        local ok, err = pcall(function()
            exports["Croll-Bridge"]:RegisterUseableItem(itemName, handler)
        end)
        if not ok then
            print(("[Croll-CleanCar] Croll-Bridge RegisterUseableItem failed: %s"):format(tostring(err)))
        end
        return
    end

    local fw = CleanCarBridge.DetectFramework()
    if fw == "qbx" then
        registerUseableDeferred_qbx(itemName, handler)
        return
    end
    if fw == "qb" then
        registerUseableDeferred_qb(itemName, handler)
        return
    end
    if fw == "esx" then
        registerUseableDeferred_esx(itemName, handler)
        return
    end
    print("[Croll-CleanCar] No supported framework detected (set Config.Framework to qbx, qb, or esx).")
end

AddEventHandler("onResourceStart", function(name)
    if CleanCarBridge.UseExternalBridge() then
        return
    end
    if name == coreResQbx() and CleanCarBridge.DetectFramework() == "qbx" then
        CreateThread(function()
            Wait(0)
            tryBindQbxUseables()
        end)
    end
    if name == coreResQb() and CleanCarBridge.DetectFramework() == "qb" then
        CreateThread(function()
            Wait(0)
            tryBindQbUseables()
        end)
    end
    if name == "es_extended" and CleanCarBridge.DetectFramework() == "esx" then
        CreateThread(function()
            Wait(100)
            tryBindEsxUseables()
        end)
    end
end)
