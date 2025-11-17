--!strict

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- // Assets
local ModelAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Models")
local SampleDogTag = ModelAssets:WaitForChild("DogTag")
local SampleBackTag = ModelAssets:WaitForChild("BackTag")

local UIAssets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"):WaitForChild("UI")
local SampleNametag = UIAssets:WaitForChild("Nametag")

-- // Types (generated)
local ServicesTypes = require(ReplicatedStorage.Shared.Types.Services)

-- // Type aliases for deps inferred from real modules
type ServiceRegistry = ServicesTypes.Registry

type DataInterface  = ServicesTypes.DataInterface
type SharedPackages = typeof(require(ReplicatedStorage.Shared.Packages))
type GameData       = typeof(require(ReplicatedStorage.Shared.GameData))
type Monetisation   = typeof(require(ReplicatedStorage.Shared.Monetisation))
type Config         = typeof(require(ReplicatedStorage.Shared.Config))

export type Deps = {
	DataInterface: DataInterface,
	SharedPackages: SharedPackages,
	GameData: GameData,
	Monetisation: Monetisation,
	Config: Config,
}

export type NametagServiceAPI = {
    _inited: boolean,
    _started: boolean,
    _conns: { RBXScriptConnection },

    Init: (self: NametagServiceAPI, deps: Deps) -> (),
    Start: (self: NametagServiceAPI) -> (),
    Destroy: (self: NametagServiceAPI) -> (),
}

local NametagService = {
    _inited = false,
    _started = false,
    _conns = {},
    Priority = 50, -- start early
    Services = nil :: any -- auto-filled by bootstrapper
}

-- // Private State
local _deps: Deps?

-- ========== Public API ========== --
function NametagService:Update(player: Player)
    -- Find their character
    local char = player.Character
    local nametag = char and char:FindFirstChild("_Nametag") :: BillboardGui
    if not nametag then return end
    
    local frame = nametag:FindFirstChildOfClass("Frame") :: Frame

    local playerNameLabel = frame:FindFirstChild("PlayerName") :: TextLabel
    playerNameLabel.Text = player.Name
end

-- ========== Internal ========== --

function NametagService:_onCharacterAdded(player: Player, char: Model)
    local human = char:WaitForChild("Humanoid") :: Humanoid
    human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

    local nametag = char:FindFirstChild("_Nametag")
    if nametag then self:Update(player); return end

    nametag = SampleNametag:Clone()
    nametag.Name = "_Nametag"
    nametag.Parent = char
    nametag.Adornee = char:WaitForChild("Head") :: BasePart

    self:Update(player)
end

function NametagService:_onPlayerAdded(player: Player)
    local char = player.Character or player.CharacterAdded:Wait()
    self:_onCharacterAdded(player, char)

    player.CharacterAdded:Connect(function(...)
        self:_onCharacterAdded(player, ...)
    end)
end

-- ========== Life Cycle ========== --
function NametagService:Init(deps: Deps)
    if self._inited then return end
    self._inited = true
    _deps = deps

    self._conns = {}
end

function NametagService:Start()
    if not self._inited or self._started then return end
    self._started = true

    -- // Example: connect remotes
    table.insert(self._conns, Players.PlayerAdded:Connect(function(...)
        self:_onPlayerAdded(...)
    end))
end

function NametagService:Destroy()
    for _, c in self._conns do c:Disconnect() end
    table.clear(self._conns)
    _deps = nil
    self._started = false
    self._inited = false
end

return NametagService :: NametagServiceAPI