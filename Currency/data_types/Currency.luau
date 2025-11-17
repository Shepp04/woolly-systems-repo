
--!strict
-- Currency (GameData type)

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Assets
local Assets = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets")
local ModelsFolder = Assets:WaitForChild("Models")

-- // Types
local DataTypes = require(ReplicatedStorage.Shared.Types.Data)

type PlayerProfile = DataTypes.PlayerProfile

type Collectable = {
	name: string,
	value: number,
	model: Model,
	soundId: number,
}

export type DataEntry = {
	name: string,
	symbol: string,
	icon: string?,
	collectSoundId: number?,
	spendSoundId: number?,
	defaultValue: number?,
	earnedPromptEnabled: boolean?,
	rebirthMultiplier: number?,
	useLeaderstats: boolean,
	leaderstatsPosition: number?,
	friendBoostMultiplier: number?,
	collectables: { Collectable }?,

	Get: (profile: PlayerProfile) -> number,
	Set: (player: Player, profile: PlayerProfile, amount: number) -> (),
	Update: (player: Player, profile: PlayerProfile, amount: number) -> (),
}

type DataTypeDict = {
	name: string,
	public_field_whitelist: { [string]: boolean },
	items: { [string]: DataEntry },

	GetCurrencyText: (self: DataTypeDict, currencyId: string, amount: number, useCurrencyName: boolean?) -> string
}

local DATA_TYPE_NAME = "Currency"
local PUBLIC_FIELD_WHITELIST = {
	name = true, symbol = true, icon = true, collectSoundId = true, spendSoundId = true, defaultValue = true, rebirthMultiplier = true,
	useLeaderstats = true, leaderstatsPosition = true, useFriendsBoost = true, collectables = true,
	Get = false, Set = false, Update = false,
}
local DATA: { [string]: DataEntry } = {
	Cash = {
		name = "Cash",
		symbol = "$",
		icon = "rbxassetid://139861974184937",
		collectSoundId = 7112275565,
		spendSoundId = 81816893340749,
		defaultValue = 0,
		earnedPromptEnabled = true,
		rebirthMultiplier = nil,
		useLeaderstats = true,
		leaderstatsPosition = 1,
		friendBoostMultiplier = nil,
		collectables = nil,

		Get = function(profile: PlayerProfile): number
			return profile.Data.Stats and profile.Data.Stats.Cash or 0
		end,

		Set = function(player: Player, profile: PlayerProfile, amount: number)
			if profile.Data.Stats then
				profile.Data.Stats.Cash = amount
			end
		end,
		
		Update = function(player: Player, profile: PlayerProfile, amount: number)
			if profile.Data.Stats and profile.Data.Stats.Cash then
				profile.Data.Stats.Cash += amount
			end
		end,
	},

	Miles = {
		name = "Total Miles",
		symbol = "mi",
		icon = nil,
		collectSoundId = nil,
		spendSoundId = nil,
		defaultValue = 0,
		earnedPromptEnabled = false,
		rebirthMultiplier = nil,
		useLeaderstats = true,
		leaderstatsPosition = 2,
		friendBoostMultiplier = nil,
		collectables = nil,

		Get = function(profile: PlayerProfile): number
			return profile.Data.Stats and profile.Data.Stats.Miles or 0
		end,

		Set = function(player: Player, profile: PlayerProfile, amount: number)
			if profile.Data.Stats then
				profile.Data.Stats.Miles = amount
			end
		end,
		
		Update = function(player: Player, profile: PlayerProfile, amount: number)
			if profile.Data.Stats and profile.Data.Stats.Miles then
				profile.Data.Stats.Miles += amount
			end
		end,
	}
}

local DataTypeDict: DataTypeDict = {
	name = DATA_TYPE_NAME,
	public_field_whitelist = PUBLIC_FIELD_WHITELIST,
	items = DATA,
}

return DataTypeDict