--[[
    Shared helpers (locale + inventory item payload normalization).
]]

CleanCarBridge = CleanCarBridge or {}

function CleanCarBridge.CoreQbx()
    return (Config.Core and Config.Core.qbxResource) or "qbx_core"
end

function CleanCarBridge.CoreQb()
    return (Config.Core and Config.Core.qbResource) or "qb-core"
end

local fwAutoCache
local fwAutoCacheAt = 0
local FW_DETECT_CACHE_MS = 4000

function CleanCarBridge.DetectFramework()
    local f = Config.Framework
    if type(f) == "string" and f ~= "" and f ~= "auto" then
        return f
    end
    local t = GetGameTimer()
    if fwAutoCache and (t - fwAutoCacheAt) < FW_DETECT_CACHE_MS then
        return fwAutoCache
    end
    local resolved
    if GetResourceState(CleanCarBridge.CoreQbx()) == "started" then
        resolved = "qbx"
    elseif GetResourceState(CleanCarBridge.CoreQb()) == "started" then
        resolved = "qb"
    elseif GetResourceState("es_extended") == "started" then
        resolved = "esx"
    else
        resolved = "qb"
    end
    fwAutoCache = resolved
    fwAutoCacheAt = t
    return resolved
end

AddEventHandler("onResourceStart", function(name)
    if name == CleanCarBridge.CoreQbx() or name == CleanCarBridge.CoreQb() or name == "es_extended" then
        fwAutoCacheAt = 0
    end
end)

function CleanCarLocale(key, ...)
    local lang = (Config and Config.Locale) or "en"
    local pack = Locales[lang] or Locales["en"]
    local fmt = (pack and pack[key]) or (Locales["en"] and Locales["en"][key]) or key
    if select("#", ...) > 0 then
        return string.format(fmt, ...)
    end
    return fmt
end

function CleanCarNormalizeItem(payload)
    if type(payload) ~= "table" then
        return payload
    end
    if type(payload.metadata) == "table" then
        return payload
    end
    local meta = payload.info or payload.information
    if type(meta) ~= "table" then
        return payload
    end
    local out = {}
    for k, v in pairs(payload) do
        out[k] = v
    end
    out.metadata = meta
    return out
end
