-- 残タスク
---- DirtyFlag管理API作成
---- UpdateAsyncマージ設計
---- BindToClose待機改善
---- SaveQueueをUserIdベースへ変更

--==================================================
-- DataManager (ModuleScript)
-- DataStore永続化、キャッシュ、マイグレーション管理
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
local MAX_INVENTORY_ITEMS = 200
local MIN_BEST_TIME = 1      -- 1秒未満は無効
local MAX_BEST_TIME = 10_000 -- 異常値防止（約3時間）

--// DataStore Retry Settings
local MAX_RETRIES = 3
local BASE_DELAY = 1 -- seconds

--// Session Cache
local SessionData = {}
local SaveQueue = {}
local LastSaveTime = {}
local IsSaving = {}
local DirtyFlags = {}
local IsLoading = {}

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

--------------------------------------------------
-- 本番・テスト切り替え用
-- ［呼び出し例：本番］
--   DataManager:Init()
--
-- ［呼び出し例：テスト（TestRunner）］
--   local mock = MockDataStore.new()
--   DataManager:SetDataStore(mock)
--   DataManager:Init()
--------------------------------------------------
local playerStore = nil
function DataManager:SetDataStore(store)
	playerStore = store
end

--------------------------------------------------
-- 初期処理（Init）
--------------------------------------------------
function DataManager:Init()

    if not playerStore then
		playerStore = DataStoreService:GetDataStore(DATASTORE_NAME)
		print("[DataManager] Using Roblox DataStore")
	else
		print("[DataManager] Using Custom DataStore")
	end

	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	self:_bindToClose()
	self:_startSaveLoop()
	self:_startAutoSaveLoop()
end

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
function DataManager:_onPlayerAdded(player)

	-- 二重ロード防止
	if SessionData[player] or IsLoading[player] then
		return
	end

	IsLoading[player] = true

	local key = "Player_" .. player.UserId

	----------------------------------------------------------------
	-- 1. GetAsync（指数バックオフ）
	----------------------------------------------------------------
	local rawData = self:_getAsyncWithRetry(playerStore, key)

	----------------------------------------------------------------
	-- 2. データが存在しない場合
	----------------------------------------------------------------
	if not rawData then
		rawData = self:_createDefaultData()
	end

	----------------------------------------------------------------
	-- 3. マイグレーション
	----------------------------------------------------------------
	rawData = self:_migrate(rawData)

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
	SessionData[player] = rawData
	DirtyFlags[player] = false
	LastSaveTime[player] = os.clock()

	IsLoading[player] = nil
end

----------------------------------------------------------------
-- 指数バックオフ付きGetAsync：失敗時の挙動→ DefaultData生成でゲーム継続UX優先
-- ※外部サービス（DataStore等）のネットワーク瞬断対策
-- ※スロットリング（読み書き回数制限）中の大量同時Join対策
-- ※サーバー起動直後の負荷集中対策
-- ※DataStoreのpcall呼び出しエラーによるサーバーダウン対策
----------------------------------------------------------------
function DataManager:_getAsyncWithRetry(store, key)

	local attempt = 0

	while attempt < MAX_RETRIES do
		attempt += 1

		local success, result = pcall(function()
			return store:GetAsync(key)
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

			-- 最終試行なら終了
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

--------------------------------------------------
-- DeepCopy Utility（安全な間接参照作成）
-- ※参照渡し（Pass-by-reference）対策
-- ※table.clone()によるシャローコピー状態を対策（深層が参照のままになっていることがあるので）
--------------------------------------------------
local function deepCopy(original, visited)
	visited = visited or {}

	-- プリミティブ型はそのまま返す
	if type(original) ~= "table" then
		return original
	end

	-- 循環参照対策
	if visited[original] then
		return visited[original]
	end

	local copy = {}
	visited[original] = copy

	for key, value in pairs(original) do
		copy[deepCopy(key, visited)] = deepCopy(value, visited)
	end

	return copy
end

--------------------------------------------------
-- マイグレーション関数
-- ※現時点では仮定した変更内容でv3までを準備しておく
--------------------------------------------------
-- v1 → v2 例
local function migrateToV2(data)
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
local function migrateToV3(data)
	-- 例: GoldをCoinsへ名称変更
	if data.Currency and data.Currency.Gold then
		data.Currency.Coins = data.Currency.Gold
		data.Currency.Gold = nil
	end

	data.Version = 3
	return data
end

-- v4 コメント残ししておく
-- local function migrateToV4(data)
-- 	-- 追加処理
-- 	data.Version = 4
-- 	return data
-- end

--------------------------------------------------
-- マイグレーション：差分マイグレーション方式
-- ※クラッシュ防止（nilチェック徹底、typeチェック、未知バージョンはbreak）
-- ※データ継続性（既存値は絶対に上書きしない）
-- ※拡張性（ver4を追加する場合を考慮してコメント残ししておく）
--------------------------------------------------
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

		-- elseif data.Version == 3 then
	    --     data = migrateToV4(data)

		else
			warn("Unknown data version:", data.Version)
			break
		end
	end

	return data
end

----------------------------------------------------------------
-- Create Default Data (Safe Instance)
----------------------------------------------------------------
function DataManager:_createDefaultData()

	local newData = deepCopy(DefaultData)

	-- 念のためVersionを保証
	newData.Version = CURRENT_VERSION

	return newData
end

----------------------------------------------------------------
-- 数値チェックユーティリティ
-- ※文字列数値の混入対策
-- ※nilエラーの回避
-- ※無限値（math.huge / -math.huge）対策
----------------------------------------------------------------
local function isValidNumber(value)
	if type(value) ~= "number" then
		return false
	end

	if value ~= value then -- NaNチェック
		return false
	end

	if value == math.huge or value == -math.huge then
		return false
	end

	return true
end

--------------------------------------------------
-- テンプレート主導Reconcile方式
-- ※マイナス値の注入対策、型の不一致（Type Mismatch）
-- ※構造の欠落（Missing Keys）、NaN（Not a Number）の混入対策
-- ※DefaultData（雛形）と現在のデータを照合（Reconcile）し、型と値を同時に修正する
--------------------------------------------------
local function reconcile(data, template)
	for key, defaultValue in pairs(template) do
		
		local currentValue = data[key]

		-- 欠落している場合は補完
		if currentValue == nil then
			data[key] = deepCopy(defaultValue)

		elseif type(defaultValue) == "table" then
			-- テーブルの場合は再帰処理
			if type(currentValue) ~= "table" then
				data[key] = deepCopy(defaultValue)
			else
				reconcile(currentValue, defaultValue)
			end

		elseif type(defaultValue) == "number" then
			if not isValidNumber(currentValue) then
				data[key] = defaultValue
			else
				-- マイナス値防止
				if currentValue < 0 then
					data[key] = 0
				end
			end

		elseif type(defaultValue) ~= type(currentValue) then
			-- 型不一致はDefaultへ戻す
			data[key] = defaultValue
		end
	end
end

--------------------------------------------------
-- 不正値防止（データサニタイズ）：
--------------------------------------------------
function DataManager:_sanitize(data)
	reconcile(data, DefaultData)
	return data
end

--------------------------------------------------
-- プレイヤー保存要求
--------------------------------------------------
function DataManager:RequestSave(player)
	if not player then return end
	SaveQueue[player] = true
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

			for player, data in pairs(SessionData) do
				if DirtyFlags[player] then
					self:RequestSave(player)
				end
			end
		end
	end)
end

----------------------------------------------------------------
-- 余分キー削除
-- ※DefaultDataに存在しないキーは削除するが、将来拡張に備え Versionは除外
----------------------------------------------------------------
local function removeExtraKeys(data, template)
	for key in pairs(data) do
		if template[key] == nil and key ~= "Version" then
			data[key] = nil
		elseif type(data[key]) == "table" and type(template[key]) == "table" then
			removeExtraKeys(data[key], template[key])
		end
	end
end

----------------------------------------------------------------
-- Inventory個数制限
-- ※DataStore 4MB上限対策、DoS防止、メモリ保護
----------------------------------------------------------------
local function sanitizeInventory(data)
	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
		return
	end

	local count = 0
	for key in pairs(data.Inventory) do
		count += 1
		if count > MAX_INVENTORY_ITEMS then
			data.Inventory[key] = nil
		end
	end
end

----------------------------------------------------------------
-- 最大値上限制限
----------------------------------------------------------------
local function clampCurrency(data)
	if data.Currency then
		data.Currency.Gold = math.clamp(data.Currency.Gold or 0, 0, MAX_GOLD)
		data.Currency.Gems = math.clamp(data.Currency.Gems or 0, 0, MAX_GEMS)
	end
end

----------------------------------------------------------------
-- Stats制限＋BestTime妥当性
----------------------------------------------------------------
local function sanitizeStats(data)
	if not data.Stats then return end

	for _, difficultyData in pairs(data.Stats) do

		-- Wins / Plays 制限
		difficultyData.Wins = math.clamp(difficultyData.Wins or 0, 0, MAX_WINS)
		difficultyData.Plays = math.clamp(difficultyData.Plays or 0, 0, MAX_PLAYS)

		-- BestTime 妥当性チェック
		local bestTime = difficultyData.BestTime

		if bestTime ~= nil then
			if type(bestTime) ~= "number" then
				difficultyData.BestTime = nil
			elseif bestTime ~= bestTime then -- NaN
				difficultyData.BestTime = nil
			elseif bestTime < MIN_BEST_TIME or bestTime > MAX_BEST_TIME then
				difficultyData.BestTime = nil
			end
		end
	end
end

----------------------------------------------------------------
-- Apply Game Logic Rules
----------------------------------------------------------------
function DataManager:_applyGameRules(data)

	-- 余分キー削除
	removeExtraKeys(data, DefaultData)

	-- Inventory制限
	sanitizeInventory(data)

	-- Currency制限
	clampCurrency(data)

	-- Stats制限
	sanitizeStats(data)

	return data
end


--------------------------------------------------
-- プレイヤーからの保存要求
--------------------------------------------------
local function performSave(self, player)

	if IsSaving[player] then
		return
	end

	local userId = player.UserId
	local key = "Player_" .. userId
	local data = SessionData[player]

	if not data then
		return
	end

	IsSaving[player] = true

	local success, err = pcall(function()
		playerStore:UpdateAsync(key, function(oldData)
			return data
		end)
	end)

	if not success then
		warn("[DataManager] Save failed:", err)
	else
		LastSaveTime[player] = os.clock()
	end

	IsSaving[player] = false
end

--------------------------------------------------
-- キュー監視ループ
--------------------------------------------------
function DataManager:_startSaveLoop()

	task.spawn(function()
		while true do
			for player in pairs(SaveQueue) do
				
				local lastTime = LastSaveTime[player] or 0
				local now = os.clock()

				if now - lastTime >= SAVE_COOLDOWN then
					performSave(self, player)
					SaveQueue[player] = nil
				end
			end

			task.wait(1)
		end
	end)
end

function DataManager:_onPlayerRemoving(player)

	if not SessionData[player] then
		return
	end

	-- 保存実行（即）
	performSave(self, player)

	-- メモリ解放
	SessionData[player] = nil
	DirtyFlags[player] = nil
	SaveQueue[player] = nil
	LastSaveTime[player] = nil
	IsSaving[player] = nil
end

function DataManager:_bindToClose()

	game:BindToClose(function()

		local players = Players:GetPlayers()

	    for _, player in ipairs(players) do
		    performSave(self, player)
	    end

		-- Robloxは最大30秒待ってくれる
		task.wait(5)
	end)
end

function DataManager:SetDirty(player)
	if SessionData[player] then
		DirtyFlags[player] = true
	end
end

function DataManager:UpdateCurrency(player, amount)
	local data = SessionData[player]
	if not data then return end

	data.Currency.Gold += amount
	DirtyFlags[player] = true
end

--//テスト専用公開
DataManager._deepCopy = deepCopy
DataManager.CURRENT_VERSION = CURRENT_VERSION
DataManager.MAX_RETRIES = MAX_RETRIES


return DataManager