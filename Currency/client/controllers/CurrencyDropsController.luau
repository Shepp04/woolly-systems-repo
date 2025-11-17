--!strict
-- CurrencyDropsController (Controller) — client controller discovered by Controllers registry.

-- // Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- // Types (generated)
local ControllersTypes = require(ReplicatedStorage.Shared.Types.Controllers)

-- // Type aliases for deps inferred from real modules
type ControllerRegistry = ControllersTypes.Registry

type ReplicatedData = typeof(require(ReplicatedStorage.Shared.Packages.ReplicatedData))
type SharedPackages = typeof(require(ReplicatedStorage.Shared.Packages))
type GameData       = typeof(require(ReplicatedStorage.Shared.GameData))
type Monetisation   = typeof(require(ReplicatedStorage.Shared.Monetisation))
type Config         = typeof(require(ReplicatedStorage.Shared.Config))

-- // Custom types
type Collectable = {
	name: string,
	value: number,
	model: Model,
	soundId: number,
}

export type Deps = {
	ReplicatedData: ReplicatedData,
	SharedPackages: SharedPackages,
	GameData: GameData,
	Monetisation: Monetisation,
	Config: Config,
}

export type CurrencyDropsControllerAPI = {
	_inited: boolean,
	_started: boolean,
	_conns: { RBXScriptConnection },
	Priority: number?,
	Controllers: ControllerRegistry, -- optional backref to the registry, filled by bootstrapper

	Init: (self: CurrencyDropsControllerAPI, deps: Deps) -> (),
	Start: (self: CurrencyDropsControllerAPI) -> (),
	Destroy: (self: CurrencyDropsControllerAPI) -> (),
}

local CurrencyDropsController = {
	_inited = false,
	_started = false,
	_conns = {},
	Priority = 50, -- higher -> starts earlier
	Controllers = {} :: ControllerRegistry,
} :: CurrencyDropsControllerAPI

-- Private captured deps for intellisense-friendly access
local _deps: Deps?

-- // Utils
local Utils = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utils")
local CurrencyUtil = require(Utils:WaitForChild("Currency"))

-- ========= Public API ========== --

function CurrencyDropsController:DropCurrency(currencyId: string, amount: number)
	task.spawn(function()
		if not self._inited or not self._started then
			warn("[CurrencyDropsController] - Cannot call :DropCurrency() before Init() and Start()")
			return
		end

		-- // Divide the amount into different collectables if defined
		local currencyInfo = _deps.GameData.Get("Currency", currencyId)
		if not currencyInfo then
			warn("[CurrencyDropsController] - Cannot drop unknown currency:", currencyId)
			return
		end

		local currencyData = _deps.GameData.GetDataType("Currency")

		-- Create a billboard GUI to show the currency value earned
		local gui = self._templateValueGui:Clone() :: BillboardGui
		gui.Adornee = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		gui.Enabled = true
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		local canvas = gui:FindFirstChild("Canvas") :: CanvasGroup
		local currencyImage = canvas:FindFirstChild("CurrencyImage") :: ImageLabel
		local amountLabel = canvas:FindFirstChild("Amount") :: TextLabel

		if currencyImage and currencyInfo.icon then
			currencyImage.Image = currencyInfo.icon
		else
			currencyImage.Image = "rbxassetid://0" -- Fallback to a default image
		end

		-- // Start a heartbeat loop to attract currency to player
		local drops = {} :: { { model: Model, collectableInfo: Collectable } }
		local attractConnection: RBXScriptConnection?

		attractConnection = RunService.Heartbeat:Connect(function()
			for _, drop in ipairs(drops) do
				if drop.model and drop.model.Parent and drop.model:IsA("Model") then
					local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					if root then
						local targetPos = root.Position + Vector3.new(0, 2, 0)
						drop.model:PivotTo(CFrame.new(drop.model:GetPivot().Position:Lerp(targetPos, 0.1)))
						if (drop.model:GetPivot().Position - targetPos).Magnitude < 3 then
							-- Reached player, collect it
							drop.model:Destroy()

							-- Play a sound or effect here
							_deps.SharedPackages.Sounds:PlaySound(drop.collectableInfo.sound)
						end
					end
				end
			end
		end)

		local collectables = currencyInfo.collectables
		if collectables and #collectables > 0 then
			-- // Sort collectables by value descending
			table.sort(collectables, function(a, b) return a.value > b.value end)
			local remaining = amount
			for _, collectable in collectables do
				while remaining >= collectable.value do
					remaining -= collectable.value
					-- // Spawn the collectable in the world (TODO: implement actual spawn logic)
					print("Dropping collectable:", collectable.name, "Value:", collectable.value)

					local drop = collectable.model:Clone() :: Model
					drop.Parent = workspace
					drop:PivotTo(
						Players.LocalPlayer.Character and Players.LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(math.random(-5,5), 0, math.random(-5,5))
							or CFrame.new()
					)

					table.insert(drops, { model = drop, collectableInfo = collectable })
					Debris:AddItem(drop, 10) -- Auto-cleanup after 10 seconds

					-- Update the GUI to show the total amount dropped so far
					local text = CurrencyUtil.GetCurrencyText(currencyId, amount - remaining, true)
					amountLabel.Text = text
					task.wait(0.1) -- Simulate delay for dropping
				end
			end

			local text = currencyData.GetCurrencyText(currencyId, amount, true)
			amountLabel.Text = text
		end

		-- // Cleanup
		attractConnection:Disconnect()
		for _, drop in drops do
			if drop.model and drop.model.Parent then
				drop.model:Destroy()
			end
		end
		table.clear(drops)

		local guiOutTween = TweenService:Create(canvas, TweenInfo.new(1), { GroupTransparency = 1 })
		guiOutTween:Play()
		guiOutTween.Completed:Wait()
		gui:Destroy()
	end)
end

-- ========== Life Cycle ========== --

function CurrencyDropsController:Init(deps: Deps)
	if self._inited then return end
	self._inited = true
	self._conns = {}
	_deps = deps

	-- // Find UI template/elements
	local Assets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets")
	self._templateValueGui = Assets:WaitForChild("UI"):FindFirstChild("CurrencyValueGui") :: BillboardGui
	assert(self._templateValueGui and self._templateValueGui:IsA("BillboardGui"), "[CurrencyDropsController] - Could not find CurrencyValueGui template!")

	local canvas = self._templateValueGui:FindFirstChild("Canvas") :: CanvasGroup
	assert(canvas and canvas:IsA("CanvasGroup"), "[CurrencyDropsController] - CurrencyValueGui is missing a CanvasGroup named 'Canvas'!")

	local currencyImage = canvas:FindFirstChild("CurrencyImage") :: ImageLabel
	assert(currencyImage and currencyImage:IsA("ImageLabel"), "[CurrencyDropsController] - CurrencyValueGui is missing a CurrencyImage ImageLabel!")
	currencyImage.Image = "rbxassetid://0" -- Default to a blank image

	local amountLabel = canvas:FindFirstChild("Amount") :: TextLabel
	assert(amountLabel and amountLabel:IsA("TextLabel"), "[CurrencyDropsController] - CurrencyValueGui is missing an AmountLabel TextLabel!")
	amountLabel.Text = ""

	self._templateValueGui.Enabled = false
	self._templateValueGui.Adornee = nil

	-- // Get remotes
	self._dropCurrencyRemote = _deps.SharedPackages.Remotes:GetRemote("RemoteEvent", "DropCurrency") :: RemoteEvent
end

function CurrencyDropsController:Start()
	if not self._inited or self._started then return end
	self._started = true

	-- // Connect remotes
	self._conns.DropCurrency = self._dropCurrencyRemote.OnClientEvent:Connect(function(...)
		self:DropCurrency(...)
	end)
end

function CurrencyDropsController:Destroy()
	for _, conn in self._conns do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(self._conns)
	_deps = nil
	self._started = false
	self._inited = false
end

return CurrencyDropsController :: CurrencyDropsControllerAPI