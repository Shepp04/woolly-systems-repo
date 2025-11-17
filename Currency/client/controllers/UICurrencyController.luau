--!strict
-- UICurrencyController (Controller) — client controller discovered by Controllers registry.

-- // Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- // Types (generated)
local ControllersTypes = require(ReplicatedStorage.Shared.Types.Controllers)

-- // Components
local CurrencyDisplay = require(script.Parent.Parent.Components.CurrencyDisplay)

-- // Type aliases for deps inferred from real modules
type ControllerRegistry = ControllersTypes.Registry

type ReplicatedData = typeof(require(ReplicatedStorage.Shared.Packages.ReplicatedData))
type SharedPackages = typeof(require(ReplicatedStorage.Shared.Packages))
type GameData       = typeof(require(ReplicatedStorage.Shared.GameData))
type Monetisation   = typeof(require(ReplicatedStorage.Shared.Monetisation))
type Config         = typeof(require(ReplicatedStorage.Shared.Config))

export type Deps = {
	ReplicatedData: ReplicatedData,
	SharedPackages: SharedPackages,
	GameData: GameData,
	Monetisation: Monetisation,
	Config: Config,
}

export type UICurrencyControllerAPI = {
	_inited: boolean,
	_started: boolean,
	_conns: { RBXScriptConnection },
	Priority: number?,
	Controllers: ControllerRegistry, -- optional backref to the registry, filled by bootstrapper

	Init: (self: UICurrencyControllerAPI, deps: Deps) -> (),
	Start: (self: UICurrencyControllerAPI) -> (),
	Destroy: (self: UICurrencyControllerAPI) -> (),
}

local UICurrencyController = {
	_inited = false,
	_started = false,
	_conns = {},
	Priority = 50, -- higher -> starts earlier
	Controllers = {} :: ControllerRegistry,
} :: UICurrencyControllerAPI

-- Private captured deps for intellisense-friendly access
local _deps: Deps?
local _currencyDisplay: any = nil
local _currentCurrencyData: {[string]: number}? = nil

-- ========== Private Functions ========== --

local function onStatsChanged(data: any)
	_currencyDisplay:SetMany(data)
	
	_currentCurrencyData = _currentCurrencyData or {}
	for currencyId, val in data do
		local currencyInfo = _deps.GameData.Get("Currency", currencyId)
		if not currencyInfo then
			continue
		end

		if _currentCurrencyData[currencyId] then
			if (val - _currentCurrencyData[currencyId]) > 0 then
				if currencyInfo.earnedPromptEnabled then
					-- Show currency earned prompt
					_currencyDisplay:ShowCurrencyEarnedPrompt(currencyId, val - _currentCurrencyData[currencyId])
				end

				-- Play a collection sound
				if currencyInfo.collectSoundId then
					_deps.SharedPackages.Sounds:PlaySound(currencyInfo.collectSoundId)
				end
			elseif (val - _currentCurrencyData[currencyId]) < 0 then
				-- Play a spending sound
				if currencyInfo.spendSoundId then
					_deps.SharedPackages.Sounds:PlaySound(currencyInfo.spendSoundId)
				end
			end
		end
		_currentCurrencyData[currencyId] = val
	end
end

-- ========== Life Cycle ========== --

function UICurrencyController:Init(deps: Deps)
	if self._inited then return end
	self._inited = true
	self._conns = {}
	_deps = deps

	-- Initialize CurrencyDisplay component
	_currencyDisplay = CurrencyDisplay.new()
	_currencyDisplay:Init({
		GameData = deps.GameData,
	})
end

function UICurrencyController:Start()
	if not self._inited or self._started then return end
	self._started = true

	-- Initial read
	local playerStatsData = _deps.ReplicatedData:GetData("Stats", true)
	if (playerStatsData) then 
		onStatsChanged(playerStatsData) 
	end
	
	-- Get data updates
	table.insert(self._conns, _deps.ReplicatedData.OnUpdate.Event:Connect(function(category: string, data: any)
		if (category == "Stats") then
			onStatsChanged(data)
		end
	end))
end

function UICurrencyController:Destroy()
	for _, conn in self._conns do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(self._conns)
	
	if _currencyDisplay then
		_currencyDisplay:Destroy()
		_currencyDisplay = nil
	end
	
	_currentCurrencyData = nil
	_deps = nil
	self._started = false
	self._inited = false
end

return UICurrencyController :: UICurrencyControllerAPI
