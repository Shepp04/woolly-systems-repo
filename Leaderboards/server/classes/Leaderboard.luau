--!strict
-- Leaderboard (Server Class)

-- // Roblox Services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

export type Opts = {
	datastoreName: string,
	model: Model,
	maxEntries: number,
	minDisplayValue: number,
	userIdBlacklist: { number },
	gui: (SurfaceGui | BillboardGui)?,
	statPath: string?, -- Path to stat in profile (e.g., "Data.Stats.Miles")
}

export type LeaderboardEntry = {
	userId: number,
	name: string,
	value: number,
}

export type LeaderboardAPI = {
	_opts: Opts,
	_conns: { RBXScriptConnection },
	_orderedDataStore: OrderedDataStore?,
	_gui: SurfaceGui | BillboardGui,
	_itemsContainer: ScrollingFrame,
	_itemTemplate: Frame,
	_topFrame: Frame?,
	_currentItems: { Frame },

	Init: (self: LeaderboardAPI) -> (),
	Refresh: (self: LeaderboardAPI) -> (),
	Destroy: (self: LeaderboardAPI) -> (),
	GetDatastoreName: (self: LeaderboardAPI) -> string,
	GetStatPath: (self: LeaderboardAPI) -> string?,
	SavePlayerStat: (self: LeaderboardAPI, userId: number, value: number) -> boolean,
	
	-- Private methods
	_createDefaultGui: (self: LeaderboardAPI) -> (SurfaceGui | BillboardGui),
	_setupGui: (self: LeaderboardAPI) -> (),
	_fetchLeaderboardData: (self: LeaderboardAPI) -> { LeaderboardEntry },
	_updateDisplay: (self: LeaderboardAPI, entries: { LeaderboardEntry }) -> (),
	_createLeaderboardItem: (self: LeaderboardAPI, entry: LeaderboardEntry, index: number) -> Frame,
	_clearItems: (self: LeaderboardAPI) -> (),
}

local Leaderboard = {}
Leaderboard.__index = Leaderboard

-- Private captured deps
local _deps: Deps?

function Leaderboard.new(deps: Deps, opts: Opts): LeaderboardAPI
	_deps = deps

	local self = setmetatable({} :: any, Leaderboard) :: LeaderboardAPI
	self._opts = opts
	self._conns = {}
	self._orderedDataStore = nil
	self._currentItems = {}

	return self
end

function Leaderboard:Init()
	-- Get or create the OrderedDataStore
	local success, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(self._opts.datastoreName)
	end)
	
	if success then
		self._orderedDataStore = result
	else
		warn(`[Leaderboard] Failed to get OrderedDataStore "{self._opts.datastoreName}": {result}`)
	end
	
	-- Setup GUI (create if needed)
	self:_setupGui()
	
	-- Initial refresh
	self:Refresh()
end

function Leaderboard:_setupGui()
	-- Use provided GUI or create default
	if self._opts.gui then
		self._gui = self._opts.gui
	else
		self._gui = self:_createDefaultGui()
	end
	
	-- Find the items container
	local container = self._gui:FindFirstChild("Container") :: Frame?
	if not container then
		warn("[Leaderboard] GUI missing Container Frame")
		return
	end
	
	-- Find Top frame (optional)
	self._topFrame = container:FindFirstChild("Top") :: Frame?
	
	-- Find Items scrolling frame
	local items = container:FindFirstChild("Items") :: ScrollingFrame?
	if not items then
		warn("[Leaderboard] GUI missing Items ScrollingFrame")
		return
	end
	self._itemsContainer = items
	
	-- Find and clone the item template
	local template = items:FindFirstChild("ItemTemplate") :: Frame?
	if not template then
		warn("[Leaderboard] GUI missing ItemTemplate Frame")
		return
	end
	
	self._itemTemplate = template:Clone()
	template.Visible = false -- Hide the original template
	
	-- Attach GUI to model's Screen part
	local screen = self._opts.model:FindFirstChild("Screen")
	if screen and screen:IsA("BasePart") then
		if self._gui:IsA("SurfaceGui") then
			self._gui.Adornee = screen
		elseif self._gui:IsA("BillboardGui") then
			self._gui.Adornee = screen
		end
		self._gui.Parent = self._opts.model
	else
		warn("[Leaderboard] Model missing 'Screen' part for GUI attachment")
	end
end

function Leaderboard:_createDefaultGui(): SurfaceGui | BillboardGui
	-- Create a default SurfaceGui with the expected structure
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "LeaderboardGui"
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	
	-- Container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	container.BackgroundTransparency = 0.1
	container.Parent = surfaceGui
	
	-- Top frame (optional header showing current player)
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.Size = UDim2.new(1, 0, 0, 60)
	top.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	top.BorderSizePixel = 0
	top.Parent = container
	
	local topIndex = Instance.new("TextLabel")
	topIndex.Name = "PlayerIndex"
	topIndex.Size = UDim2.new(0.15, 0, 1, 0)
	topIndex.BackgroundTransparency = 1
	topIndex.Font = Enum.Font.GothamBold
	topIndex.TextColor3 = Color3.new(1, 1, 1)
	topIndex.TextScaled = true
	topIndex.Text = "Rank"
	topIndex.Parent = top
	
	local topName = Instance.new("TextLabel")
	topName.Name = "PlayerName"
	topName.Size = UDim2.new(0.5, 0, 1, 0)
	topName.Position = UDim2.fromScale(0.15, 0)
	topName.BackgroundTransparency = 1
	topName.Font = Enum.Font.Gotham
	topName.TextColor3 = Color3.new(1, 1, 1)
	topName.TextScaled = true
	topName.Text = "Player"
	topName.Parent = top
	
	-- Get the name of the stat for the value display
	local parts = string.split(self._opts.statPath or "", ".")
	local statName = parts[#parts] or ""

	local topValue = Instance.new("TextLabel")
	topValue.Name = "PlayerValue"
	topValue.Size = UDim2.new(0.35, 0, 1, 0)
	topValue.Position = UDim2.fromScale(0.65, 0)
	topValue.BackgroundTransparency = 1
	topValue.Font = Enum.Font.GothamBold
	topValue.TextColor3 = Color3.new(1, 1, 1)
	topValue.TextScaled = true
	topValue.Text = statName
	topValue.Parent = top
	
	-- Items ScrollingFrame
	local items = Instance.new("ScrollingFrame")
	items.Name = "Items"
	items.Size = UDim2.new(1, 0, 1, -60)
	items.Position = UDim2.new(0, 0, 0, 60)
	items.BackgroundTransparency = 1
	items.BorderSizePixel = 0
	items.ScrollBarThickness = 10
	items.Parent = container
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = items
	
	-- ItemTemplate
	local itemTemplate = Instance.new("Frame")
	itemTemplate.Name = "ItemTemplate"
	itemTemplate.Size = UDim2.new(1, -10, 0, 50)
	itemTemplate.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	itemTemplate.BorderSizePixel = 0
	itemTemplate.Visible = false
	itemTemplate.Parent = items
	
	local itemIndex = Instance.new("TextLabel")
	itemIndex.Name = "PlayerIndex"
	itemIndex.Size = UDim2.new(0.15, 0, 1, 0)
	itemIndex.BackgroundTransparency = 1
	itemIndex.Font = Enum.Font.GothamBold
	itemIndex.TextColor3 = Color3.new(1, 1, 1)
	itemIndex.TextScaled = true
	itemIndex.Text = "1"
	itemIndex.Parent = itemTemplate
	
	local itemName = Instance.new("TextLabel")
	itemName.Name = "PlayerName"
	itemName.Size = UDim2.new(0.5, 0, 1, 0)
	itemName.Position = UDim2.fromScale(0.15, 0)
	itemName.BackgroundTransparency = 1
	itemName.Font = Enum.Font.Gotham
	itemName.TextColor3 = Color3.new(1, 1, 1)
	itemName.TextScaled = true
	itemName.Text = "Player Name"
	itemName.TextXAlignment = Enum.TextXAlignment.Left
	itemName.Parent = itemTemplate
	
	local itemValue = Instance.new("TextLabel")
	itemValue.Name = "PlayerValue"
	itemValue.Size = UDim2.new(0.35, 0, 1, 0)
	itemValue.Position = UDim2.fromScale(0.65, 0)
	itemValue.BackgroundTransparency = 1
	itemValue.Font = Enum.Font.GothamBold
	itemValue.TextColor3 = Color3.new(1, 1, 1)
	itemValue.TextScaled = true
	itemValue.Text = "100"
	itemValue.TextXAlignment = Enum.TextXAlignment.Right
	itemValue.Parent = itemTemplate
	
	return surfaceGui
end

function Leaderboard:Refresh()
	if not self._orderedDataStore then
		warn("[Leaderboard] Cannot refresh: OrderedDataStore not available")
		return
	end
	
	-- Fetch leaderboard data
	local entries = self:_fetchLeaderboardData()

	-- Update display
	self:_updateDisplay(entries)
end

function Leaderboard:_fetchLeaderboardData(): { LeaderboardEntry }
	local entries: { LeaderboardEntry } = {}
	
	if not self._orderedDataStore then
		return entries
	end
	
	local success, result = pcall(function()
		return self._orderedDataStore:GetSortedAsync(
			false, -- descending order (highest first)
			self._opts.maxEntries,
			self._opts.minDisplayValue
		)
	end)
	
	if not success then
		warn(`[Leaderboard] Failed to fetch leaderboard data: {result}`)
		return entries
	end
	
	local pages = result
	local currentPage = pages:GetCurrentPage()
	
	for _, entry in ipairs(currentPage) do
		local userId = tonumber(entry.key)
		local value = entry.value
		
		if userId then
			-- Check blacklist
			local isBlacklisted = false
			for _, blacklistedId in ipairs(self._opts.userIdBlacklist) do
				if userId == blacklistedId then
					isBlacklisted = true
					break
				end
			end
			
			if not isBlacklisted then
				-- Get player name (from Players service if online, otherwise from UserId)
				local name = "Player"
				local player = Players:GetPlayerByUserId(userId)
				
				if player then
					name = player.Name
				else
					-- Try to get name from UserService
					local nameSuccess, userName = pcall(function()
						return Players:GetNameFromUserIdAsync(userId)
					end)
					if nameSuccess then
						name = userName
					end
				end
				
				table.insert(entries, {
					userId = userId,
					name = name,
					value = value,
				})
			end
		end
	end
	
	return entries
end

function Leaderboard:_updateDisplay(entries: { LeaderboardEntry })
	-- Clear existing items
	self:_clearItems()
	
	-- Create new items
	for index, entry in ipairs(entries) do
		if index > self._opts.maxEntries then
			break
		end
		
		local item = self:_createLeaderboardItem(entry, index)
		item.Parent = self._itemsContainer
		table.insert(self._currentItems, item)
	end
	
	-- Update canvas size
	local listLayout = self._itemsContainer:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		self._itemsContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end
end

function Leaderboard:_createLeaderboardItem(entry: LeaderboardEntry, index: number): Frame
	local item = self._itemTemplate:Clone()
	item.Name = `Entry_{index}`
	item.Visible = true
	item.LayoutOrder = index
	
	-- Update index
	local indexLabel = item:FindFirstChild("PlayerIndex") :: TextLabel?
	if indexLabel then
		indexLabel.Text = `#{index}`
	end
	
	-- Update name
	local nameLabel = item:FindFirstChild("PlayerName") :: TextLabel?
	if nameLabel then
		nameLabel.Text = entry.name
	end
	
	-- Update value
	local valueLabel = item:FindFirstChild("PlayerValue") :: TextLabel?
	if valueLabel then
		valueLabel.Text = tostring(entry.value)
	end
	
	return item
end

function Leaderboard:_clearItems()
	for _, item in ipairs(self._currentItems) do
		item:Destroy()
	end
	table.clear(self._currentItems)
end

function Leaderboard:GetDatastoreName(): string
	return self._opts.datastoreName
end

function Leaderboard:GetStatPath(): string?
	return self._opts.statPath
end

function Leaderboard:SavePlayerStat(userId: number, value: number): boolean
	if not self._orderedDataStore then
		warn(`[Leaderboard] Cannot save stat for user {userId}: OrderedDataStore not available`)
		return false
	end
	
	-- Check if value meets minimum display value
	if value < self._opts.minDisplayValue then
		return true -- Successfully skipped (not an error)
	end
	
	local success, err = pcall(function()
		self._orderedDataStore:SetAsync(tostring(userId), value)
	end)
	
	if not success then
		warn(`[Leaderboard] Failed to save stat for user {userId} to "{self._opts.datastoreName}": {err}`)
		return false
	end
	
	return true
end

function Leaderboard:Destroy()
	-- Clear all items
	self:_clearItems()
	
	-- Destroy GUI
	if self._gui then
		self._gui:Destroy()
	end
	
	-- Disconnect connections
	for _, c in self._conns do
		pcall(function() c:Disconnect() end)
	end
	table.clear(self._conns)
	
	_deps = nil
end

return Leaderboard
