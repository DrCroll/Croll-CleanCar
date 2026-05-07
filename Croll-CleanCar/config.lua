Config = {}

-- Locale key from locales/*.lua
Config.Locale = "en"

--[[
    Framework: auto | qbx | qb | esx
    - auto: qbx_core → qb-core → es_extended
]]
Config.Framework = "auto"

--[[
    Inventory: auto | ox | qb | esx | tgiann | codem | origen
    - auto: ox_inventory → origen_inventory → tgiann-inventory → codem-inventory → then esx native or qb Player.Functions
]]
Config.Inventory = "auto"

--[[
    ExternalBridge: auto | none | croll-bridge
    - auto / croll-bridge: use exports['Croll-Bridge'] for RegisterUseableItem / GetItemCount / RemoveItem when that resource is started.
      Configure BridgeConfig inside Croll-Bridge (framework + inventory).
    - none: use the built-in standalone bridge in bridge/server.lua + bridge/client.lua.
]]
Config.ExternalBridge = "none"

-- Resource names if you renamed cores (optional)
Config.Core = {
    qbxResource = "qbx_core",
    qbResource = "qb-core",
}

-- Item name in your inventory (must match items database / shared items).
Config.ItemName = "rag"

-- Cleaning settings
Config.CleanDurationMs = 5000
Config.MaxDistance = 5.0

-- Anti-spam between server checks (milliseconds).
Config.CleanCooldownMs = 1500

-- Minimum gap between server RPC handlers (canClean / finishClean) per player — reduces event spam cost.
Config.MinServerRpcIntervalMs = 250

-- Hard clamp for MaxDistance on the server (prevents misconfiguration / excessive reach).
Config.ServerMaxDistanceClamp = { min = 1.0, max = 25.0 }

--[[
    Durability (optional): track remaining uses per stack via item metadata.
    Full support: ox_inventory — stores integer remaining uses under MetadataKey on the equipped slot.
    Other inventories: falls back to removing one whole item per clean (warning printed once in server console).
]]
Config.Durability = {
    Enabled = false,
    MaxUses = 5,
    MetadataKey = "cleancar_uses",
}

-- For ox_inventory + durability: non-stackable items (or single rag per slot) keep uses predictable; stacked copies share one metadata table.
