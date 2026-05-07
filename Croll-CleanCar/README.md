# Croll-CleanCar

Secure, optimized FiveM vehicle cleaning script with multi-framework support.

## Features

- Framework support: `qbx`, `qb`, `esx`, plus `auto` detection.
- Inventory support: `ox`, `qb`, `esx`, `tgiann`, `codem`, `origen`, plus `auto` detection.
- Optional bridge mode via `Croll-Bridge`.
- Server-authoritative validation:
  - source checks
  - vehicle net ID validation
  - vehicle entity type validation
  - distance checks
  - item ownership checks
  - cooldown and event rate limiting
- Optional item durability (full metadata durability on `ox_inventory`).
- Locale support (`locales/en.lua` included).

## Requirements

- FiveM artifact with Lua 5.4 enabled.
- One of: `qbx_core`, `qb-core`, or `es_extended`.
- One supported inventory (or framework native inventory fallback).
- Optional but recommended: `ox_lib`.

## Installation

1. Place the resource in your server resources folder.
2. Ensure it in `server.cfg` after your framework/inventory resources:
   - `ensure Croll-CleanCar`
3. Create the configured item in your inventory item definitions:
   - default: `rag`
4. Restart the resource/server.

## Configuration

Main config file: `config.lua`

- `Config.Framework`: `auto | qbx | qb | esx`
- `Config.Inventory`: `auto | ox | qb | esx | tgiann | codem | origen`
- `Config.ExternalBridge`: `auto | none | croll-bridge`
- `Config.ItemName`: item required to clean (default `rag`)
- `Config.CleanDurationMs`: cleaning duration
- `Config.MaxDistance`: max interaction distance
- `Config.CleanCooldownMs`: per-player clean cooldown
- `Config.MinServerRpcIntervalMs`: anti-spam RPC gap
- `Config.ServerMaxDistanceClamp`: server-side range hard clamp

### Durability

`Config.Durability` controls optional use-based item consumption:

- `Enabled`: turns durability on/off
- `MaxUses`: starting uses when metadata is missing
- `MetadataKey`: metadata field for remaining uses (default `cleancar_uses`)

Notes:

- `ox_inventory`: full per-slot metadata durability is supported.
- Other inventories currently fallback to removing one full item per clean.
- For best durability behavior on `ox_inventory`, keep rags non-stackable (or one rag per slot).

## Security Model

Client events are never trusted for final state changes.

Server validates all important actions before consumption:

- player identity/source
- entity existence and type
- range/proximity
- inventory ownership
- anti-spam and cooldowns

This prevents basic spoofing/replay/abuse vectors on clean completion.

## Locale

Default locale file:

- `locales/en.lua`

To add a new language:

1. Create `locales/<lang>.lua`
2. Add translated keys
3. Set `Config.Locale = "<lang>"`

## Exports and internals

The script is split by responsibility:

- `client.lua`: clean flow + visual handling
- `server.lua`: authoritative validation + consumption
- `bridge/shared.lua`: shared helpers/framework detection
- `bridge/client.lua`: notify/progress abstraction
- `bridge/server.lua`: framework/inventory abstraction

## License

Open-source release by DrCroll. Add your preferred license file for distribution.
