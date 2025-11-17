--!strict
-- TeleporterService (Service) — lifecycle-first singleton discovered by Services registry.

-- // Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- // Classes
local TeleporterClass = require(ServerScriptService.Server.Classes.Teleporter)

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

export type TeleporterServiceAPI = {
	_inited: boolean,
	_started: boolean,
	_conns: { RBXScriptConnection },
	Priority: number?,
	Services: ServiceRegistry, -- optional backref to the registry, filled by bootstrapper

	Init: (self: TeleporterServiceAPI, deps: Deps) -> (),
	Start: (self: TeleporterServiceAPI) -> (),
	Destroy: (self: TeleporterServiceAPI) -> (),
}

local TeleporterService = {
	_inited = false,
	_started = false,
	_conns = {},
	Priority = 50, -- higher -> starts earlier
	Services = {} :: ServiceRegistry,
}

-- Private captured deps for intellisense-friendly access
local _deps: Deps?

-- ========== Life Cycle ========== --

function TeleporterService:Init(deps: Deps)
	if self._inited then return end
	self._inited = true
	self._conns = {}
	_deps = deps

	-- // Example: get/create remotes
end

function TeleporterService:Start()
	if not self._inited or self._started then return end
	self._started = true

	-- // Example: connect remotes, start loops, etc.

	-- Create teleporters
	local teleportersFolder = workspace:WaitForChild("Teleporters")
	local teleporterObjects = {}
	for _, v in teleportersFolder:GetChildren() do
		if not v:IsA("Model") then continue end

		local object
		if v.Name == "MainTeleporter" then
			object = TeleporterClass.new(_deps, { teleportPlaceId = 124240592130904, model = v, countdown = 25, teleporterType = "Public", minPlayers = 2, maxPlayers = 25 })
		end
		if v.Name == "PartyTeleporter" then
			object = TeleporterClass.new(_deps, { teleportPlaceId = 124240592130904, model = v, countdown = 10, teleporterType = "Party", minPlayers = 2, maxPlayers = 25 })
		end
		if object then
			object:Init()
			table.insert(teleporterObjects, object)
		end
	end
end

function TeleporterService:Destroy()
	for _, conn in self._conns do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(self._conns)
	_deps = nil
	self._started = false
	self._inited = false
end

return TeleporterService :: TeleporterServiceAPI
