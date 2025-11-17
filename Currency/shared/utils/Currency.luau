--!strict
-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Data
local GameData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameData"))

local CurrencyUtil = {}

function CurrencyUtil.GetCurrencyText(currencyId: string, amount: number, useCurrencyName: boolean?): string
	local currencyInfo = GameData.Get("Currency", currencyId)
	if not currencyInfo then
		return tostring(amount)
	end

	if currencyInfo.symbol == "" or useCurrencyName then
		return tostring(amount) .. " " .. currencyInfo.name
	else
		return currencyInfo.symbol .. tostring(amount)
	end
end

return CurrencyUtil