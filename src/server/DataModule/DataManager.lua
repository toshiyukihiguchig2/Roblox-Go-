-- ServerScriptService/DataModule/DataManager.lua

local DataManager = {}
DataManager.__index = DataManager

--// Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

--// Constants
local DATASTORE_NAME = "PlayerData_v1"
local SAVE_COOLDOWN = 6 -- Roblox制限対策
local AUTOSAVE_INTERVAL = 300 -- 5分

--// DataStore
local playerStore = DataStoreService:GetDataStore(DATASTORE_NAME)

--// Session Cache
local SessionData = {}
local LastSaveTime = {}
local DirtyFlags = {}

--// Default Data Template
local DefaultData = {
	Version = 1,
	Currency = {
		Gold = 0,
		Gems = 0,
	},
	Stats = {
		Easy = { BestTime = nil, Wins = 0, Plays = 0 },
		Normal = { BestTime = nil, Wins = 0, Plays = 0 },
		Hard = { BestTime = nil, Wins = 0, Plays = 0 },
	},
	Inventory = {},
}