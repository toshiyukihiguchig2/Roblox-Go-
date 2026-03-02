----------------------------------------------------------------------------------------------------
-- tests/DataManagerTest.lua
--
-- //テスト方針//
-- 純粋関数（単体テスト）：副作用なし・DataStore未使用
-- ［対象］
--  deepCopy(),reconcile(),_sanitize(),_applyGameRules(),removeExtraKeys(),sanitizeInventory(),
--  clampCurrency(),sanitizeStats(),_migrate(),_createDefaultData(),isValidNumber()
--
-- 準純粋関数（Session依存）：Playerモック使用
-- ［対象］
--  RequestSave(),SetDirty(),_onPlayerAdded(),_onPlayerRemoving()
--
-- 外部依存関数（Mock必須）：MockDataStore使用
-- ［対象］
--  _getAsyncWithRetry(),performSave(),_startSaveLoop(),_startAutoSaveLoop(),_bindToClose()
----------------------------------------------------------------------------------------------------
local DataManager = require(script.Parent.Parent.Parent.DataModule.DataManager)
local Players = game:GetService("Players")

local Test = {}

function Test:RunBasicTest()

	print("=== Basic Test ===")

	local player = Players:GetPlayers()[1]
	if not player then
		warn("No player found.")
		return
	end

	local data = DataManager:GetData(player)
	if not data then
		warn("No session data.")
		return
	end

	data.Currency.Gold += 500
	DataManager:SetDirty(player)
	DataManager:RequestSave(player)

	print("Gold updated and save requested.")
end

return Test