--!strict
-- Teleporter (Server Class)

-- // Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

-- // Assets
local Assets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets")
local LeaveTeleportQueueGui = Assets:WaitForChild("UI"):WaitForChild("LeaveTeleportQueueGui")
local ReserveTeleportPartyGui = Assets:WaitForChild("UI"):WaitForChild("ReserveTeleportPartyGui")

-- // Types
local ServicesTypes = require(ReplicatedStorage.Shared.Types.Services)

-- // Type aliases for deps
type ServiceRegistry = ServicesTypes.Registry

type ReplicatedData = typeof(require(ReplicatedStorage.Shared.Packages.ReplicatedData))
type SharedPackages = typeof(require(ReplicatedStorage.Shared.Packages))
type GameData       = typeof(require(ReplicatedStorage.Shared.GameData))
type Monetisation   = typeof(require(ReplicatedStorage.Shared.Monetisation))
type Config         = typeof(require(ReplicatedStorage.Shared.Config))

export type Deps = {
	ReplicatedData: ReplicatedData,
	Services: ServiceRegistry,
	SharedPackages: SharedPackages,
	GameData: GameData,
	Monetisation: Monetisation,
	Config: Config,
}

export type TeleporterType = "Public" | "Party"

export type Opts = {
	minPlayers: number?,
	maxPlayers: number?,
	teleportPlaceId: number?,
	countdown: number?,
	instantTeleportOnFull: boolean?,
	teleporterType: TeleporterType?,
	model: Model,
}

export type TeleporterAPI = {
	_opts: Opts,
	_conns: { RBXScriptConnection },
	_model: Model,
	_trigger: BasePart,
	_spawnCFrame: CFrame,
	_gui: BillboardGui,
	_messageLabel: TextLabel,
	_countdownLabel: TextLabel,
	_queue: { Player },
	_countdownThread: thread?,
	_teleporterType: TeleporterType,
	_partySize: number?,
	_isLocked: boolean,
	_partyReservationThread: thread?,
	_partyLeader: Player?,
	_isFriendsOnly: boolean,
	_isOnCooldown: boolean,
	_cooldownThread: thread?,

	Init: (self: TeleporterAPI) -> (),
	UpdateText: (self: TeleporterAPI, message: string?, countdown: number?) -> (),
	Destroy: (self: TeleporterAPI) -> (),

	_validateModel: (self: TeleporterAPI) -> boolean,
	_createPlaceholderGui: (self: TeleporterAPI) -> BillboardGui,
	_onTriggerTouched: (self: TeleporterAPI, hit: BasePart) -> (),
	_addPlayerToQueue: (self: TeleporterAPI, player: Player) -> (),
	_removePlayerFromQueue: (self: TeleporterAPI, player: Player, removeGui: boolean?, teleportAway: boolean?) -> (),
	_startCountdown: (self: TeleporterAPI) -> (),
	_cancelCountdown: (self: TeleporterAPI) -> (),
	_teleportPlayers: (self: TeleporterAPI) -> (),
	_onPlayerRemoving: (self: TeleporterAPI, player: Player) -> (),
	_onCharacterDied: (self: TeleporterAPI, player: Player) -> (),
	_onPlayerLeaveQueue: (self: TeleporterAPI, player: Player) -> (),
	_createLeaveQueueGui: (self: TeleporterAPI, player: Player) -> (),
	_removeLeaveQueueGui: (self: TeleporterAPI, player: Player) -> (),
	_createReservePartyGui: (self: TeleporterAPI, player: Player) -> (),
	_removeReservePartyGui: (self: TeleporterAPI, player: Player) -> (),
	_createTeleportFadeGui: (self: TeleporterAPI, player: Player) -> (),
	_startPartyReservationTimeout: (self: TeleporterAPI, player: Player) -> (),
	_cancelPartyReservationTimeout: (self: TeleporterAPI) -> (),
	_onCreateTeleportParty: (self: TeleporterAPI, player: Player, partySize: number) -> (),
	_onCancelTeleportPartyReservation: (self: TeleporterAPI, player: Player) -> (),
	_startCooldown: (self: TeleporterAPI) -> (),
	_cancelCooldown: (self: TeleporterAPI) -> (),
}

local Teleporter = {}
Teleporter.__index = Teleporter

-- Private captured deps
local _deps: Deps?

-- // Constants
local HIDDEN_TELEPORT_CFRAME = CFrame.new(-200, 5, 0)

-- Class-level registry to track which players are in any teleporter queue
-- Maps Player -> Teleporter instance
local _playerToTeleporter: { [Player]: TeleporterAPI } = {}

-- Remote event for leaving queue (initialized once)
local _leaveQueueRemote: RemoteEvent?
local _createTeleportPartyRemote: RemoteEvent?
local _cancelTeleportPartyReservationRemote: RemoteEvent?

-- ========== Helpers ========== --

--[[
	isPlayerInQueue
	Checks if a player is already in the teleporter queue

	@param queue: { Player }, The queue to search
	@param player: Player, The player to find

	@return inQueue: boolean, True if player is in queue
]]
local function isPlayerInQueue(queue: { Player }, player: Player): boolean
	for _, plr in queue do
		if plr == player then
			return true
		end
	end
	return false
end

-- ========== Constructor ========== --

--[[
	new
	Creates a new Teleporter instance

	@param deps: Deps, Dependency injection container
	@param opts: Opts?, Configuration options

	@return teleporter: TeleporterAPI, The new teleporter instance
]]
function Teleporter.new(deps: Deps, opts: Opts?): TeleporterAPI
	_deps = deps

	local self = setmetatable({} :: any, Teleporter) :: TeleporterAPI
	self._opts = opts or {} :: Opts
	self._conns = {}
	self._queue = {}
	self._countdownThread = nil
	self._partySize = nil
	self._isLocked = false
	self._partyReservationThread = nil
	self._partyLeader = nil
	self._isFriendsOnly = false
	self._isOnCooldown = false
	self._cooldownThread = nil

	-- Set properties with defaults
	self._opts.minPlayers = self._opts.minPlayers or 1
	self._opts.maxPlayers = self._opts.maxPlayers or 16
	self._opts.teleportPlaceId = self._opts.teleportPlaceId or 0
	self._opts.countdown = self._opts.countdown or 30
	self._opts.instantTeleportOnFull = if self._opts.instantTeleportOnFull ~= nil then self._opts.instantTeleportOnFull else true
	self._teleporterType = self._opts.teleporterType or "Public"

	-- Validate model
	if not self._opts.model then
		error("[Teleporter] Model is required in opts")
	end

	self._model = self._opts.model

	if not self:_validateModel() then
		error(`[Teleporter] Model {self._model:GetFullName()} failed validation`)
	end

	return self
end

-- ========== Public API ========== --

--[[
	Init
	Initializes the teleporter, setting up connections and GUI
]]
function Teleporter:Init()
	-- Initialize the remote events (once per class)
	if not _leaveQueueRemote and _deps then
		_leaveQueueRemote = _deps.SharedPackages.Remotes:GetRemote("RemoteEvent", "LeaveTeleportQueue") :: RemoteEvent
		
		-- Connect the leave queue remote event handler
		_leaveQueueRemote.OnServerEvent:Connect(function(player: Player)
			-- Find which teleporter this player is in
			local teleporter = _playerToTeleporter[player]
			if teleporter then
				teleporter:_onPlayerLeaveQueue(player)
			end
		end)
	end

	if not _createTeleportPartyRemote and _deps then
		_createTeleportPartyRemote = _deps.SharedPackages.Remotes:GetRemote("RemoteEvent", "CreateTeleportParty") :: RemoteEvent
		
		-- Connect the create teleport party remote event handler
		_createTeleportPartyRemote.OnServerEvent:Connect(function(player: Player, partySize: number, isFriendsOnly: boolean)
			-- Find which teleporter this player is in
			local teleporter = _playerToTeleporter[player]
			if teleporter then
				teleporter:_onCreateTeleportParty(player, partySize, isFriendsOnly)
			end
		end)
	end

	if not _cancelTeleportPartyReservationRemote and _deps then
		_cancelTeleportPartyReservationRemote = _deps.SharedPackages.Remotes:GetRemote("RemoteEvent", "CancelTeleportPartyReservation") :: RemoteEvent
		
		-- Connect the cancel teleport party reservation remote event handler
		_cancelTeleportPartyReservationRemote.OnServerEvent:Connect(function(player: Player)
			-- Find which teleporter this player is in
			local teleporter = _playerToTeleporter[player]
			if teleporter then
				teleporter:_onCancelTeleportPartyReservation(player)
			end
		end)
	end

	-- Connect trigger touch event
	table.insert(self._conns, self._trigger.Touched:Connect(function(hit)
		self:_onTriggerTouched(hit)
	end))

	-- Connect player removing event
	table.insert(self._conns, Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end))

	-- Initialize text
	self:UpdateText("Waiting for players...", nil)
end

--[[
	UpdateText
	Updates the GUI text labels

	@param message: string?, Optional message to display
	@param countdown: number?, Optional countdown value to display
]]
function Teleporter:UpdateText(message: string?, countdown: number?)
	if message then
		self._messageLabel.Text = message
	end

	if countdown then
		self._countdownLabel.Text = `{countdown}s`
		self._countdownLabel.Visible = true
	else
		self._countdownLabel.Visible = false
	end
end

--[[
	Destroy
	Cleans up the teleporter instance
]]
function Teleporter:Destroy()
	self:_cancelCountdown()
	self:_cancelCooldown()

	for _, c in self._conns do
		pcall(function() c:Disconnect() end)
	end
	table.clear(self._conns)
	table.clear(self._queue)
	_deps = nil
end

-- ========== Internal ========== --

--[[
	_validateModel
	Validates that the model contains required parts and sets up references

	@return isValid: boolean, True if model is valid
]]
function Teleporter:_validateModel(): boolean
	local trigger = self._model:FindFirstChild("Trigger")
	if not trigger or not trigger:IsA("BasePart") then
		warn(`[Teleporter] Model {self._model:GetFullName()} has no Trigger part`)
		return false
	end

	self._trigger = trigger :: BasePart

	-- Determine spawn CFrame
	local playerSpawn = self._model:FindFirstChild("PlayerSpawn")
	if playerSpawn and playerSpawn:IsA("BasePart") then
		self._spawnCFrame = playerSpawn.CFrame
	else
		self._spawnCFrame = self._model:GetPivot()
	end

	-- Get or create GUI
	local gui = self._model:FindFirstChild("TeleportGui")
	if gui and gui:IsA("BillboardGui") then
		self._gui = gui :: BillboardGui
	else
		-- warn(`[Teleporter] Model {self._model:GetFullName()} has no TeleportGui, creating placeholder`)
		self._gui = self:_createPlaceholderGui(trigger)
	end

	-- Get text labels
	local messageLabel = self._gui:FindFirstChild("Message")
	local countdownLabel = self._gui:FindFirstChild("Countdown")

	if not messageLabel or not messageLabel:IsA("TextLabel") then
		-- warn(`[Teleporter] TeleportGui missing Message TextLabel, creating placeholder`)
		messageLabel = Instance.new("TextLabel")
		messageLabel.Name = "Message"
		messageLabel.Size = UDim2.new(1, 0, 0.5, 0)
		messageLabel.Position = UDim2.new(0, 0, 0, 0)
		messageLabel.BackgroundTransparency = 1
		messageLabel.TextScaled = true
		messageLabel.TextColor3 = Color3.new(1, 1, 1)
		messageLabel.Parent = self._gui
	end

	if not countdownLabel or not countdownLabel:IsA("TextLabel") then
		-- warn(`[Teleporter] TeleportGui missing Countdown TextLabel, creating placeholder`)
		countdownLabel = Instance.new("TextLabel")
		countdownLabel.Name = "Countdown"
		countdownLabel.Size = UDim2.new(1, 0, 0.5, 0)
		countdownLabel.Position = UDim2.new(0, 0, 0.5, 0)
		countdownLabel.BackgroundTransparency = 1
		countdownLabel.TextScaled = true
		countdownLabel.TextColor3 = Color3.new(1, 1, 0)
		countdownLabel.Parent = self._gui
	end

	self._messageLabel = messageLabel :: TextLabel
	self._countdownLabel = countdownLabel :: TextLabel

	return true
end

--[[
	_createPlaceholderGui
	Creates a placeholder BillboardGui for the teleporter

	@return gui: BillboardGui, The created GUI
]]
function Teleporter:_createPlaceholderGui(adornee: BasePart?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "TeleportGui"
	gui.Size = UDim2.new(6, 0, 3, 0)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = adornee
	gui.Parent = self._model

	return gui
end

--[[
	_onTriggerTouched
	Handles trigger touch events

	@param hit: BasePart, The part that touched the trigger
]]
function Teleporter:_onTriggerTouched(hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Check if player is already in queue
	if isPlayerInQueue(self._queue, player) then
		return
	end

	-- Check if player is in ANY teleporter queue
	if _playerToTeleporter[player] then
		return
	end

	-- Check if teleporter is locked (party reservation in progress)
	if self._isLocked then
		return
	end

	-- Check if teleporter is on cooldown
	if self._isOnCooldown then
		return
	end

	-- For party teleporters with friends-only restriction, verify friendship
	if self._teleporterType == "Party" and self._isFriendsOnly and self._partyLeader then
		if self._partyLeader ~= player then
			local isFriend = false
			local success, result = pcall(function()
				return self._partyLeader:IsFriendsWith(player.UserId)
			end)
			
			if success then
				isFriend = result
			else
				warn(`[Teleporter] Failed to check friendship between {self._partyLeader.Name} and {player.Name}: {result}`)
			end
			
			if not isFriend then
				-- Player is not a friend of the party leader, reject them
				return
			end
		end
	end

	-- Check they have a character and are alive
	local char = player.Character
	local human = char and char:FindFirstChild("Humanoid") :: Humanoid
	if not (human and human.Health > 0) then
		return
	end

	-- For Party teleporters, first player locks it and gets reservation GUI
	-- Only do this if no party has been created yet (no party size set)
	if self._teleporterType == "Party" and #self._queue == 0 and not self._partySize then
		self._isLocked = true
		self._partyLeader = player
		self:_addPlayerToQueue(player)
		self:_createReservePartyGui(player)
		self:_startPartyReservationTimeout(player)
		return
	end

	-- Check capacity
	local maxCapacity = if self._teleporterType == "Party" and self._partySize then self._partySize else self._opts.maxPlayers
	if #self._queue >= (maxCapacity or 16) then
		return
	end

	self:_addPlayerToQueue(player)
end

--[[
	_addPlayerToQueue
	Adds a player to the teleporter queue

	@param player: Player, The player to add
]]
function Teleporter:_addPlayerToQueue(player: Player)
	table.insert(self._queue, player)

	-- Register player in the global registry
	_playerToTeleporter[player] = self

	-- Teleport player to the spawn location
	local char = player.Character
	if char then
		char:PivotTo(self._spawnCFrame)
	end

	-- Only create leave queue GUI if:
	-- - This is a public teleporter, OR
	-- - This is a party teleporter and party size is already set (not the initial player)
	local isPartyLeader = self._teleporterType == "Party" and self._partyLeader == player
	if not isPartyLeader or self._partySize then
		self:_createLeaveQueueGui(player)
	end

	-- Listen for character death
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			table.insert(self._conns, humanoid.Died:Connect(function()
				self:_onCharacterDied(player)
			end))
		end
	end

	-- Update GUI
	local maxCapacity = if self._teleporterType == "Party" and self._partySize then self._partySize else self._opts.maxPlayers
	local friendsOnlyText = if self._teleporterType == "Party" and self._isFriendsOnly then " (Friends Only)" else ""
	
	-- Check if we're below minimum players
	local minPlayers = self._opts.minPlayers or 1
	if #self._queue < minPlayers then
		-- Show waiting message
		local playersNeeded = minPlayers - #self._queue
		self:UpdateText(`Waiting for {playersNeeded} more player{playersNeeded == 1 and "" or "s"}...`, nil)
	else
		self:UpdateText(`Players: {#self._queue}/{maxCapacity}{friendsOnlyText}`, nil)
	end

	-- For party teleporters, only start countdown if party size is confirmed
	-- For public teleporters, start countdown when min players is met
	local shouldStartCountdown = false
	if self._teleporterType == "Party" then
		-- Party teleporter: only start countdown if party size is set and min players met
		shouldStartCountdown = self._partySize ~= nil and #self._queue >= (self._opts.minPlayers or 1)
	else
		-- Public teleporter: start countdown when min players met
		shouldStartCountdown = #self._queue >= (self._opts.minPlayers or 1)
	end

	if shouldStartCountdown and not self._countdownThread then
		self:_startCountdown()
	end

	-- Instant teleport if full (only if party size is confirmed for party teleporters)
	if self._opts.instantTeleportOnFull and #self._queue >= (maxCapacity or 16) then
		if self._teleporterType ~= "Party" or self._partySize then
			self:_cancelCountdown()
			self:_teleportPlayers()
		end
	end
end

--[[
	_removePlayerFromQueue
	Removes a player from the teleporter queue

	@param player: Player, The player to remove
	@param removeGui: boolean?, Whether to remove the leave queue GUI (default: true)
	@param teleportAway: boolean?, Whether to teleport the player away (default: true)
]]
function Teleporter:_removePlayerFromQueue(player: Player, removeGui: boolean?, teleportAway: boolean?, teleportDestination: CFrame?)
	print(player, removeGui, teleportAway, teleportDestination)
	local shouldRemoveGui = if removeGui ~= nil then removeGui else true
	local shouldTeleportAway = if teleportAway ~= nil then teleportAway else true

	for i, plr in self._queue do
		if plr == player then
			table.remove(self._queue, i)
			break
		end
	end

	-- Unregister player from the global registry
	_playerToTeleporter[player] = nil

	-- Remove leave queue GUI
	if shouldRemoveGui then
		self:_removeLeaveQueueGui(player)
	end

	-- Remove reserve party GUI if applicable
	self:_removeReservePartyGui(player)

	-- Teleport player away from the teleporter if requested
	if shouldTeleportAway then
		local char = player.Character
		if char then
			if teleportDestination then
				print("Teleporting to custom destination")
				char:PivotTo(teleportDestination)
			else
				print("Teleporting away from teleporter")
				local triggerSize = self._trigger.Size
				local triggerCFrame = self._trigger.CFrame
				local distance = triggerSize.Z -- Use Z component as it's the front-facing dimension
				local offset = triggerCFrame.LookVector * distance
				local targetCFrame = self._spawnCFrame + offset
				char:PivotTo(targetCFrame)
			end
		end
	end

	-- If this was the party leader, cancel reservation
	if self._partyLeader == player then
		self:_cancelPartyReservationTimeout()
		self._partyLeader = nil
		self._isLocked = false
	end

	-- Update GUI
	if #self._queue > 0 then
		local maxCapacity = if self._teleporterType == "Party" and self._partySize then self._partySize else self._opts.maxPlayers
		local friendsOnlyText = if self._teleporterType == "Party" and self._isFriendsOnly then " (Friends Only)" else ""
		
		-- Check if we're below minimum players
		local minPlayers = self._opts.minPlayers or 1
		if #self._queue < minPlayers then
			-- Cancel countdown if it's running
			self:_cancelCountdown()
			
			-- Show waiting message
			local playersNeeded = minPlayers - #self._queue
			self:UpdateText(`Waiting for {playersNeeded} more player{playersNeeded == 1 and "" or "s"}...`, nil)
		else
			self:UpdateText(`Players: {#self._queue}/{maxCapacity}{friendsOnlyText}`, nil)
		end
	else
		-- Cancel countdown if no players remain
		self:_cancelCountdown()
		self:UpdateText("Waiting for players...", nil)

		-- Reset party state if Party teleporter
		if self._teleporterType == "Party" then
			self._partySize = nil
			self._isLocked = false
			self._partyLeader = nil
			self._isFriendsOnly = false
		end
	end
end

--[[
	_startCountdown
	Starts the teleport countdown
]]
function Teleporter:_startCountdown()
	if self._countdownThread then
		return
	end

	self._countdownThread = task.spawn(function()
		local timeRemaining = self._opts.countdown or 30

		while timeRemaining > 0 do
			-- Check if we're still above minimum players
			local minPlayers = self._opts.minPlayers or 1
			if #self._queue < minPlayers then
				-- Drop below minimum, cancel countdown
				self._countdownThread = nil
				
				local playersNeeded = minPlayers - #self._queue
				self:UpdateText(`Waiting for {playersNeeded} more player{playersNeeded == 1 and "" or "s"}...`, nil)
				return
			end
			
			-- For party teleporters, also check if party size is still set
			if self._teleporterType == "Party" and not self._partySize then
				-- Party was cancelled, stop countdown
				self._countdownThread = nil
				self:UpdateText("Waiting for players...", nil)
				return
			end
			
			local maxCapacity = if self._teleporterType == "Party" and self._partySize then self._partySize else self._opts.maxPlayers
			local friendsOnlyText = if self._teleporterType == "Party" and self._isFriendsOnly then " (Friends Only)" else ""
			self:UpdateText(`Players: {#self._queue}/{maxCapacity}{friendsOnlyText}`, timeRemaining)
			task.wait(1)
			timeRemaining -= 1
		end

		self:_teleportPlayers()
	end)
end

--[[
	_cancelCountdown
	Cancels the current countdown
]]
function Teleporter:_cancelCountdown()
	if self._countdownThread then
		local ok, err = pcall(task.cancel, self._countdownThread)
		if not ok then
			warn(`[Teleporter] Failed to cancel countdown thread: {err}`)
		end
		self._countdownThread = nil
	end
end

--[[
	_teleportPlayers
	Teleports all players in the queue to a reserved server
]]
function Teleporter:_teleportPlayers()
	if #self._queue == 0 then
		return
	end

	self:UpdateText("Teleporting...", nil)

	-- Start cooldown immediately when teleport begins
	self:_startCooldown()

	local placeId = self._opts.teleportPlaceId or 0
	if placeId == 0 then
		warn("[Teleporter] Invalid teleportPlaceId, cannot teleport players")
		self:_cancelCountdown()
		self:UpdateText("Teleport failed!", nil)
		
		-- Manually remove all players from queue
		local playersToRemove = table.clone(self._queue)
		for _, player in playersToRemove do
			self:_removePlayerFromQueue(player, nil, true, HIDDEN_TELEPORT_CFRAME)
		end
		
		task.wait(3)

		-- Check that there are no players in the queue before showing this message
		if #self._queue == 0 then
			self:UpdateText("Waiting for players...", nil)
		end
		return
	end

	local playersToTeleport = table.clone(self._queue)

	-- Remove leave queue GUIs before teleporting
	for _, player in playersToTeleport do
		self:_removeLeaveQueueGui(player)
	end

	-- Reserve a private server for this group of players
	local reserveSuccess, reserveResult = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)

	if not reserveSuccess then
		warn(`[Teleporter] Failed to reserve server: {reserveResult}`)
		self:UpdateText("Teleport failed!", nil)
		task.wait(3)

		-- Manually remove all players from queue
		local playersToRemove = table.clone(self._queue)
		for _, player in playersToRemove do
			-- Remove from registry
			_playerToTeleporter[player] = nil
			-- Remove GUI if still present
			self:_removeLeaveQueueGui(player)
			-- Teleport player away
			local char = player.Character
			if char then
				local triggerSize = self._trigger.Size
				local triggerCFrame = self._trigger.CFrame
				local distance = triggerSize.Z * 2
				local offset = triggerCFrame.LookVector * distance
				local targetCFrame = self._spawnCFrame + offset
				char:PivotTo(targetCFrame)
			end
		end

		-- Clear queue and reset state
		table.clear(self._queue)
		self._countdownThread = nil

		-- Reset party state if Party teleporter
		if self._teleporterType == "Party" then
			self._partySize = nil
			self._isLocked = false
			self._partyLeader = nil
			self._isFriendsOnly = false
		end

		self:UpdateText("Waiting for players...", nil)
		return
	end

	local reservedServerAccessCode, privateServerId = reserveResult, nil
	if type(reserveResult) == "table" then
		-- ReserveServer returns (accessCode, privateServerId) as a tuple
		reservedServerAccessCode = reserveResult[1] or reserveResult
		privateServerId = reserveResult[2]
	end

	-- Create TeleportOptions with the reserved server access code
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions.ReservedServerAccessCode = reservedServerAccessCode

	-- Attempt teleport to the reserved server
	local success, result = pcall(function()
		return TeleportService:TeleportAsync(placeId, playersToTeleport, teleportOptions)
	end)

	if not success then
		warn(`[Teleporter] Teleport failed: {result}`)
		self:UpdateText("Teleport failed!", nil)
		task.wait(3)
		
		-- Manually remove all players from queue (teleport them away since it failed)
		local playersToRemove = table.clone(self._queue)
		for _, player in playersToRemove do
			-- Remove from registry
			_playerToTeleporter[player] = nil
			-- Remove GUI if still present
			self:_removeLeaveQueueGui(player)
			-- Teleport player away
			local char = player.Character
			if char then
				local triggerSize = self._trigger.Size
				local triggerCFrame = self._trigger.CFrame
				local distance = triggerSize.Z * 2
				local offset = triggerCFrame.LookVector * distance
				local targetCFrame = self._spawnCFrame + offset
				char:PivotTo(targetCFrame)
			end
		end
		
		-- Clear queue and reset state
		table.clear(self._queue)
		self._countdownThread = nil

		-- Reset party state if Party teleporter
		if self._teleporterType == "Party" then
			self._partySize = nil
			self._isLocked = false
			self._partyLeader = nil
			self._isFriendsOnly = false
		end

		self:UpdateText("Waiting for players...", nil)
	else
		-- Log successful teleport with private server ID
		if privateServerId then
			print(`[Teleporter] Successfully teleported {#playersToTeleport} players to reserved server (ID: {privateServerId})`)
		end
		
		-- Create fade-to-black screen for successful teleports
		for _, player in playersToTeleport do
			self:_createTeleportFadeGui(player)
		end
		
		-- Clean up queue without physically moving players (they're teleporting away)
		for _, player in playersToTeleport do
			-- Remove from registry
			_playerToTeleporter[player] = nil
			-- Remove GUI if still present
			self:_removeLeaveQueueGui(player)
			-- Don't teleport - they're already leaving via TeleportAsync
		end
		
		-- Clear queue and reset state
		table.clear(self._queue)
		self._countdownThread = nil

		-- Reset party state if Party teleporter
		if self._teleporterType == "Party" then
			self._partySize = nil
			self._isLocked = false
			self._partyLeader = nil
			self._isFriendsOnly = false
		end

		self:UpdateText("Waiting for players...", nil)
	end
end

--[[
	_onPlayerRemoving
	Handles player leaving the game

	@param player: Player, The player that is leaving
]]
function Teleporter:_onPlayerRemoving(player: Player)
	if isPlayerInQueue(self._queue, player) then
		-- Don't teleport away when player is leaving the game
		self:_removePlayerFromQueue(player, true, false)
	end
end

--[[
	_onCharacterDied
	Handles player character death

	@param player: Player, The player whose character died
]]
function Teleporter:_onCharacterDied(player: Player)
	if isPlayerInQueue(self._queue, player) then
		self:_removePlayerFromQueue(player)
	end
end

--[[
	_onPlayerLeaveQueue
	Handles player manually leaving the queue via the GUI button

	@param player: Player, The player leaving the queue
]]
function Teleporter:_onPlayerLeaveQueue(player: Player)
	if not isPlayerInQueue(self._queue, player) then
		return
	end

	-- Remove from queue (with teleport)
	self:_removePlayerFromQueue(player, true, true)
end

--[[
	_createLeaveQueueGui
	Creates a ScreenGui with a leave queue button for the player

	@param player: Player, The player to create the GUI for
]]
function Teleporter:_createLeaveQueueGui(player: Player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	-- Remove any existing leave queue GUI
	local existing = playerGui:FindFirstChild("LeaveTeleportQueueGui")
	if existing then
		existing:Destroy()
	end

	-- Create new ScreenGui
	local screenGui = LeaveTeleportQueueGui:Clone()
	screenGui.Name = "LeaveTeleportQueueGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
end

--[[
	_removeLeaveQueueGui
	Removes the leave queue GUI from the player

	@param player: Player, The player to remove the GUI from
]]
function Teleporter:_removeLeaveQueueGui(player: Player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local gui = playerGui:FindFirstChild("LeaveTeleportQueueGui")
	if gui then
		gui:Destroy()
	end
end

--[[
	_createReservePartyGui
	Creates a ScreenGui with party reservation options for the player

	@param player: Player, The player to create the GUI for
]]
function Teleporter:_createReservePartyGui(player: Player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	-- Remove any existing reserve party GUI
	local existing = playerGui:FindFirstChild("ReserveTeleportPartyGui")
	if existing then
		existing:Destroy()
	end

	-- Create new ScreenGui
	local screenGui = ReserveTeleportPartyGui:Clone()
	screenGui.Name = "ReserveTeleportPartyGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Set attributes for min and max party size
	screenGui:SetAttribute("MinPartySize", self._opts.minPlayers or 1)
	screenGui:SetAttribute("MaxPartySize", self._opts.maxPlayers or 8)
	print(`[Teleporter] Created ReserveTeleportPartyGui for {player.Name} with MinPartySize={self._opts.minPlayers or 1} and MaxPartySize={self._opts.maxPlayers or 8}`)
	screenGui.Parent = playerGui
end

--[[
	_removeReservePartyGui
	Removes the reserve party GUI from the player

	@param player: Player, The player to remove the GUI from
]]
function Teleporter:_removeReservePartyGui(player: Player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local gui = playerGui:FindFirstChild("ReserveTeleportPartyGui")
	if gui then
		gui:Destroy()
	end
end

--[[
	_createTeleportFadeGui
	Creates a fade-to-black screen GUI for the player during teleportation

	@param player: Player, The player to create the GUI for
]]
function Teleporter:_createTeleportFadeGui(player: Player)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	-- Create ScreenGui with high display order
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TeleportFadeGui"
	screenGui.DisplayOrder = 10000 -- Very high to ensure it's on top
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	-- Create black frame that covers the entire screen
	local fadeFrame = Instance.new("Frame")
	fadeFrame.Name = "FadeFrame"
	fadeFrame.Size = UDim2.new(1, 0, 1, 0)
	fadeFrame.Position = UDim2.new(0, 0, 0, 0)
	fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	fadeFrame.BackgroundTransparency = 1 -- Start transparent
	fadeFrame.BorderSizePixel = 0
	fadeFrame.Parent = screenGui
	
	screenGui.Parent = playerGui
	
	-- Animate fade to black
	task.spawn(function()
		local fadeDuration = 1.0 -- 1 second fade
		local steps = 20
		local stepDuration = fadeDuration / steps
		
		for i = 1, steps do
			if fadeFrame and fadeFrame.Parent then
				fadeFrame.BackgroundTransparency = 1 - (i / steps)
				task.wait(stepDuration)
			else
				break
			end
		end
	end)
end

--[[
	_startPartyReservationTimeout
	Starts a 10-second timeout for party reservation

	@param player: Player, The player who needs to create the party
]]
function Teleporter:_startPartyReservationTimeout(player: Player)
	if self._partyReservationThread then
		return
	end

	self._partyReservationThread = task.spawn(function()
		local timeRemaining = 10
		while timeRemaining > 0 do
			self:UpdateText(`{player.Name} is creating a party. ({timeRemaining})`, nil)
			task.wait(1)
			timeRemaining -= 1

			if self._partyLeader ~= player then
				-- Party leader changed or reservation canceled
				break
			end
		end

		-- Check if player is still in queue and is the party leader
		if self._partyLeader == player and isPlayerInQueue(self._queue, player) then
			-- Remove reserve party GUI
			self:_removeReservePartyGui(player)

			-- Remove player from queue
			self:_removePlayerFromQueue(player)

			-- Show timeout message
			if _deps and _deps.SharedPackages.Messages then
				local success = pcall(function()
					_deps.SharedPackages.Messages:ShowMessage(player, "Create party timed out", "Error")
				end)
				if not success then
					warn("[Teleporter] Failed to show timeout message to player")
				end
			end

			-- Reset party state
			self._partyLeader = nil
			self._isLocked = false
			self._partyReservationThread = nil
		end
	end)
end

--[[
	_cancelPartyReservationTimeout
	Cancels the party reservation timeout
]]
function Teleporter:_cancelPartyReservationTimeout()
	if self._partyReservationThread then
		local ok, err = pcall(task.cancel, self._partyReservationThread)
		if not ok then
			warn(`[Teleporter] Failed to cancel party reservation thread: {err}`)
		end
		self._partyReservationThread = nil
	end
end

--[[
	_onCreateTeleportParty
	Handles creating a teleport party

	@param player: Player, The player creating the party
	@param partySize: number, The size of the party
]]
function Teleporter:_onCreateTeleportParty(player: Player, partySize: number, isFriendsOnly: boolean)
	-- Verify this is a party teleporter
	if self._teleporterType ~= "Party" then
		return
	end

	-- Verify player is the party leader
	if self._partyLeader ~= player then
		return
	end

	-- Verify player is in queue
	if not isPlayerInQueue(self._queue, player) then
		return
	end

	-- Validate party size
	local maxCapacity = self._opts.maxPlayers or 16
	if partySize < 1 or partySize > maxCapacity then
		warn(`[Teleporter] Invalid party size: {partySize}`)
		return
	end

	-- Cancel the reservation timeout
	self:_cancelPartyReservationTimeout()

	-- Remove reserve party GUI
	self:_removeReservePartyGui(player)

	-- Now give the party leader the leave queue GUI
	self:_createLeaveQueueGui(player)

	-- Set party size and unlock teleporter
	self._partySize = partySize
	self._isFriendsOnly = isFriendsOnly
	-- Don't modify self._opts.minPlayers - keep the original minimum requirement
	self._isLocked = false

	-- Update GUI
	local friendsOnlyText = if self._isFriendsOnly then " (Friends Only)" else ""
	
	-- Check if we're below minimum players
	local minPlayers = self._opts.minPlayers or 1
	if #self._queue < minPlayers then
		local playersNeeded = minPlayers - #self._queue
		self:UpdateText(`Waiting for {playersNeeded} more player{playersNeeded == 1 and "" or "s"}...`, nil)
	else
		self:UpdateText(`Players: {#self._queue}/{partySize}{friendsOnlyText}`, nil)
	end

	-- Start countdown only if we have enough players
	if #self._queue >= minPlayers and not self._countdownThread then
		self:_startCountdown()
	end
end

--[[
	_onCancelTeleportPartyReservation
	Handles canceling a teleport party reservation

	@param player: Player, The player canceling the reservation
]]
function Teleporter:_onCancelTeleportPartyReservation(player: Player)
	-- Verify this is a party teleporter
	if self._teleporterType ~= "Party" then
		return
	end

	-- Verify player is the party leader
	if self._partyLeader ~= player then
		return
	end

	-- Verify player is in queue
	if not isPlayerInQueue(self._queue, player) then
		return
	end

	-- Cancel the reservation timeout
	self:_cancelPartyReservationTimeout()

	-- Remove reserve party GUI
	self:_removeReservePartyGui(player)

	-- Remove player from queue
	self:_removePlayerFromQueue(player)

	-- Reset party state
	self._partyLeader = nil
	self._isLocked = false
end

--[[
	_startCooldown
	Starts a 3-second cooldown after a teleport attempt
]]
function Teleporter:_startCooldown()
	if self._cooldownThread then
		return
	end

	self._isOnCooldown = true
	self._cooldownThread = task.spawn(function()
		task.wait(3)
		self._isOnCooldown = false
		self._cooldownThread = nil
	end)
end

--[[
	_cancelCooldown
	Cancels the current cooldown
]]
function Teleporter:_cancelCooldown()
	if self._cooldownThread then
		local ok, err = pcall(task.cancel, self._cooldownThread)
		if not ok then
			warn(`[Teleporter] Failed to cancel cooldown thread: {err}`)
		end
		self._cooldownThread = nil
	end
	self._isOnCooldown = false
end

return Teleporter :: TeleporterAPI
