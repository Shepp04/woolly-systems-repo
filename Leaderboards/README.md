# Leaderboards System

A complete leaderboard system for displaying and managing player statistics using Roblox OrderedDataStores.

## Overview

The Leaderboards system provides:
- **Persistent leaderboards** using OrderedDataStores
- **Automatic stat saving** from player profiles
- **Customizable display** with default GUI generation
- **Multiple leaderboard support** in a single place
- **Automatic refresh** on configurable intervals

## System Structure

```
Leaderboards/
├── server/
│   ├── classes/
│   │   └── Leaderboard.luau        # Individual leaderboard instance
│   └── services/
│       └── LeaderboardService.luau # Main service managing all leaderboards
└── README.md                       # This file
```

## Quick Start

### 1. Setup Leaderboard Models

Create a Model in workspace for each leaderboard with:
- **Name**: Your leaderboard identifier (e.g., "TotalMilesLeaderboard")
- **Screen Part**: A part named "Screen" where the GUI will be displayed

Example structure:
```
workspace/
├── TotalMilesLeaderboard (Model)
│   └── Screen (Part)
├── CashLeaderboard (Model)
│   └── Screen (Part)
└── TotalStudsLeaderboard (Model)
    └── Screen (Part)
```

### 2. Register Leaderboards

In `LeaderboardService:Start()`, register your leaderboards:

```lua
function LeaderboardService:Start()
    if not self._inited or self._started then return end
    self._started = true

    self:_startAutoUpdate()

    -- Register leaderboards
    self:RegisterLeaderboard({
        datastoreName = "Total Miles",        -- OrderedDataStore name
        statPath = "Data.Analytics.TotalMiles", -- Path in player profile
        model = workspace:WaitForChild("TotalMilesLeaderboard"),
        maxEntries = 10,                      -- Top 10 players
        minDisplayValue = 1,                  -- Min value to appear
        userIdBlacklist = {},                 -- Optional blacklist
        gui = nil,                            -- nil = auto-generate GUI
    })
end
```

### 3. Configure Auto-Update Intervals

Adjust refresh and save intervals in the service:

```lua
local LeaderboardService = {
    _refreshInterval = 60, -- Refresh display every 60 seconds
    _saveInterval = 60,    -- Save player stats every 60 seconds
    -- ...
}
```

## Configuration Options

### LeaderboardOpts

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `datastoreName` | `string` | ✓ | Name of the OrderedDataStore to use |
| `statPath` | `string?` | ✓ | Path to stat in player profile (e.g., "Data.Stats.Cash") |
| `model` | `Model` | ✓ | The workspace model containing the Screen part |
| `maxEntries` | `number` | ✓ | Maximum number of entries to display |
| `minDisplayValue` | `number` | ✓ | Minimum value required to appear on leaderboard |
| `userIdBlacklist` | `{number}` | ✓ | Array of UserIds to exclude from leaderboard |
| `gui` | `SurfaceGui?` | | Custom GUI (nil to auto-generate) |

## Stat Path Examples

The `statPath` should match your profile structure:

```lua
-- For a profile structure like:
{
    Data = {
        Stats = {
            Cash = 1000,
            Miles = 50,
        },
        Analytics = {
            TotalMiles = 500,
            TotalStuds = 10000,
        }
    }
}

-- Use paths like:
statPath = "Data.Stats.Cash"
statPath = "Data.Stats.Miles"
statPath = "Data.Analytics.TotalMiles"
statPath = "Data.Analytics.TotalStuds"
```

## Custom GUI

If you want a custom GUI instead of the auto-generated one:

### GUI Structure Requirements

Your GUI must follow this hierarchy:

```
SurfaceGui or BillboardGui
└── Container (Frame)
    ├── Top (Frame) [Optional - shows headers]
    │   ├── PlayerIndex (TextLabel)
    │   ├── PlayerName (TextLabel)
    │   └── PlayerValue (TextLabel)
    ├── Items (ScrollingFrame)
    │   ├── UIListLayout
    │   └── ItemTemplate (Frame)
    │       ├── PlayerIndex (TextLabel)
    │       ├── PlayerName (TextLabel)
    │       └── PlayerValue (TextLabel)
```

### Using Custom GUI

```lua
local customGui = script.Parent.MyCustomLeaderboardGui:Clone()

self:RegisterLeaderboard({
    datastoreName = "Custom Stat",
    statPath = "Data.CustomStat",
    model = workspace.CustomLeaderboard,
    maxEntries = 20,
    minDisplayValue = 1,
    userIdBlacklist = {},
    gui = customGui, -- Provide your custom GUI
})
```

## API Reference

### LeaderboardService

#### Methods

##### `RegisterLeaderboard(opts: LeaderboardOpts): Leaderboard?`
Register a new leaderboard and return its instance.

```lua
local leaderboard = LeaderboardService:RegisterLeaderboard({
    datastoreName = "My Stat",
    statPath = "Data.Stats.MyStat",
    model = workspace.MyLeaderboard,
    maxEntries = 10,
    minDisplayValue = 1,
    userIdBlacklist = {},
})
```

##### `RefreshAllLeaderboards(): ()`
Manually refresh all registered leaderboards (fetches latest data from DataStore).

```lua
LeaderboardService:RefreshAllLeaderboards()
```

##### `SavePlayerStats(player: Player): ()`
Save a specific player's stats to all leaderboards.

```lua
LeaderboardService:SavePlayerStats(player)
```

### Leaderboard Class

#### Methods

##### `Refresh(): ()`
Refresh this leaderboard's display with latest data.

```lua
leaderboard:Refresh()
```

##### `SavePlayerStat(userId: number, value: number): boolean`
Save a specific stat value for a user.

```lua
local success = leaderboard:SavePlayerStat(123456789, 1000)
```

##### `GetDatastoreName(): string`
Get the OrderedDataStore name.

##### `GetStatPath(): string?`
Get the stat path in player profiles.

## How It Works

### Automatic System Flow

1. **Initialization**: LeaderboardService starts and registers all leaderboards
2. **Auto-Update Loop**: 
   - Every `_refreshInterval` seconds: Fetches latest data from OrderedDataStores and updates displays
   - Every `_saveInterval` seconds: Saves all online players' stats to OrderedDataStores
3. **Player Leaving**: When a player leaves, their stats are saved immediately

### Manual Control

You can manually trigger operations:

```lua
-- Refresh a specific leaderboard
leaderboard:Refresh()

-- Refresh all leaderboards
LeaderboardService:RefreshAllLeaderboards()

-- Save a player's stats
LeaderboardService:SavePlayerStats(player)
```

## Integration with DataInterface

The system automatically integrates with your DataInterface service to read player profile data:

```lua
-- In LeaderboardService:SavePlayerStats()
local profile = _deps.DataInterface:GetPlayerProfile(player, false)
local statValue = getStatFromProfile(profile, statPath)
```

Make sure your profile data structure matches the `statPath` you configure.

## OrderedDataStores

Each leaderboard uses its own OrderedDataStore identified by `datastoreName`:
- Stores data as `[userId] = statValue`
- Automatically sorted in descending order (highest values first)
- Respects Roblox DataStore API limits
- Handles errors gracefully with pcall wrapping

## Blacklisting Players

Prevent specific users from appearing on leaderboards:

```lua
self:RegisterLeaderboard({
    datastoreName = "Clean Leaderboard",
    statPath = "Data.Stats.Score",
    model = workspace.ScoreLeaderboard,
    maxEntries = 10,
    minDisplayValue = 1,
    userIdBlacklist = {
        123456789,  -- Banned user
        987654321,  -- Test account
    },
})
```

## Performance Considerations

- **DataStore Limits**: Each refresh calls `GetSortedAsync()`. Be mindful of Roblox's DataStore request limits.
- **Auto-Update Intervals**: Longer intervals (60s+) are recommended to avoid hitting rate limits.
- **Player Count**: Saving stats for many players simultaneously may require staggering or rate limiting.
- **GUI Updates**: The default GUI is optimized, but complex custom GUIs may impact performance.

## Troubleshooting

### Leaderboard not displaying

1. Check that the model exists in workspace
2. Verify the model has a "Screen" part
3. Ensure OrderedDataStore is accessible (Studio API access enabled)
4. Check output for warnings about missing GUI elements

### Stats not saving

1. Verify `statPath` matches your profile structure exactly
2. Check that DataInterface is returning valid profiles
3. Ensure value meets `minDisplayValue` threshold
4. Look for DataStore error messages in output

### Names showing as "Player"

This happens when:
- Player is offline and `GetNameFromUserIdAsync()` fails (API limit hit)
- Player has privacy settings preventing name lookups
- Consider caching names in your profile data

## Example: Complete Setup

```lua
-- In LeaderboardService:Start()
function LeaderboardService:Start()
    if not self._inited or self._started then return end
    self._started = true

    self:_startAutoUpdate()

    -- Miles leaderboard
    self:RegisterLeaderboard({
        datastoreName = "Total Miles",
        statPath = "Data.Analytics.TotalMiles",
        model = workspace:WaitForChild("TotalMilesLeaderboard"),
        maxEntries = 10,
        minDisplayValue = 1,
        userIdBlacklist = {},
        gui = nil,
    })

    -- Cash leaderboard with custom minimum
    self:RegisterLeaderboard({
        datastoreName = "Cash",
        statPath = "Data.Stats.Cash",
        model = workspace:WaitForChild("CashLeaderboard"),
        maxEntries = 15,
        minDisplayValue = 100, -- Only show players with 100+ cash
        userIdBlacklist = {123456}, -- Exclude test account
        gui = nil,
    })

    -- Custom GUI leaderboard
    local customGui = ReplicatedStorage.CustomLeaderboardGui:Clone()
    self:RegisterLeaderboard({
        datastoreName = "Custom Stat",
        statPath = "Data.CustomStat",
        model = workspace:WaitForChild("CustomLeaderboard"),
        maxEntries = 20,
        minDisplayValue = 1,
        userIdBlacklist = {},
        gui = customGui,
    })
end
```

## License

This system is part of the woolly project framework.
