--==================================================
--// DataManager (ModuleScript)
--   DataStore永続化、キャッシュ、マイグレーション管理
--   ［DataStoreイメージ：1 プレイヤー = 1 DataStore］
--     DataStore: PlayerData_v1
--      └── Key: Player_123456   ：ユーザID
--            ├── Currency      ：Gold = 500, Gems = 12,
--            ├── Inventory     ：HighJump01 = 1, SpeedBoost01 = 3, SpeedBoost03 = 50
--            └── Stats
--                  ├── Easy    ：BestTime = 45.2, Wins = 3, Plays = 10
--                  ├── Normal  ：BestTime = nil,  Wins = 0, Plays = 0
--                  └── Hard    ：BestTime = nil,  Wins = 0, Plays = 0
--==================================================
local DataManager = {}
DataManager.__index = DataManager

--// Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

--// Constants
local DATASTORE_NAME    = "PlayerData_v1"
local SAVE_COOLDOWN     = 6   -- Roblox制限対策（6秒制限遵守）
local AUTOSAVE_INTERVAL = 300 -- 5分（仕様§7.2 AutoSave 3〜5分間隔）
local CURRENT_VERSION   = 1   -- 将来増やす

--// Constants Game Rules (Data Limits)
local MAX_GOLD       = 1_000_000_000
local MAX_GEMS       = 1_000_000
local MAX_WINS       = 100_000
local MAX_PLAYS      = 1_000_000
local MAX_ITEM_COUNT = 999
local MIN_BEST_TIME  = 1   -- 1秒未満は無効
local MAX_BEST_TIME  = 600 -- 10分（仕様§7：MAX_ALLOWED_TIMEと統一）

--// DataStore Retry Settings
local MAX_RETRIES = 3
local BASE_DELAY  = 1 -- seconds

--// Default Data Template（仕様書 §7.1）
local DefaultData = {
	Version = CURRENT_VERSION,
	Currency = {
		Gold            = 0,
		Gems            = 0,
		TotalGoldEarned = 0,  -- 獲得Gold累計（減らない）
	},
	Stats = {
		Easy   = { BestTime = nil, Wins = 0, Plays = 0 },
		Normal = { BestTime = nil, Wins = 0, Plays = 0 },
		Hard   = { BestTime = nil, Wins = 0, Plays = 0 },
	},
	Inventory = {},
}
DataManager.DefaultData = DefaultData

--------------------------------------------------
-- コンストラクタ
-- ※依存注入可能（テスト時にMockDataStoreを渡す）
--------------------------------------------------
function DataManager.new(customDataStore)
	local self = setmetatable({}, DataManager)

	-- Fix 1-A: new() も DATASTORE_NAME を使用（"PlayerData" → "PlayerData_v1"）
	if customDataStore then
		self._dataStore = customDataStore
	else
		self._dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
	end

	self._sessionData  = {}
	self._saveQueue    = {}
	self._lastSaveTime = {}
	self._isSaving     = {}
	self._dirtyFlags   = {}
	self._isLoading    = {}

	return self
end

--==============================================================
-- Public API
--==============================================================

----------------------------------------------------------------
-- 初期処理（Init）
-- ※保存トリガー3重を起動（仕様§7.2）
----------------------------------------------------------------
function DataManager:Init()
	print("[DataManager] Init")

	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	self:_bindToClose()
	self:_startSaveLoop()
	self:_startAutoSaveLoop()
end

----------------------------------------------------------------
-- セッションデータ取得（仕様§7.2 セッションキャッシュ）
----------------------------------------------------------------
function DataManager:GetData(player)
	local userId = player.UserId
	return self._sessionData[userId]
end

----------------------------------------------------------------
-- プレイヤー保存要求（キュー登録）
-- ※Session未存在時は拒否
----------------------------------------------------------------
function DataManager:RequestSave(player)
	if not player then
		return false
	end

	local userId = player.UserId

	if not self._sessionData[userId] then
		return false
	end

	if self._saveQueue[userId] then
		return true
	end

	self._saveQueue[userId] = true
	return true
end

----------------------------------------------------------------
-- DirtyFlag 設定
-- ※PlayerOrUserId 両対応
----------------------------------------------------------------
function DataManager:SetDirty(playerOrUserId)
	local userId =
		typeof(playerOrUserId) == "number"
		and playerOrUserId
		or playerOrUserId.UserId

	if self._sessionData[userId] then
		self._dirtyFlags[userId] = true
	end
end

----------------------------------------------------------------
-- 通貨更新（Gold / Gems 両対応）（仕様§7.1）
-- currencyType = "Gold" | "Gems"
----------------------------------------------------------------
function DataManager:UpdateCurrency(player, currencyType, amount)
	local userId = player.UserId
	local data = self._sessionData[userId]
	if not data then return end

	if data.Currency[currencyType] == nil then
		warn("[DataManager] Unknown currencyType:", currencyType)
		return
	end

	data.Currency[currencyType] += amount

	-- Gold 獲得時に累計を加算（支払いなど減少時は加算しない）
	if currencyType == "Gold" and amount > 0 then
		data.Currency.TotalGoldEarned += amount
	end

	self:SetDirty(player)
	self:_updateLeaderstats(userId)
end

----------------------------------------------------------------
-- leaderstats 作成・更新（Gold / Gems をリーダーボードに反映）
----------------------------------------------------------------
function DataManager:_updateLeaderstats(userId)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end

	local data = self._sessionData[userId]
	if not data then return end

	-- leaderstats フォルダを初回のみ作成
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name   = "leaderstats"
		leaderstats.Parent = player

		local gold = Instance.new("IntValue")
		gold.Name   = "Gold"
		gold.Value  = 0
		gold.Parent = leaderstats

		local gems = Instance.new("IntValue")
		gems.Name   = "Gems"
		gems.Value  = 0
		gems.Parent = leaderstats
	end

	local goldValue = leaderstats:FindFirstChild("Gold")
	local gemsValue = leaderstats:FindFirstChild("Gems")

	if goldValue then goldValue.Value = data.Currency.Gold end
	if gemsValue then gemsValue.Value = data.Currency.Gems end
end

----------------------------------------------------------------
-- ラン記録（仕様§7.1 Stats、§3.1 DataManager）
-- ※GoalManager から呼び出す
-- ※didWin = true のときのみ Wins++ / BestTime 更新
-- ※戻り値: isNewBestTime (bool)
----------------------------------------------------------------
function DataManager:RecordRun(player, difficulty, elapsedTime, didWin)
	local userId = player.UserId
	local data = self._sessionData[userId]
	if not data then return false end

	local validDifficulties = { Easy = true, Normal = true, Hard = true }
	if not validDifficulties[difficulty] then
		warn("[DataManager] Unknown difficulty:", difficulty)
		return false
	end

	local stats = data.Stats[difficulty]
	if not stats then return false end

	-- Plays は常に加算
	stats.Plays = (stats.Plays or 0) + 1

	local isNewBest = false

	if didWin then
		stats.Wins = (stats.Wins or 0) + 1

		-- BestTime: 有効値かつ改善時のみ更新
		if self:isValidNumber(elapsedTime)
			and elapsedTime >= MIN_BEST_TIME
			and elapsedTime <= MAX_BEST_TIME then

			if stats.BestTime == nil or elapsedTime < stats.BestTime then
				stats.BestTime = elapsedTime
				isNewBest = true
			end
		end
	end

	self:SetDirty(player)
	return isNewBest
end

----------------------------------------------------------------
-- DataStore 差し替え（テスト用）
----------------------------------------------------------------
function DataManager:SetDataStore(store)
	self._dataStore = store
end

--==============================================================
-- Private Core Logic
-- (Player Lifecycle)
--==============================================================

----------------------------------------------------------------
-- プレイヤーロード処理（仕様§7.2 セッションキャッシュ）
----------------------------------------------------------------
function DataManager:_onPlayerAdded(userId)
	if self._sessionData[userId] or self._isLoading[userId] then
		return
	end

	self._isLoading[userId] = true

	local success, err = pcall(function()
		local key = "Player_" .. userId

		local rawData = self:_getAsyncWithRetry(key)

		if rawData then
			rawData = self:_migrate(rawData)
		else
			rawData = self:_createDefaultData()
		end

		rawData = self:_sanitize(rawData)

		self._sessionData[userId]  = rawData
		self._dirtyFlags[userId]   = false
		self._lastSaveTime[userId] = os.clock()

		-- leaderstats を初期値で作成
		self:_updateLeaderstats(userId)
	end)

	self._isLoading[userId] = nil

	if not success then
		warn("[DataManager] Failed loading user:", userId, err)
	end
end

----------------------------------------------------------------
-- プレイヤー退出処理
-- ※PlayerOrUserId 両対応
----------------------------------------------------------------
function DataManager:_onPlayerRemoving(playerOrUserId)
	local userId =
		typeof(playerOrUserId) == "number"
		and playerOrUserId
		or playerOrUserId.UserId

	if not self._sessionData[userId] then
		return
	end

	-- Fix 1-D: userId（number）を渡す
	self:_performSave(userId)

	self._sessionData[userId]  = nil
	self._dirtyFlags[userId]   = nil
	self._saveQueue[userId]    = nil
	self._lastSaveTime[userId] = nil
	self._isSaving[userId]     = nil
	self._isLoading[userId]    = nil
end

----------------------------------------------------------------
-- BindToClose（仕様§7.2 保存トリガー3重のうち2番目）
-- ※全員保存後 最大25秒待機
----------------------------------------------------------------
function DataManager:_bindToClose()
	game:BindToClose(function()
		local players = Players:GetPlayers()

		for _, player in ipairs(players) do
			task.spawn(function()
				-- Fix 1-D: userId を渡す
				self:_performSave(player.UserId)
			end)
		end

		local timeout = os.clock() + 25
		while os.clock() < timeout do
			if not self:_hasActiveSaves() then
				break
			end
			task.wait(0.5)
		end
	end)
end

----------------------------------------------------------------
-- 保存中が存在するか判定
----------------------------------------------------------------
function DataManager:_hasActiveSaves()
	for _, isSaving in pairs(self._isSaving) do
		if isSaving then
			return true
		end
	end
	return false
end

--==============================================================
-- Utility functions
-- (Save System)
--==============================================================

----------------------------------------------------------------
-- 指数バックオフ付きGetAsync（仕様§7.2 読み込みリトライ最大3回）
----------------------------------------------------------------
function DataManager:_getAsyncWithRetry(key)
	local attempt = 0

	while attempt < MAX_RETRIES do
		attempt += 1

		local success, result = pcall(function()
			return self._dataStore:GetAsync(key)
		end)

		if success then
			return result
		else
			warn(string.format(
				"[DataManager] GetAsync failed (Attempt %d/%d): %s",
				attempt, MAX_RETRIES, tostring(result)
			))

			if attempt >= MAX_RETRIES then
				break
			end

			local delayTime = (BASE_DELAY * (2 ^ (attempt - 1))) + math.random()
			task.wait(delayTime)
		end
	end

	return nil
end

----------------------------------------------------------------
-- 保存実行（Fix 1-D: PlayerOrUserId 両対応）
-- ※UpdateAsyncのみ使用（仕様§13）
----------------------------------------------------------------
function DataManager:_performSave(playerOrUserId)
	local userId =
		typeof(playerOrUserId) == "number"
		and playerOrUserId
		or playerOrUserId.UserId

	if self._isSaving[userId] then
		return
	end

	local key  = "Player_" .. userId
	local data = self._sessionData[userId]

	if not data then
		return
	end

	self._isSaving[userId] = true

	local success, err = pcall(function()
		self._dataStore:UpdateAsync(key, function(oldData)
			oldData = oldData or self:_createDefaultData()
			oldData = self:_sanitize(oldData)

			oldData.Currency  = self:DeepCopy(data.Currency)
			oldData.Stats     = self:DeepCopy(data.Stats)
			oldData.Inventory = self:DeepCopy(data.Inventory)

			return oldData
		end)
	end)

	if not success then
		warn("[DataManager] Save failed:", err)
	else
		self._lastSaveTime[userId] = os.clock()
	end

	self._isSaving[userId] = false
end

----------------------------------------------------------------
-- キュー監視ループ（仕様§7.2 UpdateAsyncキュー制御・6秒制限）
----------------------------------------------------------------
function DataManager:_startSaveLoop()
	task.spawn(function()
		while true do
			for userId in pairs(self._saveQueue) do
				local player = Players:GetPlayerByUserId(userId)
				if not player then
					self._saveQueue[userId] = nil
					continue
				end

				local lastTime = self._lastSaveTime[userId] or 0
				local now = os.clock()

				if now - lastTime >= SAVE_COOLDOWN then
					self:_performSave(userId)
					self._dirtyFlags[userId] = false
					self._saveQueue[userId]  = nil
				end
			end

			task.wait(1)
		end
	end)
end

----------------------------------------------------------------
-- AutoSave Loop（仕様§7.2 AutoSave）
-- ※DirtyFlag依存のため変更が無いプレイヤーは保存しない
----------------------------------------------------------------
function DataManager:_startAutoSaveLoop()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)

			for userId in pairs(self._sessionData) do
				if self._dirtyFlags[userId] then
					local player = Players:GetPlayerByUserId(userId)
					if player then
						self:RequestSave(player)
					end
				end
			end
		end
	end)
end

--==============================================================
-- Utility functions
-- (Data Processing Pipeline)
--==============================================================

----------------------------------------------------------------
-- マイグレーション（仕様§7.2 マイグレーション）
-- Fix 1-E: self:migrateToV2 / self:migrateToV3 で呼び出し
----------------------------------------------------------------
function DataManager:_migrate(data)
	if not data then
		return self:_createDefaultData()
	end

	if type(data.Version) ~= "number" then
		data.Version = 1
	end

	while data.Version < CURRENT_VERSION do
		if data.Version == 1 then
			data = self:migrateToV2(data)  -- Fix 1-E: self: 経由で呼ぶ
		elseif data.Version == 2 then
			data = self:migrateToV3(data)  -- Fix 1-E: self: 経由で呼ぶ
		else
			warn("[DataManager] Unknown data version:", data.Version)
			break
		end
	end

	return data
end

----------------------------------------------------------------
-- マイグレーション関数（v1→v2、v2→v3）
----------------------------------------------------------------
function DataManager:migrateToV2(data)
	if data.Settings == nil then
		data.Settings = { SFX = true, BGM = true }
	end
	data.Version = 2
	return data
end

function DataManager:migrateToV3(data)
	if data.Currency and data.Currency.Gold then
		data.Currency.Coins = data.Currency.Gold
		data.Currency.Gold  = nil
	end
	data.Version = 3
	return data
end

----------------------------------------------------------------
-- Default Data 生成（安全なDeepCopy）
----------------------------------------------------------------
function DataManager:_createDefaultData()
	local success, newData = pcall(function()
		return self:DeepCopy(DefaultData)
	end)

	if not success or type(newData) ~= "table" then
		warn("[DataManager] Failed to create default data. Rebuilding minimal structure.")
		newData = {
			Version   = CURRENT_VERSION,
			Currency  = { Gold = 0, Gems = 0 },
			Stats     = {},
			Inventory = {},
		}
	end

	newData.Version = CURRENT_VERSION
	return newData
end

----------------------------------------------------------------
-- サニタイズ（Fix 1-B: pcall重複バグを除去してシンプル化）
-- ① 完全破損 → ② 構造保証 → ③ 値の正常化 → ④ ゲームルール → ⑤ 余分キー削除
----------------------------------------------------------------
function DataManager:_sanitize(data)
	-- ① 完全破損
	if typeof(data) ~= "table" then
		data = {}
	end

	-- ② 構造保証（欠落キーを補完）
	data = self:reconcile(data, self.DefaultData)

	-- ③ 値の正常化（in-place、戻り値なし）
	self:sanitizeInventory(data)
	self:sanitizeStats(data)

	-- ④ ゲームルール適用（整合性保証）
	data = self:_applyGameRules(data)

	-- ⑤ 余計なキー削除
	self:removeExtraKeys(data, self.DefaultData)

	return data
end

----------------------------------------------------------------
-- ゲームルール適用（Fix 1-C: sanitizeStats の引数を修正）
----------------------------------------------------------------
function DataManager:_applyGameRules(data)
	if type(data) ~= "table" then
		return self:_createDefaultData()
	end

	-- ① Currency 安全化
	if type(data.Currency) ~= "table" then
		data.Currency = {}
	end

	data.Currency.Gold = self:clampCurrency(data.Currency.Gold, MAX_GOLD)
	data.Currency.Gems = self:clampCurrency(data.Currency.Gems, MAX_GEMS)

	-- ② Stats 構造保証
	if type(data.Stats) ~= "table" then
		data.Stats = {}
	end

	-- Fix 1-C: data ごと渡す（data.Stats ではなく）
	self:sanitizeStats(data)

	-- ③ ゲーム整合性ルール適用（Fix 1-F: MAX_BEST_TIME で統一）
	for _, stats in pairs(data.Stats) do
		if type(stats) == "table" then
			local wins  = stats.Wins
			local plays = stats.Plays

			if wins ~= nil and plays ~= nil then
				if wins > plays then
					stats.Wins = plays
					wins = plays
				end
			end

			if wins == 0 then
				stats.BestTime = nil
			end

			if stats.BestTime ~= nil then
				if not self:isValidNumber(stats.BestTime)
					or stats.BestTime <= 0
					or stats.BestTime > MAX_BEST_TIME then
					stats.BestTime = nil
				end
			end
		end
	end

	return data
end

--==============================================================
-- Utility functions
-- (Sanitizers)
--==============================================================

----------------------------------------------------------------
-- Inventory サニタイズ（in-place、戻り値なし）
----------------------------------------------------------------
function DataManager:sanitizeInventory(data)
	if typeof(data) ~= "table" then
		return
	end

	if typeof(data.Inventory) ~= "table" then
		data.Inventory = {}
		return
	end

	local clean = {}

	for itemId, count in pairs(data.Inventory) do
		if typeof(itemId) == "string" and self:isValidNumber(count) then
			count = math.floor(count)
			if count > 0 then
				clean[itemId] = math.clamp(count, 1, MAX_ITEM_COUNT)
			end
		end
	end

	data.Inventory = clean
end

----------------------------------------------------------------
-- Stats サニタイズ（in-place、戻り値なし）
-- Fix 1-B: data ごと受け取り、data.Stats を直接書き換える
----------------------------------------------------------------
function DataManager:sanitizeStats(data)
	if type(data) ~= "table" then
		return
	end

	if type(data.Stats) ~= "table" then
		data.Stats = {}
		return
	end

	local VALID_DIFFICULTIES = { Easy = true, Normal = true, Hard = true }

	for difficulty, stats in pairs(data.Stats) do
		if not VALID_DIFFICULTIES[difficulty] then
			data.Stats[difficulty] = nil
			continue
		end

		if type(stats) ~= "table" then
			data.Stats[difficulty] = nil
			continue
		end

		-- Plays
		if not self:isValidNumber(stats.Plays) then
			stats.Plays = 0
		else
			stats.Plays = math.floor(stats.Plays)
			if stats.Plays < 0 then
				stats.Plays = nil
			elseif stats.Plays > MAX_PLAYS then
				stats.Plays = MAX_PLAYS
			end
		end

		-- Wins
		local wins = stats.Wins
		if not self:isValidNumber(wins) then
			stats.Wins = 0
		else
			wins = math.floor(wins)
			if wins < 0 then
				stats.Wins = 0
			elseif wins > MAX_WINS then
				stats.Wins = MAX_WINS
			else
				stats.Wins = wins
			end
		end

		-- BestTime（Fix 1-F: MAX_BEST_TIME で統一）
		if stats.BestTime ~= nil then
			if not self:isValidNumber(stats.BestTime)
				or stats.BestTime < MIN_BEST_TIME
				or stats.BestTime > MAX_BEST_TIME then
				stats.BestTime = nil
			end
		end
	end
end

----------------------------------------------------------------
-- reconcile: テンプレート主導の欠落キー補完
----------------------------------------------------------------
function DataManager:reconcile(data, template)
	if type(data) ~= "table" then
		warn("[DataManager] reconcile: data is not table. Resetting.")
		return self:DeepCopy(template)
	end

	for key, defaultValue in pairs(template) do
		local currentValue = data[key]

		if currentValue == nil then
			data[key] = self:DeepCopy(defaultValue)

		elseif type(defaultValue) == "table"
			and type(currentValue) == "table" then
			self:reconcile(currentValue, defaultValue)

		elseif type(currentValue) ~= type(defaultValue) then
			warn(("[DataManager] Type mismatch on key '%s'. Resetting."):format(key))
			data[key] = self:DeepCopy(defaultValue)
		end
	end

	return data
end

----------------------------------------------------------------
-- removeExtraKeys: スキーマ外キー削除（Version は除外）
----------------------------------------------------------------
function DataManager:removeExtraKeys(data, template)
	for key, value in pairs(data) do
		if key ~= "Version" and template[key] == nil then
			data[key] = nil
		elseif type(value) == "table" and type(template[key]) == "table" then
			self:removeExtraKeys(value, template[key])
		end
	end
end

----------------------------------------------------------------
-- clampCurrency: 通貨の型チェック・正規化
----------------------------------------------------------------
function DataManager:clampCurrency(value, maxValue)
	if not self:isValidNumber(value) then
		return 0
	end
	return math.clamp(math.floor(value), 0, maxValue)
end

----------------------------------------------------------------
-- isValidNumber: NaN / Infinity 対策
----------------------------------------------------------------
function DataManager:isValidNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

----------------------------------------------------------------
-- DeepCopy: 循環参照対策付き深いコピー
----------------------------------------------------------------
function DataManager:DeepCopy(original, visited)
	visited = visited or {}

	if type(original) ~= "table" then
		return original
	end

	if typeof(original) == "Instance" then
		warn("[DataManager] Attempted to DeepCopy Instance. Returning nil.")
		return nil
	end

	if visited[original] then
		return visited[original]
	end

	local copy = {}
	visited[original] = copy

	for key, value in pairs(original) do
		local copiedKey   = self:DeepCopy(key, visited)
		local copiedValue = self:DeepCopy(value, visited)
		copy[copiedKey] = copiedValue
	end

	local mt = getmetatable(original)
	if mt then
		setmetatable(copy, self:DeepCopy(mt, visited))
	end

	return copy
end

--==============================================================
-- Test Exports
--==============================================================
DataManager.CURRENT_VERSION = CURRENT_VERSION
DataManager.MAX_RETRIES     = MAX_RETRIES
DataManager.MAX_GOLD        = MAX_GOLD
DataManager.MAX_GEMS        = MAX_GEMS
DataManager.MAX_WINS        = MAX_WINS
DataManager.MAX_PLAYS       = MAX_PLAYS
DataManager.MIN_BEST_TIME   = MIN_BEST_TIME
DataManager.MAX_BEST_TIME   = MAX_BEST_TIME
DataManager.DefaultData     = DefaultData

return DataManager
