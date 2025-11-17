--!strict
-- CurrencyDisplay (Component) — reusable client UI/gameplay piece (class-like).

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- //* Configuration *// --

-- Map currencyIds to UI paths
local LABEL_PATHS: {[string]: {string}} = {
	Cash = {"Coin", "Amount"},
	-- Add more currencies here as needed
}

local Assets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets")
local CURRENCY_EARNED_PROMPT = Assets:WaitForChild("UI"):WaitForChild("CurrencyEarnedPrompt")

-- // Helpers
local function getPlayerGui(): PlayerGui
	return (Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui)
end

local function getNested(parent: Instance, path: {string}): Instance
	local cur = parent
	for _, name in ipairs(path) do
		cur = cur:WaitForChild(name)
	end
	return cur
end

-- // Type Defs
export type Deps = {
	GameData: any,
}

export type CurrencyDisplay = {
	_inited: boolean,
	_root: ScreenGui,
	_labels: {[string]: TextLabel}, -- currencyId -> label
	_deps: Deps?,
	
	Init: (self: CurrencyDisplay, deps: Deps) -> (),
	SetCurrency: (self: CurrencyDisplay, currencyId: string, amount: number) -> (),
	ShowCurrencyEarnedPrompt: (self: CurrencyDisplay, currencyId: string, amount: number) -> (),
	SetMany: (self: CurrencyDisplay, changes: {[string]: number}) -> (),
	Show: (self: CurrencyDisplay, visible: boolean) -> (),
	Destroy: (self: CurrencyDisplay) -> (),
}

local CurrencyDisplay = {}
CurrencyDisplay.__index = CurrencyDisplay

local function buildLabels(root: ScreenGui): {[string]: TextLabel}
	local labels: {[string]: TextLabel} = {}
	for currencyId, path in pairs(LABEL_PATHS) do
		local inst = getNested(root, path)
		labels[currencyId] = inst :: TextLabel
	end
	return labels
end

-- ========== Constructor ========== --

function CurrencyDisplay.new()
	local root = (getPlayerGui():WaitForChild("Main") :: ScreenGui)
	local self = setmetatable({
		_inited = false,
		_root = root,
		_labels = buildLabels(root),
		_deps = nil,
	}, CurrencyDisplay)
	return self
end

-- ========== Life Cycle ========== --

function CurrencyDisplay:Init(deps: Deps)
	if self._inited then return end
	self._inited = true
	self._deps = deps
end

function CurrencyDisplay:ShowCurrencyEarnedPrompt(currencyId: string, amount: number)
	task.spawn(function()
		-- Check this is a valid currency
		local currencyInfo = self._deps and self._deps.GameData.Get("Currency", currencyId)
		if not (currencyInfo) then return end
		
		local prompt = CURRENCY_EARNED_PROMPT:Clone()
		
		local amountLabel = prompt:FindFirstChild("Amount") :: TextLabel
		assert(amountLabel, "Currency Earned Prompts need a TextLabel called 'Amount'")
		
		amountLabel.Text = tostring(amount)
		
		local icon = prompt:FindFirstChild("Icon") or prompt:FindFirstChildOfClass("ImageLabel") :: ImageLabel
		if (icon) then
			icon.Image = currencyInfo.icon or ""
		end
		
		prompt.AnchorPoint = Vector2.new(0.5, 0.5)
		
		local x = math.random(350, 650) / 1000
		local y = math.random(350, 650) / 1000
		
		-- Initialise
		prompt.Position = UDim2.fromScale(x, y)
		prompt.Visible = false
		prompt.Parent = self._root
		
		-- Create tweens
		local inTween = TweenService:Create(
			prompt, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{
				Size = prompt:IsA("Frame") and UDim2.fromOffset(prompt.AbsoluteSize.X, prompt.AbsoluteSize.Y) or nil,
				GroupTransparency = prompt:IsA("CanvasGroup") and 0 or nil
			}
		)
		
		local outTween = TweenService:Create(
			prompt, TweenInfo.new(0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{
				Size = prompt:IsA("Frame") and UDim2.fromScale(0, 0) or nil,
				GroupTransparency = prompt:IsA("CanvasGroup") and 1 or nil
			}
		)
		
		-- Play a sound
		if (currencyInfo.soundId) then
			local sound = Instance.new("Sound")
			sound.SoundId = currencyInfo.soundId
			sound.Parent = prompt
			sound.PlayOnRemove = true
			sound:Destroy()
		end
		
		if (prompt:IsA("CanvasGroup")) then prompt.GroupTransparency = 1 end
		if (prompt:IsA("Frame")) then prompt.Size = UDim2.fromScale(0, 0) end
		
		prompt.Visible = true
		inTween:Play()
		inTween.Completed:Wait()
		
		task.wait(2.5)
		outTween:Play()
		outTween.Completed:Wait()
		prompt:Destroy()
	end)
end

function CurrencyDisplay:SetCurrency(currencyId: string, amount: number)
	local label = self._labels[currencyId]
	if not label then
		-- Not all currencies need a label; silently ignore unknown Ids
		return
	end
	-- If you want raw numbers, just tostring(amount). If you want pretty text per currency:
	label.Text = tostring(amount)
end

function CurrencyDisplay:SetMany(changes: {[string]: number})
	for currencyId, amount in pairs(changes) do
		self:SetCurrency(currencyId, amount)
	end
end

function CurrencyDisplay:Show(visible: boolean)
	self._root.Enabled = visible
end

function CurrencyDisplay:Destroy()
	-- cleanup
	self._deps = nil
end

return CurrencyDisplay
