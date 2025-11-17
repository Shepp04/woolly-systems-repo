--!strict
-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- // Types
local Types = require(ReplicatedStorage.Shared.Types.Monetisation)
type DevProductPrivate = Types.DevProductPrivate
type Handler = Types.Handler

-- ========== Handlers ========== --
local Handlers: { [string]: Handler } = {
    CurrencyDevProduct = function(player: Player, productId: number, params: { any }?, deps: { any }?): boolean
        local value = params.value
        local currencyId = params.currencyId

        assert(typeof(value) == "number", "Invalid value for CurrencyDevProduct")
        assert(typeof(currencyId) == "string", "Invalid currencyId for CurrencyDevProduct")
        
        -- // Grant currency to player
        local CurrencyService = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services")).Get("CurrencyService")
        if not CurrencyService then
            error("CurrencyService not found")
        end
        
        local ok, err = CurrencyService:GiveCurrency(player, currencyId, value, false)
        if not ok then
            warn("Failed to grant currency to player:", err)
            return false
        end

        return true
    end,
}

-- ========== Definitions ========== --
local defs: { devProducts: { DevProductPrivate } } = {
    devProducts = {
        DevProduct01 = {
            id = 1151725677,
            name = "Dev Product 01",
            category = "Currency",
            description = nil, -- hydrated later
            priceInRobux = nil, -- hydrated later
            iconImageAssetId = nil, -- hydrated later
            handler = Handlers.CurrencyDevProduct,
            params = { value = 10, currencyId = "Cash" },
        },
	},
}

return defs
