--!strict
-- LeaderboardService (Service) — lifecycle-first singleton discovered by Services registry.

-- // Roblox Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- // Classes
local LeaderboardClass = require(ServerScriptService.Server.Classes.Leaderboard)
type Leaderboard = LeaderboardClass.LeaderboardAPI
type LeaderboardOpts = LeaderboardClass.Opts

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

export type LeaderboardServiceAPI = {
	_inited: boolean,
	_started: boolean,
	_conns: { RBXScriptConnection },
	_leaderboards: { Leaderboard },
	_refreshInterval: number,
	_saveInterval: number,
	_lastRefresh: number,
	_lastSave: number,
	Priority: number?,
	Services: ServiceRegistry, -- optional backref to the registry, filled by bootstrapper

	Init: (self: LeaderboardServiceAPI, deps: Deps) -> (),
	Start: (self: LeaderboardServiceAPI) -> (),
	Destroy: (self: LeaderboardServiceAPI) -> (),
	
	-- Public API
	RegisterLeaderboard: (self: LeaderboardServiceAPI, opts: LeaderboardOpts) -> Leaderboard?,
	RefreshAllLeaderboards: (self: LeaderboardServiceAPI) -> (),
	SavePlayerStats: (self: LeaderboardServiceAPI, player: Player) -> (),
	
	-- Private methods
	_getStatFromProfile: (profile: any, statPath: string) -> number?,
	_saveAllPlayerStats: (self: LeaderboardServiceAPI) -> (),
	_startAutoUpdate: (self: LeaderboardServiceAPI) -> (),
}

local LeaderboardService = {
	_inited = false,
	_started = false,
	_conns = {},
	_leaderboards = {},
	_refreshInterval = 60, -- Refresh display every 60 seconds
	_saveInterval = 60,    -- Save player stats every 60 seconds
	_lastRefresh = 0,
	_lastSave = 0,
	Priority = 50, -- higher -> starts earlier
	Services = {} :: ServiceRegistry,
}

-- Private captured deps for intellisense-friendly access
local _deps: Deps?

-- ========== Private Helper Functions ========== --

local function getStatFromProfile(profile: any, statPath: string): number?
	if not profile or not statPath then
		return nil
	end
	
	-- Split the path by dots (e.g., "Data.Stats.Miles" -> {"Data", "Stats", "Miles"})
	local parts = string.split(statPath, ".")
	local current = profile
	
	-- Traverse the path
	for _, part in ipairs(parts) do
		if type(current) ~= "table" then
			return nil
		end
		current = current[part]
		if current == nil then
			return nil
		end
	end
	
	-- Ensure the final value is a number
	if type(current) == "number" then
		return current
	end

	return nil
end

-- ========== Life Cycle ========== --

function LeaderboardService:Init(deps: Deps)
	if self._inited then return end
	self._inited = true
	self._conns = {}
	self._leaderboards = {}
	_deps = deps

	-- Listen for player leaving to save their stats one last time
	table.insert(self._conns, Players.PlayerRemoving:Connect(function(player)
		self:SavePlayerStats(player)
	end))
end

function LeaderboardService:Start()
	if not self._inited or self._started then return end
	self._started = true

	-- Start automatic update loop
	self:_startAutoUpdate()

	-- Create initial leaderboards here if desired
	-- Examples:
	self:RegisterLeaderboard({
		datastoreName = "Total Miles",
		statPath = "Data.Analytics.TotalMiles",
		model = workspace:WaitForChild("TotalMilesLeaderboard") :: Model,
		maxEntries = 10,
		minDisplayValue = 1,
		userIdBlacklist = {},
		gui = nil,
	})

	self:RegisterLeaderboard({
		datastoreName = "Total Studs",
		statPath = "Data.Analytics.TotalStuds",
		model = workspace:WaitForChild("TotalStudsLeaderboard") :: Model,
		maxEntries = 10,
		minDisplayValue = 1,
		userIdBlacklist = {},
		gui = nil,
	})

	self:RegisterLeaderboard({
		datastoreName = "Cash",
		statPath = "Data.Stats.Cash",
		model = workspace:WaitForChild("CashLeaderboard") :: Model,
		maxEntries = 10,
		minDisplayValue = 1,
		userIdBlacklist = {},
		gui = nil,
	})
end

function LeaderboardService:RegisterLeaderboard(opts: LeaderboardOpts): Leaderboard?
	if not _deps then
		warn("[LeaderboardService] Cannot register leaderboard: Service not initialized")
		return nil
	end
	
	-- Create leaderboard instance
	local leaderboard = LeaderboardClass.new({
		ReplicatedData = nil, -- Not needed for leaderboards
		Services = self.Services,
		SharedPackages = _deps.SharedPackages,
		GameData = _deps.GameData,
		Monetisation = _deps.Monetisation,
		Config = _deps.Config,
	}, opts)
	
	-- Initialize the leaderboard
	leaderboard:Init()
	
	-- Add to registry
	table.insert(self._leaderboards, leaderboard)
	
	print(`[LeaderboardService] Registered leaderboard: {opts.datastoreName}`)
	
	return leaderboard
end

function LeaderboardService:RefreshAllLeaderboards()
	for _, leaderboard in ipairs(self._leaderboards) do
		task.spawn(function()
			leaderboard:Refresh()
		end)
	end
	
	self._lastRefresh = os.clock()
end

function LeaderboardService:SavePlayerStats(player: Player)
	if not _deps or not _deps.DataInterface then
		return
	end
	
	-- Get player's profile
	local profile = _deps.DataInterface:GetPlayerProfile(player, false)
	if not profile then
		return
	end
	
	-- Save to all leaderboards that have a statPath
	for _, leaderboard in ipairs(self._leaderboards) do
		local statPath = leaderboard:GetStatPath()
		if statPath then
			local statValue = getStatFromProfile(profile, statPath)
			if statValue then
				task.spawn(function()
					leaderboard:SavePlayerStat(player.UserId, statValue)
				end)
			else
				warn(`[LeaderboardService] Could not get stat value for player {player.Name} at path {statPath}`)
			end
		end
	end
end

function LeaderboardService:_saveAllPlayerStats()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:SavePlayerStats(player)
		end)
	end
	
	self._lastSave = os.clock()
end

function LeaderboardService:_startAutoUpdate()
	-- Use Heartbeat for timing checks
	table.insert(self._conns, RunService.Heartbeat:Connect(function()
		local now = os.clock()
		
		-- Check if it's time to refresh leaderboards
		if now - self._lastRefresh >= self._refreshInterval then
			self:RefreshAllLeaderboards()
		end
		
		-- Check if it's time to save player stats
		if now - self._lastSave >= self._saveInterval then
			self:_saveAllPlayerStats()
		end
	end))
	
	-- Do initial refresh and save
	self:RefreshAllLeaderboards()
	self:_saveAllPlayerStats()
	
	print(`[LeaderboardService] Auto-update started (refresh: {self._refreshInterval}s, save: {self._saveInterval}s)`)
end

function LeaderboardService:Destroy()
	-- Destroy all leaderboards
	for _, leaderboard in ipairs(self._leaderboards) do
		leaderboard:Destroy()
	end
	table.clear(self._leaderboards)
	
	-- Disconnect connections
	for _, conn in self._conns do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(self._conns)
	
	_deps = nil
	self._started = false
	self._inited = false
end

return LeaderboardService :: LeaderboardServiceAPI
