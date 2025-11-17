# Nametags System

A lightweight custom nametag system that replaces Roblox's default nametags with customizable BillboardGuis for player characters.

## Overview

The Nametags system provides:
- **Custom nametag UI** above player heads
- **Automatic setup** on character spawn
- **Default nametag hiding** (disables Roblox's built-in nametags)
- **Update API** for dynamic content changes
- **Character respawn handling** with automatic reattachment
- **Extensible design** for additional nametag elements (health bars, titles, badges, etc.)

## System Structure

```
Nametags/
├── server/
│   └── services/
│       └── NametagService.luau    # Main service for nametag management
└── README.md                      # This file
```

## Quick Start

### 1. Create Nametag UI Asset

Create a BillboardGui template in `ReplicatedStorage.Shared.Assets.UI`:

```
ReplicatedStorage/
└── Shared/
    └── Assets/
        └── UI/
            └── Nametag (BillboardGui)
                ├── Size: UDim2.new(6, 0, 1, 0)
                ├── StudsOffset: Vector3.new(0, 2, 0)
                ├── AlwaysOnTop: true
                └── Frame
                    └── PlayerName (TextLabel)
                        ├── Text: ""
                        ├── TextScaled: true
                        └── BackgroundTransparency: 1
```

### 2. Service Auto-Starts

The service automatically initializes when the game starts. No additional setup required!

```lua
-- NametagService automatically:
-- 1. Connects to Players.PlayerAdded
-- 2. Waits for character spawns
-- 3. Hides default Roblox nametags
-- 4. Clones and attaches custom nametag
-- 5. Updates nametag content
```

### 3. Update Nametags Dynamically

Use the `Update()` method to refresh nametag content:

```lua
local NametagService = Services.NametagService

-- Update a specific player's nametag
NametagService:Update(player)
```

## Configuration

### Nametag Asset Requirements

**Location:** `ReplicatedStorage.Shared.Assets.UI.Nametag`

**Required Structure:**
```
Nametag (BillboardGui)
└── Frame (Frame)                  -- First Frame child
    └── PlayerName (TextLabel)     -- TextLabel for player name
```

**Recommended Properties:**

| Property | Value | Purpose |
|----------|-------|---------|
| `Size` | `UDim2.new(6, 0, 1, 0)` | Width in studs, height in studs |
| `StudsOffset` | `Vector3.new(0, 2, 0)` | Position above head |
| `AlwaysOnTop` | `true` | Visible through walls |
| `MaxDistance` | `100` (optional) | Visibility range |
| `LightInfluence` | `0` (optional) | Ignore lighting |

### Additional Assets (Optional)

The system references additional assets for potential extensions:

**DogTag** (Model): `ReplicatedStorage.Assets.Models.DogTag`
- Physical dog tag model for character customization
- Not currently implemented in base system

**BackTag** (Model): `ReplicatedStorage.Assets.Models.BackTag`
- Back-mounted tag model for character customization
- Not currently implemented in base system

## API Reference

### NametagService

#### Public Methods

##### `Update(player: Player): void`
Updates the nametag for a specific player.

```lua
-- Update player's nametag
NametagService:Update(player)
```

**Parameters:**
- `player: Player` - The player whose nametag should be updated

**Behavior:**
1. Finds player's character
2. Locates `_Nametag` BillboardGui in character
3. Updates `PlayerName` TextLabel with `player.Name`
4. Returns early if character or nametag not found

**Use Cases:**
- Update nametag after nickname change
- Refresh nametag with new title/rank
- Apply custom formatting based on player state

**Example with custom logic:**
```lua
-- Override Update() to add custom content
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    
    -- Custom: Add VIP prefix
    local prefix = player:GetAttribute("VIP") and "[VIP] " or ""
    playerNameLabel.Text = prefix .. player.Name
end
```

---

#### Lifecycle Methods

##### `Init(deps: Deps): void`
Initializes the service with dependencies.

```lua
NametagService:Init(deps)
```

Called automatically by the service registry. Sets up internal state.

---

##### `Start(): void`
Starts the service and connects event listeners.

```lua
NametagService:Start()
```

**Automatic behavior:**
- Connects to `Players.PlayerAdded`
- Handles existing players already in game
- Sets up character spawn listeners
- Priority: 50 (starts early)

---

##### `Destroy(): void`
Cleans up the service.

```lua
NametagService:Destroy()
```

Disconnects all event connections and clears internal state.

---

#### Internal Methods (For Extension)

##### `_onCharacterAdded(player: Player, char: Model): void`
Handles character spawn and nametag setup.

```lua
function NametagService:_onCharacterAdded(player, char)
    -- 1. Disable default Roblox nametag
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    
    -- 2. Check for existing nametag
    local nametag = char:FindFirstChild("_Nametag")
    if nametag then 
        self:Update(player)
        return 
    end
    
    -- 3. Clone and attach nametag
    nametag = SampleNametag:Clone()
    nametag.Name = "_Nametag"
    nametag.Adornee = char:WaitForChild("Head")
    nametag.Parent = char
    
    -- 4. Initialize content
    self:Update(player)
end
```

---

##### `_onPlayerAdded(player: Player): void`
Handles player joining and sets up character listeners.

```lua
function NametagService:_onPlayerAdded(player)
    -- Handle initial character
    local char = player.Character or player.CharacterAdded:Wait()
    self:_onCharacterAdded(player, char)
    
    -- Listen for respawns
    player.CharacterAdded:Connect(function(char)
        self:_onCharacterAdded(player, char)
    end)
end
```

## Nametag Lifecycle

### 1. Player Joins Server
```lua
Players.PlayerAdded → NametagService:_onPlayerAdded(player)
```

### 2. Character Spawns
```lua
player.CharacterAdded → NametagService:_onCharacterAdded(player, char)
```

### 3. Nametag Setup
```lua
1. Disable Roblox nametag: humanoid.DisplayDistanceType = None
2. Clone template: SampleNametag:Clone()
3. Attach to head: nametag.Adornee = head
4. Parent to character: nametag.Parent = char
5. Update content: self:Update(player)
```

### 4. Character Respawn
```lua
CharacterAdded → _onCharacterAdded() → Reattaches nametag
```

## Customization Examples

### Adding Health Bar

```lua
-- Modify _onCharacterAdded to add health bar
function NametagService:_onCharacterAdded(player: Player, char: Model)
    local human = char:WaitForChild("Humanoid")
    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local nametag = SampleNametag:Clone()
    nametag.Name = "_Nametag"
    nametag.Parent = char
    nametag.Adornee = char:WaitForChild("Head")

    -- Add health bar
    local frame = nametag:FindFirstChildOfClass("Frame")
    local healthBar = Instance.new("Frame")
    healthBar.Name = "HealthBar"
    healthBar.Size = UDim2.new(1, 0, 0.2, 0)
    healthBar.Position = UDim2.new(0, 0, 0.8, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = frame
    
    -- Update health bar on health change
    human.HealthChanged:Connect(function(health)
        local healthPercent = health / human.MaxHealth
        healthBar.Size = UDim2.new(healthPercent, 0, 0.2, 0)
    end)

    self:Update(player)
end
```

### Adding Player Titles

```lua
-- Extend Update() to show player titles
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    local titleLabel = frame:FindFirstChild("Title")
    
    -- Update name
    playerNameLabel.Text = player.Name
    
    -- Update title (from profile or attribute)
    if titleLabel then
        local profile = _deps.DataInterface:Get(player)
        if profile then
            titleLabel.Text = profile.Data.Title or ""
        end
    end
end
```

### Adding Team Colors

```lua
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    
    -- Color by team
    if player.Team then
        playerNameLabel.TextColor3 = player.Team.TeamColor.Color
    else
        playerNameLabel.TextColor3 = Color3.new(1, 1, 1)
    end
    
    playerNameLabel.Text = player.Name
end
```

### Adding Distance Scaling

```lua
-- Modify nametag template or add in _onCharacterAdded
function NametagService:_onCharacterAdded(player: Player, char: Model)
    local human = char:WaitForChild("Humanoid")
    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local nametag = SampleNametag:Clone()
    nametag.Name = "_Nametag"
    nametag.Parent = char
    nametag.Adornee = char:WaitForChild("Head")
    
    -- Add distance scaling
    nametag.MaxDistance = 100 -- Fade out at 100 studs
    nametag.Size = UDim2.new(6, 0, 1, 0)
    nametag.StudsOffset = Vector3.new(0, 2, 0)
    
    self:Update(player)
end
```

### Adding Rank Badges

```lua
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    local badgeImage = frame:FindFirstChild("Badge")
    
    playerNameLabel.Text = player.Name
    
    -- Show badge for premium players
    if badgeImage then
        if player.MembershipType == Enum.MembershipType.Premium then
            badgeImage.Image = "rbxassetid://123456789"
            badgeImage.Visible = true
        else
            badgeImage.Visible = false
        end
    end
end
```

## Integration with Other Systems

### With DataInterface

```lua
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    
    -- Get player data
    local profile = _deps.DataInterface:Get(player)
    if profile then
        local level = profile.Data.Stats.Level or 1
        playerNameLabel.Text = `[Lv.{level}] {player.Name}`
    else
        playerNameLabel.Text = player.Name
    end
end
```

### With ReplicatedData

```lua
-- In Init(), listen for data changes
function NametagService:Init(deps: Deps)
    if self._inited then return end
    self._inited = true
    _deps = deps
    
    -- Update nametags when stats change
    local ReplicatedData = deps.SharedPackages.ReplicatedData
    ReplicatedData:ListenToCategory("Stats", function(player, category, key, value)
        if key == "Level" or key == "Rank" then
            self:Update(player)
        end
    end)
    
    self._conns = {}
end
```

### With Monetisation (VIP)

```lua
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    
    -- Check for VIP gamepass
    local hasVIP = false
    local vipGamepass = _deps.Monetisation.Gamepasses:Find("VIP")
    if vipGamepass then
        hasVIP = _deps.Monetisation.Gamepasses:Owns(player, vipGamepass)
    end
    
    local prefix = hasVIP and "⭐ " or ""
    playerNameLabel.Text = prefix .. player.Name
end
```

## Performance Considerations

- **Minimal overhead**: Only updates on spawn/explicit call
- **No continuous polling**: No RunService loops or frequent updates
- **Efficient cloning**: Clones from single template reference
- **Early cleanup**: Returns early if character/nametag missing
- **Event-driven**: Only processes when players join or respawn

## Common Patterns

### Manual Update on Event

```lua
-- Update nametag when player levels up
local function onPlayerLevelUp(player)
    NametagService:Update(player)
end
```

### Batch Update All Players

```lua
-- Update all player nametags
local function updateAllNametags()
    for _, player in Players:GetPlayers() do
        NametagService:Update(player)
    end
end
```

### Conditional Nametag Visibility

```lua
function NametagService:_onCharacterAdded(player: Player, char: Model)
    local human = char:WaitForChild("Humanoid")
    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local nametag = SampleNametag:Clone()
    nametag.Name = "_Nametag"
    nametag.Parent = char
    nametag.Adornee = char:WaitForChild("Head")
    
    -- Hide nametag for spectators
    if player:GetAttribute("IsSpectator") then
        nametag.Enabled = false
    end
    
    self:Update(player)
end
```

### Dynamic Size Adjustment

```lua
function NametagService:Update(player: Player)
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag")
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame")
    local playerNameLabel = frame:FindFirstChild("PlayerName")
    
    playerNameLabel.Text = player.Name
    
    -- Adjust size based on name length
    local nameLength = #player.Name
    if nameLength > 15 then
        nametag.Size = UDim2.new(8, 0, 1, 0)
    else
        nametag.Size = UDim2.new(6, 0, 1, 0)
    end
end
```

## Troubleshooting

### Nametags not appearing
1. Check `Nametag` asset exists in `ReplicatedStorage.Shared.Assets.UI`
2. Verify asset has correct structure (Frame → PlayerName TextLabel)
3. Check output for errors during character spawn
4. Ensure service is started (check Priority and Init/Start calls)

### Default Roblox nametags still showing
1. Verify `humanoid.DisplayDistanceType` is set to `None`
2. Check `_onCharacterAdded` is being called
3. Ensure no other scripts are resetting DisplayDistanceType

### Nametags not updating
1. Call `NametagService:Update(player)` after data changes
2. Check player.Character exists before update
3. Verify `_Nametag` exists in character model
4. Ensure Frame and PlayerName children exist

### Nametags disappearing on respawn
1. Verify `player.CharacterAdded` connection is active
2. Check `_onCharacterAdded` is called on respawn
3. Ensure no scripts are destroying nametag on spawn

### Performance issues
1. Avoid updating nametags in loops (use events)
2. Don't update nametags per-frame (use Heartbeat sparingly)
3. Check for memory leaks in custom nametag logic
4. Limit MaxDistance to reduce render load

## Migration Guide

### From Default Roblox Nametags

1. **No changes needed** - System automatically hides default nametags
2. **Create UI asset** in `ReplicatedStorage.Shared.Assets.UI.Nametag`
3. **Service auto-starts** on game launch
4. **Test in-game** to verify nametags appear

### From Legacy Custom Nametag System

1. **Replace legacy service** with NametagService
2. **Move nametag template** to `ReplicatedStorage.Shared.Assets.UI.Nametag`
3. **Update structure** to match required format (Frame → PlayerName)
4. **Migrate custom logic** to `Update()` method
5. **Remove old event connections** (handled by new service)

### Adding to Existing Project

1. Copy `NametagService.luau` to `src/_systems/Nametags/server/services/`
2. Create nametag template in ReplicatedStorage
3. Service will auto-register with service registry
4. Call `Update(player)` when data changes

## Advanced Examples

### Animated Nametags

```lua
function NametagService:_onCharacterAdded(player: Player, char: Model)
    local human = char:WaitForChild("Humanoid")
    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local nametag = SampleNametag:Clone()
    nametag.Name = "_Nametag"
    nametag.Parent = char
    nametag.Adornee = char:WaitForChild("Head")
    
    -- Animate nametag on spawn
    local frame = nametag:FindFirstChildOfClass("Frame")
    frame.Size = UDim2.new(0, 0, 0, 0)
    
    local tween = game:GetService("TweenService"):Create(
        frame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(1, 0, 1, 0) }
    )
    tween:Play()
    
    self:Update(player)
end
```

### Multiple Nametag Styles

```lua
-- Different nametag templates
local VIPNametag = UIAssets:WaitForChild("VIPNametag")
local AdminNametag = UIAssets:WaitForChild("AdminNametag")

function NametagService:_onCharacterAdded(player: Player, char: Model)
    local human = char:WaitForChild("Humanoid")
    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    -- Choose template based on player status
    local template = SampleNametag
    if player:GetRankInGroup(123456) >= 255 then
        template = AdminNametag
    elseif player.MembershipType == Enum.MembershipType.Premium then
        template = VIPNametag
    end
    
    local nametag = template:Clone()
    nametag.Name = "_Nametag"
    nametag.Parent = char
    nametag.Adornee = char:WaitForChild("Head")
    
    self:Update(player)
end
```

### Proximity-Based Updates

```lua
-- Update nametags based on nearby players (for complex info)
local RunService = game:GetService("RunService")

function NametagService:Start()
    if not self._inited or self._started then return end
    self._started = true

    table.insert(self._conns, Players.PlayerAdded:Connect(function(player)
        self:_onPlayerAdded(player)
    end))
    
    -- Update nametags near local player (if running on client)
    -- For server, use more efficient event-based updates
end
```

## Security Considerations

- **Server-side only**: All nametag logic runs on server (trusted)
- **No client input**: Players cannot modify others' nametags
- **Template cloning**: Each player gets isolated nametag instance
- **Safe updates**: Update() validates character existence before access

## Best Practices

1. **Keep Update() lightweight** - Called frequently during gameplay
2. **Cache references** - Store commonly used values in service state
3. **Use events for updates** - Don't poll or update every frame
4. **Validate before access** - Always check character/nametag exists
5. **Test with respawns** - Ensure nametags persist across character reloads
6. **Consider performance** - Limit MaxDistance for large servers
7. **Use RunService sparingly** - Prefer event-driven updates

## License

This system is part of the woolly project framework.
