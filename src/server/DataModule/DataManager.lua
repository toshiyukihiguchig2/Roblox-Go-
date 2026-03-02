-- 残タスク
---- DirtyFlag管理API作成
---- UpdateAsyncマージ設計
---- BindToClose待機改善
---- SaveQueueをUserIdベースへ変更

--==================================================
--// DataManager (ModuleScript)
--   DataStore永続化、キャッシュ、マイグレーション管理
--   ［DataStoreイメージ：1 プレイヤー = 1 DataStore］
--     DataStore: PlayerData_v1
--      └── Key: Player_123456   ：ユーザID
--            ├── Currency      ：Gold = 500, Gems = 12,
--            ├── Inventory     ：HighJump01 = 1, SpeedBoost01 = 3, SpeedBoost03 = 50
--            ├── EquippedItem  ：HighJump01 = true, SpeedBoost01 = false, SpeedBoost03 = true
--            ├── Stats.Easy    ：BestTime = 45.2, Wins = 3, PlayCount = 10
--            ├── Stats.Normal  ：BestTime = nil,  Wins = 0, PlayCount = 0
--            └── Stats.Hard    ：BestTime = nil,  Wins = 0, PlayCount = 0
--==================================================
local DataManager = {}
DataManager.__index = DataManager

--// Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

--// Constants
local DATASTORE_NAME = "PlayerData_v1"
local SAVE_COOLDOWN = 6 -- Roblox制限対策（6秒制限遵守）
local AUTOSAVE_INTERVAL = 300 -- 5分
local CURRENT_VERSION = 1 -- 将来増やす

--// Constants Game Rules (Data Limits)
local MAX_GOLD = 1_000_000_000
local MAX_GEMS = 1_000_000
local MAX_WINS = 100_000
local MAX_PLAYS = 1_000_000
local DIFFICULTIES = {
	Easy = true,
	Normal = true,
	Hard = true,
}
local MAX_ITEM_COUNT = 999
local MIN_BEST_TIME = 1      -- 1秒未満は無効
local MAX_BEST_TIME = 10_000 -- 異常値防止（約3時間）
local MAX_ALLOWED_TIME = 600

--// DataStore Retry Settings
local MAX_RETRIES = 3
local BASE_DELAY = 1 -- seconds

--// Default Data Template
local DefaultData = {
	Version = CURRENT_VERSION,
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
DataManager.DefaultData = DefaultData

--// Forward declarations
local playerStore
local migrateToV2
local migrateToV3

--------------------------------------------------
-- コンストラクタ
-- ※依存注入可能、並列サーバー安全対策
-- ※データや処理を「複数のグループ（Shard）」に分割して管理可能
--   Easy・Normal・Hardロビー（サーバー）：各専用ロビーへのシャーディング対策
--------------------------------------------------
--  ［シャーディング例：Easy用DataManager、DataStore］
--    local EasyDataManager = DataManager.new("Easy")
--
--    local shardName = "Easy"
--    local dataStoreName = "PlayerData_" .. shardName　　→　"PlayerData_Easy"
--    local easyStore = DataStoreService:GetDataStore(dataStoreName)
--
--------------------------------------------------
--  ［シャーディング例：Hard用DataManager、DataStore］
--    local HardDataManager = DataManager.new("Hard")
--
--    local shardName = "Hard"
--    local dataStoreName = "PlayerData_" .. shardName　　→　"HardEasy"
--    local hardStore = DataStoreService:GetDataStore(dataStoreName)
--
--------------------------------------------------
function DataManager.new(customDataStore)
	local self = setmetatable({}, DataManager)

	-- 依存注入対応
	if customDataStore then
		self._dataStore = customDataStore
	else
		self._dataStore = DataStoreService:GetDataStore("PlayerData")
	end
	self._sessionData = {}
	self._saveQueue = {}
	self._lastSaveTime = {}
	self._isSaving = {}
	self._dirtyFlags = {}
	self._isLoading = {}

	return self
end

--==============================================================
-- Public API
----------------------------------------------------------------
-- 初期処理（Init）
----------------------------------------------------------------
function DataManager:Init()

    if not playerStore then
		playerStore = DataStoreService:GetDataStore(DATASTORE_NAME)
		print("[DataManager] Using Roblox DataStore")
	else
		print("[DataManager] Using Custom DataStore")
	end

	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	self:_bindToClose()
	self:_startSaveLoop()
	self:_startAutoSaveLoop()
end

----------------------------------------------------------------
-- プレイヤー保存要求
-- ※Session未存在時は拒否
-- ※戻り値で成功/失敗を明示
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
-- 
-- 
-- 
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
-- 
-- 
-- 
----------------------------------------------------------------
function DataManager:UpdateCurrency(player, amount)

	local userId = player.UserId
	local data = self._sessionData[userId]
	if not data then return end

	data.Currency.Gold += amount
	self:SetDirty(player)

end

----------------------------------------------------------------
-- 本番・テスト切り替え用
-- ［呼び出し例：本番］
--   DataManager:Init()
--
-- ［呼び出し例：テスト（TestRunner）］
--   local mock = MockDataStore.new()
--   DataManager:SetDataStore(mock)
--   DataManager:Init()
----------------------------------------------------------------
function DataManager:SetDataStore(store)
	playerStore = store
end

--==============================================================
-- Private Core Logic
-- (Player Lifecycle)
----------------------------------------------------------------
-- プレイヤーロード処理
-- [プレイヤーロードのフロー]
-- PlayerAdded
--    ↓
-- GetAsync（指数バックオフ）
--    ↓
-- nilならDefault生成
--    ↓
-- Versionマイグレーション
--    ↓
-- 構造サニタイズ
--    ↓
-- ゲームルール制限
--    ↓
-- SessionData登録
--    ↓
-- DirtyFlag初期化
----------------------------------------------------------------
function DataManager:_onPlayerAdded(userId)

	if self._sessionData[userId] or self._isLoading[userId] then
		return
	end

	self._isLoading[userId] = true

	local success, err = pcall(function()

		local key = "Player_" .. userId

		----------------------------------------------------------------
		-- 1. GetAsync（指数バックオフ）
		----------------------------------------------------------------
		local rawData = self:_getAsyncWithRetry(key)

		----------------------------------------------------------------
		-- 2. データが存在しない場合
		-- 3. マイグレーション
		----------------------------------------------------------------
		if rawData then
			rawData = self:_migrate(rawData)
		else
			rawData = self:_createDefaultData()
		end

		----------------------------------------------------------------
		-- 4. 構造サニタイズ
		----------------------------------------------------------------
		rawData = self:_sanitize(rawData)

		----------------------------------------------------------------
		-- 5. ゲームルール適用
		----------------------------------------------------------------
		rawData = self:_applyGameRules(rawData)

		----------------------------------------------------------------
		-- 6. セッション登録
		----------------------------------------------------------------
		self._sessionData[userId] = rawData
		self._dirtyFlags[userId] = false
		self._lastSaveTime[userId] = os.clock()
	end)

	self._isLoading[userId] = nil

	if not success then
		warn("[DataManager] Failed loading user:", userId, err)
	end
end

----------------------------------------------------------------
-- 
-- 
-- 
----------------------------------------------------------------
function DataManager:_onPlayerRemoving(playerOrUserId)

	local userId =
		typeof(playerOrUserId) == "number"
		and playerOrUserId
		or playerOrUserId.UserId

	if not self._sessionData[userId] then
		return
	end

	-- 保存実行
	self:_performSave(userId)

	-- メモリ解放
	self._sessionData[userId] = nil
	self._dirtyFlags[userId] = nil
	self._saveQueue[userId] = nil
	self._lastSaveTime[userId] = nil
	self._isSaving[userId] = nil
	self._isLoading[userId] = nil
end

----------------------------------------------------------------
-- 
-- 
-- 
----------------------------------------------------------------
function DataManager:_bindToClose()

	game:BindToClose(function()

		local players = Players:GetPlayers()

		-- ① 全員保存要求
		for _, player in ipairs(players) do
			task.spawn(function()
				self:_performSave(player)
			end)
		end

		-- ② 最大25秒待機
		local timeout = os.clock() + 25

		while os.clock() < timeout do
			if not self:_hasActiveSaves() then
				break
			end
			task.wait(0.5)
		end

	end)
end

--------------------------------------------------
-- 保存中が存在するか判定
--------------------------------------------------
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
----------------------------------------------------------------
-- 指数バックオフ付きGetAsync：失敗時の挙動→ DefaultData生成でゲーム継続UX優先
-- ※外部サービス（DataStore等）のネットワーク瞬断対策
-- ※スロットリング（読み書き回数制限）中の大量同時Join対策
-- ※サーバー起動直後の負荷集中対策
-- ※DataStoreのpcall呼び出しエラーによるサーバーダウン対策
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
				attempt,
				MAX_RETRIES,
				tostring(result)
			))

			if attempt >= MAX_RETRIES then
				break
			end

			-- 指数バックオフ + ジッター
			local delayTime = (BASE_DELAY * (2 ^ (attempt - 1))) + math.random()
			task.wait(delayTime)
		end
	end

	return nil
end

----------------------------------------------------------------
-- プレイヤーからの保存要求
----------------------------------------------------------------
function DataManager:_performSave(player)

	local userId = player.UserId

	if self._isSaving[userId] then
		return
	end

	local key = "Player_" .. userId
	local data = self._sessionData[userId]

	if not data then
		return
	end

	self._isSaving[userId] = true

	local success, err = pcall(function()
		playerStore:UpdateAsync(key, function(oldData)

			oldData = oldData or self:_createDefaultData()

			oldData = self:_sanitize(oldData)

			oldData.Currency = self:DeepCopy(data.Currency)
			oldData.Stats = self:DeepCopy(data.Stats)
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
-- キュー監視ループ
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
                    self:_performSave(player)
                    self._dirtyFlags[userId] = false
                    self._saveQueue[userId] = nil
                end
            end

            task.wait(1)
        end
    end)
end

----------------------------------------------------------------
-- AutoSave Loop
-- ※定期保存によるサーバークラッシュ対策の保険
-- ※保存キュー経由のため直接保存しない
-- ※DirtyFlag依存のため変更が無いプレイヤーは保存しない
----------------------------------------------------------------
function DataManager:_startAutoSaveLoop()

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)

			for userId, data in pairs(self._sessionData) do
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
----------------------------------------------------------------
-- マイグレーション：差分マイグレーション方式
-- ※クラッシュ防止（nilチェック徹底、typeチェック、未知バージョンはbreak）
-- ※データ継続性（既存値は絶対に上書きしない）
----------------------------------------------------------------
function DataManager:_migrate(data)
	if not data then
		return self:_createDefaultData()
	end

	-- Versionが無い古いデータ対策
	if type(data.Version) ~= "number" then
		data.Version = 1
	end

	-- 段階的マイグレーション
	while data.Version < CURRENT_VERSION do

		if data.Version == 1 then
			data = migrateToV2(data)

		elseif data.Version == 2 then
			data = migrateToV3(data)

		else
			warn("Unknown data version:", data.Version)
			break
		end
	end

	return data
end

----------------------------------------------------------------
-- マイグレーション関数
-- ※現時点では仮定した変更内容でv3までを準備しておく
----------------------------------------------------------------
-- v1 → v2 例
function DataManager:migrateToV2(data)
	-- 例: Settings追加
	if data.Settings == nil then
		data.Settings = {
			SFX = true,
			BGM = true,
		}
	end

	data.Version = 2
	return data
end

-- v2 → v3 例
function DataManager:migrateToV3(data)
	-- 例: GoldをCoinsへ名称変更
	if data.Currency and data.Currency.Gold then
		data.Currency.Coins = data.Currency.Gold
		data.Currency.Gold = nil
	end

	data.Version = 3
	return data
end

----------------------------------------------------------------
-- Create Default Data (Safe Instance)
----------------------------------------------------------------
function DataManager:_createDefaultData()
	local success, newData = pcall(function()
		return self:DeepCopy(DefaultData)
	end)

	if not success or type(newData) ~= "table" then
		warn("[DataManager] Failed to create default data. Rebuilding minimal structure.")

		-- 最低限のフェイルセーフ
		newData = {
			Version = CURRENT_VERSION,
			Currency = {
				Gold = 0,
				Gems = 0,
			},
			Stats = {},
			Inventory = {}
		}
	end

	-- Version保証
	newData.Version = CURRENT_VERSION

	return newData
end

----------------------------------------------------------------
-- |処理				|役割
-- |sanitize			|型・値を正す
-- |removeExtraKeys		|余分キー削除
-- |reconcile			|不足キー補完
--------------------------------------------------
-- テンプレート主導reconcile方式
-- ※構造の欠落（Missing Keys）、NaN（Not a Number）の混入対策
--------------------------------------------------
function DataManager:reconcile(data, template)
	-- 安全チェック
	if type(data) ~= "table" then
		warn("[DataManager] reconcile: data is not table. Resetting.")
		return self:DeepCopy(template)
	end

	for key, defaultValue in pairs(template) do
		local currentValue = data[key]

		-- 存在しない場合は補完
		if currentValue == nil then
			data[key] = self:DeepCopy(defaultValue)

		-- 両方tableなら再帰
		elseif type(defaultValue) == "table"
			and type(currentValue) == "table" then

			self:reconcile(currentValue, defaultValue)

		-- 型が違う場合は修正（重要）
		elseif type(currentValue) ~= type(defaultValue) then
			warn(("[DataManager] Type mismatch on key '%s'. Resetting."):format(key))
			data[key] = self:DeepCopy(defaultValue)
		end
	end

	return data
end

----------------------------------------------------------------
-- |処理				|役割
-- |sanitize			|型・値を正す
-- |removeExtraKeys		|余分キー削除
-- |reconcile			|不足キー補完
----------------------------------------------------------------
-- 不正キー削除
--
-- ※現在のスキーマに適合させることを目的とする（reconcileとは別にして役割を分業する）
-- ※DefaultDataに存在しないキーは削除するが、将来拡張に備えVersionは処理対象から除外しておく
-- ［不正キー削除仕様］
-- ※未定義の不正キーを削除、reconcile前に一度通すこと
----------------------------------------------------------------
function DataManager:removeExtraKeys(data, template)
	for key, value in pairs(data) do

		-- Versionは例外的に保持
		if key ~= "Version" and template[key] == nil then
			data[key] = nil

		elseif type(value) == "table" and type(template[key]) == "table" then
			self:removeExtraKeys(value, template[key])
		end
	end
end

----------------------------------------------------------------
-- |処理				|役割
-- |sanitize			|型・値を正す
-- |removeExtraKeys		|余分キー削除
-- |reconcile			|不足キー補完
----------------------------------------------------------------
-- 不正値防止（データサニタイズ）：
-- ［サニタイズ処理仕様］
--  以下を順次呼び出し。
--  型ガード（完全破損対策）、値サニタイズ（ホワイトリスト再構築）
--  未定義キー削除（スキーマ外排除）、欠落補完（完全スキーマ化）
----------------------------------------------------------------
function DataManager:_sanitize(data)

	-- ① 完全破損
	if typeof(data) ~= "table" then
		data = {}
	end

	-- ② 構造保証
	print("② 構造保証")
	local status, err = pcall(function()
		self:reconcile(data)
	end)
	if not status then
		warn("Error applying game rules:", err)
	end
	data = self:reconcile(data, self.DefaultData)

	-- ③ 値の正常化
	print("③ 値の正常化")
	local status, err = pcall(function()
		self:sanitizeInventory(data)
	end)
	if not status then
		warn("Error applying game rules:", err)
	end
	data.Inventory = self:sanitizeInventory(data.Inventory)
	data.Stats = self:sanitizeStats(data.Stats)

	-- ④ ゲームルール適用（整合性保証）
	print("④ ゲームルール適用（整合性保証）")
	local status, err = pcall(function()
		self:_applyGameRules(data)
	end)
	if not status then
		warn("Error applying game rules:", err)
	end
	data = self:_applyGameRules(data)

	-- ⑤ 余計なキー削除
	self:removeExtraKeys(data, self.DefaultData)

	return data
end

----------------------------------------------------------------
-- Apply Game Logic Rules
----------------------------------------------------------------
function DataManager:_applyGameRules(data)
	if type(data) ~= "table" then
		return self:_createDefaultData()
	end

	--------------------------------------------------
	-- ① Currency安全化
	--------------------------------------------------

	if type(data.Currency) ~= "table" then
		data.Currency = {}
	end

	data.Currency.Gold =
		self:clampCurrency(data.Currency.Gold, MAX_GOLD)

	data.Currency.Gems =
		self:clampCurrency(data.Currency.Gems, MAX_GEMS)

	--------------------------------------------------
	-- ② Stats構造保証
	--------------------------------------------------

	if type(data.Stats) ~= "table" then
		data.Stats = {}
	end

	data.Stats = self:sanitizeStats(data.Stats)

	--------------------------------------------------
	-- ③ ゲーム整合性ルール適用
	--------------------------------------------------

	for difficulty, stats in pairs(data.Stats) do
		if type(stats) == "table" then

			local wins = stats.Wins
			local plays = stats.Plays

			-- Wins > Plays 防止（両方存在する時のみ）
			if wins ~= nil and plays ~= nil then
				if wins > plays then
					stats.Wins = plays
					wins = plays
				end
			end

			-- 勝利ゼロならBestTime削除
			if wins == 0 then
				stats.BestTime = nil
			end

			-- BestTime妥当性（nil安全）
			if stats.BestTime ~= nil then
				if not self:isValidNumber(stats.BestTime)
					or stats.BestTime <= 0
					or stats.BestTime > MAX_ALLOWED_TIME then

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
----------------------------------------------------------------
-- |処理				|役割
-- |sanitize			|型・値を正す
-- |removeExtraKeys		|余分キー削除
-- |reconcile			|不足キー補完
----------------------------------------------------------------
-- 所持アイテム管理
-- ※DataStore 4MB上限対策、DoS防止、メモリ保護
-- ［data.Inventory仕様］
--  数量は 1〜999、不正値は削除、小数は切り捨て、非数値は削除
--  不正キーを除去する
--  予期せぬメタデータを排除する
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

		-- キーが文字列か
		if typeof(itemId) == "string"
			and self:isValidNumber(count) then

			count = math.floor(count)

			if count > 0 then
				clean[itemId] = math.clamp(count, 1, MAX_ITEM_COUNT)
			end
		end
	end

	data.Inventory = clean
end

----------------------------------------------------------------
-- |処理				|役割
-- |sanitize			|型・値を正す
-- |removeExtraKeys		|余分キー削除
-- |reconcile			|不足キー補完
----------------------------------------------------------------
-- ゲームステータス管理（Stats制限＋BestTime妥当性）
-- ［ステータス管理仕様］
--  不正difficulty削除、不正フィールド削除、型が違えば初期化（Type Mismatch）
--  整数はfloor、上限clamp、マイナス値の注入対策
--  難易度：（Easy / Normal / Hard）
--  BestTime：number、0より大きい、小数を扱う
--  Wins：整数、0以上、上限あり（100_000にしておく）
--  Plays：整数、0以上、上限あり（1_000_000にしておく）
----------------------------------------------------------------
function DataManager:sanitizeStats(data)

	if type(data) ~= "table" then
        return
    end

	if type(data.Stats) ~= "table" then
		data.Stats = {}
		return
	end

	local VALID_DIFFICULTIES = {
		Easy = true,
		Normal = true,
		Hard = true
	}

	for difficulty, stats in pairs(data.Stats) do

		-- 不正difficulty削除
		if not VALID_DIFFICULTIES[difficulty] then
			data.Stats[difficulty] = nil
			continue
		end

		if type(stats) ~= "table" then
			data.Stats[difficulty] = nil
			continue
		end

		-- =====================
		-- Plays
		-- =====================

		if not self:isValidNumber(stats.Plays) then
			stats.Plays = 0
		else
			stats.Plays = math.floor(stats.Plays)

			if stats.Plays < 0 then
				stats.Plays = nil -- ← negativeは削除
			elseif stats.Plays > MAX_PLAYS then
				stats.Plays = MAX_PLAYS
			end
		end

		-- =====================
		-- Wins
		-- =====================

		local wins = stats.Wins

		-- ① 型と数値妥当性
		if not self:isValidNumber(wins) then
			stats.Wins = 0
		else
			-- ② 正規化
			wins = math.floor(wins)

			-- ③ 負値は0
			if wins < 0 then
				stats.Wins = 0

			-- ④ 上限クランプ
			elseif wins > MAX_WINS then
				stats.Wins = MAX_WINS

			else
				stats.Wins = wins
			end
		end

		-- =====================
		-- BestTime
		-- =====================

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
-- 通貨制限チェック
-- ※保存前の改ざん対策（型チェック、NaN対策、Infinity対策、テーブル破損対策）
-- ［通貨仕様］
--  整数のみ（マイナス値の注入対策）、下限 0、上限あり（MAX_GOLD / MAX_GEMS）
--  小数は切り捨て、不正値（nil / 文字列 / NaN / inf）は 0 にリセット
--  Currencyテーブルが壊れていても復元
----------------------------------------------------------------
function DataManager:clampCurrency(value, maxValue)
	if not self:isValidNumber(value) then
		return 0
	end

	value = math.floor(value)

	return math.clamp(value, 0, maxValue)
end

----------------------------------------------------------------
-- 数値チェックユーティリティ
-- ※文字列数値の混入対策
-- ※NaN（Not a Number）の混入対策
-- ※無限値（math.huge / -math.huge）対策
----------------------------------------------------------------
function DataManager:isValidNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

----------------------------------------------------------------
-- DeepCopy（安全な間接参照作成）
-- ※参照渡し（Pass-by-reference）対策
-- ※table.clone()によるシャローコピー状態を対策（深層が参照のままになっていることがあるので）
----------------------------------------------------------------
function DataManager:DeepCopy(original, visited)
	visited = visited or {}

	-- プリミティブ型はそのまま
	if type(original) ~= "table" then
		return original
	end

	-- Roblox Instanceはコピーしない（安全対策）
	if typeof(original) == "Instance" then
		warn("[DataManager] Attempted to DeepCopy Instance. Returning nil.")
		return nil
	end

	-- 循環参照対策
	if visited[original] then
		return visited[original]
	end

	local copy = {}
	visited[original] = copy

	for key, value in pairs(original) do
		local copiedKey = self:DeepCopy(key, visited)
		local copiedValue = self:DeepCopy(value, visited)
		copy[copiedKey] = copiedValue
	end

	-- metatableもコピー（必要な場合）
	local mt = getmetatable(original)
	if mt then
		setmetatable(copy, self:DeepCopy(mt, visited))
	end

	return copy
end

--==============================================================
-- Test Exports
----------------------------------------------------------------
DataManager.CURRENT_VERSION = CURRENT_VERSION
DataManager.MAX_RETRIES = MAX_RETRIES
DataManager.MAX_GOLD = MAX_GOLD
DataManager.MAX_GEMS = MAX_GEMS
DataManager.MAX_WINS = MAX_WINS
DataManager.MAX_PLAYS = MAX_PLAYS
DataManager.MIN_BEST_TIME = MIN_BEST_TIME
DataManager.MAX_BEST_TIME = MAX_BEST_TIME
DataManager.DefaultData = DefaultData

return DataManager