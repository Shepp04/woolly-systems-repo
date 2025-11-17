# Currency System

A complete currency management system with client-side UI, animations, multipliers, and integration with player profiles and leaderboards.

## Overview

The Currency system provides:
- **Multiple currency types** (Cash, Miles, etc.)
- **Profile integration** with automatic saving
- **Leaderstats support** with configurable positioning
- **Multipliers system** (friends, temporary boosts, rebirths)
- **Client UI components** with animated currency drops
- **Sound effects** for earning and spending
- **Earned prompts** to show currency gains
- **Dev Products & Gamepasses** monetization hooks

## System Structure

```
Currency/
├── server/
│   └── services/
│       └── CurrencyService.luau        # Main currency management service
├── client/
│   ├── controllers/
│   │   ├── UICurrencyController.luau   # UI updates and sounds
│   │   └── CurrencyDropsController.luau # Animated currency drops
│   └── components/
│       └── CurrencyDisplay.luau        # Reusable UI component
├── shared/
│   ├── utils/
│   │   └── Currency.luau               # Helper functions
│   └── assets/
│       └── ui/
│           ├── CurrencyValueGui.rbxmx  # Drop value display
│           └── CurrencyEarnedPrompt.rbxmx # Earn notification
├── data_types/
│   └── Currency.luau                   # Currency definitions
├── monetisation/
│   ├── DevProducts.luau                # Dev product handlers
│   └── Gamepasses.luau                 # Gamepass handlers
└── README.md                           # This file
```

## Quick Start

### 1. Define Your Currencies

Edit `data_types/Currency.luau` to define your game's currencies:

```lua
local DATA: { [string]: DataEntry } = {
    Cash = {
        name = "Cash",
        symbol = "$",
        icon = "rbxassetid://139861974184937",
        collectSoundId = 7112275565,
        spendSoundId = 81816893340749,
        defaultValue = 0,
        earnedPromptEnabled = true,
        useLeaderstats = true,
        leaderstatsPosition = 1,
        friendBoostMultiplier = 1.1, -- 10% boost per friend

        Get = function(profile: PlayerProfile): number
            return profile.Data.Stats.Cash or 0
        end,

        Set = function(player: Player, profile: PlayerProfile, amount: number)
            profile.Data.Stats.Cash = amount
        end,
        
        Update = function(player: Player, profile: PlayerProfile, amount: number)
            profile.Data.Stats.Cash += amount
        end,
    },
}
```

### 2. Use Currency Service

The service is automatically initialized. Use it in your game logic:

```lua
local CurrencyService = Services.CurrencyService

-- Give currency to player
CurrencyService:GiveCurrency(player, "Cash", 100, true, true)
-- Args: player, currencyId, amount, useMultipliers?, showDrops?

-- Spend currency
if CurrencyService:SpendCurrency(player, "Cash", 50) then
    print("Purchase successful!")
end

-- Check affordability
if CurrencyService:CanAfford(player, "Cash", 100, true) then
    -- true = shows message to player if they can't afford
    print("Player can afford this")
end
```

### 3. Setup Client UI

The UI is automatically managed by `UICurrencyController`. Configure display paths in `CurrencyDisplay.luau`:

```lua
local LABEL_PATHS: {[string]: {string}} = {
    Cash = {"Coin", "Amount"},     -- PlayerGui.Main.Coin.Amount
    Miles = {"Miles", "Amount"},    -- PlayerGui.Main.Miles.Amount
}
```

Your UI structure should look like:
```
PlayerGui/
└── Main (ScreenGui)
    ├── Coin (Frame)
    │   └── Amount (TextLabel)
    └── Miles (Frame)
        └── Amount (TextLabel)
```

## Currency Definition Properties

### Required Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Display name of the currency |
| `symbol` | `string` | Symbol prefix (e.g., "$", "⭐") or "" for none |
| `defaultValue` | `number` | Starting amount for new players |
| `useLeaderstats` | `boolean` | Show in player.leaderstats folder |
| `Get` | `function` | Reads currency value from profile |
| `Set` | `function` | Sets absolute currency value |
| `Update` | `function` | Adds/subtracts from currency |

### Optional Properties

| Property | Type | Description |
|----------|------|-------------|
| `icon` | `string?` | Asset ID for currency icon |
| `collectSoundId` | `number?` | Sound to play when earning |
| `spendSoundId` | `number?` | Sound to play when spending |
| `earnedPromptEnabled` | `boolean?` | Show popup when earning |
| `leaderstatsPosition` | `number?` | Order in leaderstats (1 = first) |
| `friendBoostMultiplier` | `number?` | Multiplier per friend in server (e.g., 1.1 = +10%) |
| `rebirthMultiplier` | `number?` | Multiplier per rebirth level |
| `collectables` | `{Collectable}?` | Physical models for currency drops |

## API Reference

### CurrencyService

#### Server Methods

##### `GiveCurrency(player, currencyId, amount, useMultipliers?, showDrops?): boolean`
Adds currency to a player.

```lua
-- Simple give
CurrencyService:GiveCurrency(player, "Cash", 100)

-- With multipliers and visual drops
CurrencyService:GiveCurrency(player, "Cash", 100, true, true)
```

**Parameters:**
- `player: Player` - Target player
- `currencyId: string` - Currency identifier (e.g., "Cash")
- `amount: number` - Amount to give (≥0, will be clamped)
- `useMultipliers: boolean?` - Apply friend/rebirth/boost multipliers
- `showDrops: boolean?` - Show animated drops on client

**Returns:** `boolean` - Success status

---

##### `SpendCurrency(player, currencyId, amount): boolean`
Removes currency from player if they can afford it.

```lua
if CurrencyService:SpendCurrency(player, "Cash", 500) then
    -- Award purchased item
end
```

**Parameters:**
- `player: Player`
- `currencyId: string`
- `amount: number`

**Returns:** `boolean` - True if transaction succeeded

---

##### `CanAfford(player, currencyId, amount, promptUser?): boolean`
Checks if player has enough currency.

```lua
-- Silent check
if CurrencyService:CanAfford(player, "Cash", 100) then
    print("Can afford")
end

-- With user prompt if insufficient
if CurrencyService:CanAfford(player, "Cash", 100, true) then
    -- Shows "You need $50!" message if player only has 50
end
```

**Parameters:**
- `player: Player`
- `currencyId: string`
- `amount: number`
- `promptUser: boolean?` - Show UI message if insufficient funds

**Returns:** `boolean`

---

##### `SetCurrency(player, currencyId, amount): boolean`
Sets currency to an absolute value.

```lua
-- Reset player's cash
CurrencyService:SetCurrency(player, "Cash", 0)

-- Set to specific amount
CurrencyService:SetCurrency(player, "Miles", 50)
```

**Parameters:**
- `player: Player`
- `currencyId: string`
- `amount: number`

**Returns:** `boolean`

---

##### `GetCurrencyMultiplier(player, currencyId): number`
Calculates total multiplier for a player's currency.

```lua
local mult = CurrencyService:GetCurrencyMultiplier(player, "Cash")
print("Total multiplier:", mult) -- e.g., 2.5 (250% earnings)
```

Includes:
- **Friend boosts**: Each friend in server adds `friendBoostMultiplier`
- **Temporary boosts**: From `profile.Info.Multipliers`
- **Rebirth multipliers**: Based on `profile.Data.Stats.Rebirths`

**Returns:** `number` (minimum 1.0)

---

##### `SetMultiplier(player, multiplierId, currencyId, multiplier, duration?): boolean`
Sets a temporary or permanent multiplier.

```lua
-- Temporary 2x boost for 300 seconds
CurrencyService:SetMultiplier(player, "DoubleXP", "Cash", 2.0, 300)

-- Permanent 1.5x boost
CurrencyService:SetMultiplier(player, "VIPBoost", "Cash", 1.5)
```

**Parameters:**
- `player: Player`
- `multiplierId: string` - Unique identifier for this multiplier
- `currencyId: string` - Which currency to boost
- `multiplier: number` - Multiplier value (e.g., 2.0 = double)
- `duration: number?` - Seconds (nil = permanent)

**Returns:** `boolean`

**Notes:**
- Multipliers are additive: 1.5x + 2.0x = 3.5x total
- Auto-removes temporary multipliers after duration
- Stores in `profile.Info.Multipliers[multiplierId]`

### CurrencyUtil (Shared)

##### `GetCurrencyText(currencyId, amount, useCurrencyName?): string`
Formats currency amount as text.

```lua
local text = CurrencyUtil.GetCurrencyText("Cash", 100)
print(text) -- "$100"

local text2 = CurrencyUtil.GetCurrencyText("Cash", 100, true)
print(text2) -- "100 Cash"
```

### Client Controllers

#### CurrencyDropsController

##### `DropCurrency(currencyId, amount)`
Show animated currency drop effect.

```lua
-- Triggered automatically when server calls GiveCurrency with showDrops=true
-- Can also be called manually:
CurrencyDropsController:DropCurrency("Cash", 50)
```

## Multipliers System

### How Multipliers Work

Multipliers are **additive bonuses** on top of the base 1.0 multiplier:

```lua
-- Base: 1.0 (100%)
-- +2 friends × 0.1 each = +0.2
-- +1 temp boost of 1.5 = +0.5
-- +3 rebirths × 0.25 each = +0.75
-- Total = 1.0 + 0.2 + 0.5 + 0.75 = 2.45 (245%)
```

### Types of Multipliers

#### 1. Friend Boost
Configured per currency via `friendBoostMultiplier`:

```lua
Cash = {
    friendBoostMultiplier = 1.1, -- +10% per friend
    -- Each friend in server adds 0.1 to the multiplier
}
```

#### 2. Temporary Boosts
Set via `SetMultiplier()` with duration:

```lua
-- 2x earnings for 5 minutes
CurrencyService:SetMultiplier(player, "PowerHour", "Cash", 2.0, 300)
```

Stored in `profile.Info.Multipliers`:
```lua
{
    PowerHour = {
        Value = 2.0,
        EndTime = 1700000000,
        LastUpdate = 1699999700,
        CurrencyId = "Cash",
        IsPermanent = false,
    }
}
```

#### 3. Permanent Boosts
Set via `SetMultiplier()` without duration:

```lua
-- Permanent VIP boost
CurrencyService:SetMultiplier(player, "VIP", "Cash", 1.5)
```

#### 4. Rebirth Multiplier
Automatic based on rebirth count:

```lua
Cash = {
    rebirthMultiplier = 0.25, -- +25% per rebirth
}

-- Player with 5 rebirths gets +125% (1.25x) bonus
```

## Leaderstats Integration

Currencies automatically appear in `player.leaderstats` when `useLeaderstats = true`:

```lua
Cash = {
    name = "Cash",
    useLeaderstats = true,
    leaderstatsPosition = 1, -- Shows first
}

Miles = {
    name = "Total Miles",
    useLeaderstats = true,
    leaderstatsPosition = 2, -- Shows second
}
```

**Result:**
```
Players/
└── PlayerName/
    └── leaderstats/
        ├── Cash (NumberValue) = 1000
        └── Total Miles (NumberValue) = 50
```

## Profile Structure

The system expects this profile structure:

```lua
{
    Data = {
        Stats = {
            Cash = 0,
            Miles = 0,
            Rebirths = 0,
        }
    },
    Info = {
        Multipliers = {
            BoostId = {
                Value = 2.0,
                EndTime = nil,
                LastUpdate = 0,
                CurrencyId = "Cash",
                IsPermanent = true,
            }
        }
    }
}
```

Adjust the `Get`, `Set`, and `Update` functions in your currency definitions to match your profile structure.

## Client UI Integration

### Automatic Updates

`UICurrencyController` automatically:
- Updates UI when currency changes via `ReplicatedData`
- Plays collect sound when currency increases
- Plays spend sound when currency decreases
- Shows earned prompts when `earnedPromptEnabled = true`

### Custom UI Paths

Configure where currency displays in your UI:

```lua
-- In CurrencyDisplay.luau
local LABEL_PATHS: {[string]: {string}} = {
    Cash = {"TopBar", "Cash", "Amount"},
    Miles = {"TopBar", "Miles", "Value"},
}
```

This maps to:
```
PlayerGui.Main.TopBar.Cash.Amount
PlayerGui.Main.TopBar.Miles.Value
```

### Currency Drops

Animated drops are triggered by:
```lua
CurrencyService:GiveCurrency(player, "Cash", 100, true, true)
--                                                       ^^^^ showDrops
```

Or manually:
```lua
-- On client
CurrencyDropsController:DropCurrency("Cash", 50)
```

## Monetization Integration

### Dev Products

Define in `monetisation/DevProducts.luau`:

```lua
local Handlers: { [string]: Handler } = {
    Buy100Cash = function(player: Player, profile: any, product: any)
        Services.CurrencyService:GiveCurrency(player, "Cash", 100, false, true)
        return true
    end,
}

local defs = {
    devProducts = {
        {
            id = "Buy100Cash",
            devProductId = 1234567890,
            name = "100 Cash",
            price = 99,
            icon = "rbxassetid://123456",
            handler = Handlers.Buy100Cash,
        }
    }
}
```

### Gamepasses

Define in `monetisation/Gamepasses.luau`:

```lua
local Handlers: { [string]: Handler } = {
    CashBoost = function(player: Player, profile: any, product: any)
        -- Apply permanent multiplier
        Services.CurrencyService:SetMultiplier(
            player, 
            "VIPCashBoost", 
            "Cash", 
            2.0 -- 2x cash earnings
        )
        return true
    end,
}

local defs = {
    gamepasses = {
        {
            id = "CashBoost",
            gamepassId = 1234567890,
            name = "2x Cash",
            price = 499,
            icon = "rbxassetid://123456",
            handler = Handlers.CashBoost,
        }
    }
}
```

## Sound Effects

Configure sounds per currency:

```lua
Cash = {
    collectSoundId = 7112275565,  -- Plays when earning
    spendSoundId = 81816893340749, -- Plays when spending
}
```

Sounds are automatically played by `UICurrencyController` when currency changes.

## Performance Considerations

- **Leaderstats Updates**: Only updates when value actually changes
- **Multiplier Calculations**: Cached per transaction, not per frame
- **UI Updates**: Throttled by ReplicatedData update rate
- **Friend Checks**: Only done during `GetCurrencyMultiplier()` call
- **Temporary Multipliers**: Auto-cleanup via `task.delay()` (no continuous polling)

## Common Patterns

### Reward System
```lua
-- Simple reward
CurrencyService:GiveCurrency(player, "Cash", 100, true, true)

-- Reward with message
CurrencyService:GiveCurrency(player, "Cash", 100, true, true)
Messages:ShowMessage(player, "Quest completed! +$100", "Success")
```

### Shop Purchase
```lua
local price = 500
if CurrencyService:CanAfford(player, "Cash", price, true) then
    if CurrencyService:SpendCurrency(player, "Cash", price) then
        -- Give purchased item
        InventoryService:GiveItem(player, "Sword")
    end
end
```

### VIP Pass
```lua
-- On gamepass purchase
local function onVIPPurchased(player)
    -- Permanent 2x cash boost
    CurrencyService:SetMultiplier(player, "VIP_Cash", "Cash", 2.0)
    
    -- Permanent 1.5x miles boost
    CurrencyService:SetMultiplier(player, "VIP_Miles", "Miles", 1.5)
end
```

### Double XP Weekend
```lua
-- Start event
for _, player in Players:GetPlayers() do
    CurrencyService:SetMultiplier(player, "Weekend2X", "Cash", 2.0, 172800) -- 48 hours
end
```

### Admin Commands
```lua
Commands.SetCash = function(admin: Player, target: Player, amount: number)
    CurrencyService:SetCurrency(target, "Cash", amount)
    Messages:ShowMessage(admin, `Set {target.Name}'s cash to {amount}`, "Success")
end
```

## Troubleshooting

### Currency not showing in leaderstats
1. Check `useLeaderstats = true` in currency definition
2. Verify `_buildLeaderstatsValues()` is called in `_onPlayerAdded()`
3. Check profile is loaded before leaderstats creation

### Multipliers not applying
1. Ensure `useMultipliers = true` in `GiveCurrency()` call
2. Check `GetCurrencyMultiplier()` returns > 1.0
3. Verify `profile.Info.Multipliers` exists in profile structure

### UI not updating
1. Check `ReplicatedData` is updating the "Stats" category
2. Verify `LABEL_PATHS` match your UI structure exactly
3. Ensure `UICurrencyController` is started

### Sounds not playing
1. Check `collectSoundId` and `spendSoundId` are valid asset IDs
2. Verify `SharedPackages.Sounds` exists and works
3. Ensure sound is not muted in game settings

### Earned prompts not showing
1. Set `earnedPromptEnabled = true` in currency definition
2. Check `CurrencyEarnedPrompt` asset exists in `Assets.UI`
3. Verify currency increase is detected (not just setting to same value)

## Migration Guide

### From Legacy Currency System

1. **Update Get/Set/Update functions** to match your profile structure
2. **Configure leaderstats positions** if order matters
3. **Add multiplier support** via `SetMultiplier()`
4. **Hook monetization** in DevProducts/Gamepasses files
5. **Test UI integration** with ReplicatedData

### Adding New Currency

1. Add definition to `data_types/Currency.luau`
2. Update `LABEL_PATHS` in `CurrencyDisplay.luau`
3. Create UI elements in PlayerGui
4. Test Get/Set/Update functions
5. Configure sounds and icons

## Example: Complete Currency Setup

```lua
-- In data_types/Currency.luau
Gems = {
    name = "Gems",
    symbol = "💎",
    icon = "rbxassetid://123456789",
    collectSoundId = 7112275565,
    spendSoundId = 81816893340749,
    defaultValue = 0,
    earnedPromptEnabled = true,
    rebirthMultiplier = 0.5,
    useLeaderstats = true,
    leaderstatsPosition = 3,
    friendBoostMultiplier = 1.05,

    Get = function(profile)
        return profile.Data.Stats.Gems or 0
    end,

    Set = function(player, profile, amount)
        profile.Data.Stats.Gems = amount
    end,
    
    Update = function(player, profile, amount)
        profile.Data.Stats.Gems += amount
    end,
}

-- In CurrencyDisplay.luau
local LABEL_PATHS = {
    Cash = {"TopBar", "Cash", "Amount"},
    Miles = {"TopBar", "Miles", "Amount"},
    Gems = {"TopBar", "Gems", "Amount"}, -- Add new path
}

-- Usage in game
CurrencyService:GiveCurrency(player, "Gems", 10, true, true)
```

## License

This system is part of the woolly project framework.
