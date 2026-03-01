--==================================================
-- RunManager (ModuleScript)
-- プレイヤー走行タイム + ベストタイム保存管理（安全対策版）
--==================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local RunManager = {}
RunManager.__index = RunManager

--------------------------------------------------
-- DataStore設定
--------------------------------------------------

local RunDataStore = DataStoreService:GetDataStore("RunBestTimes_v1")

--------------------------------------------------
-- 異常値対策設定
--------------------------------------------------

local MIN_VALID_TIME = 0.5        -- これ未満は無効（チート対策）
local MAX_VALID_TIME = 60 * 30    -- 30分以上は無効（放置対策）

--------------------------------------------------
-- コンストラクタ
--------------------------------------------------

function RunManager.new()

	local self = setmetatable({}, RunManager)

	self._activeRuns = {} :: {[Player]: number}
	self._bestTimes = {} :: {[Player]: number}

	self:_connectPlayerEvents()

	return self
end

--------------------------------------------------
-- プレイヤーイベント接続
--------------------------------------------------

function RunManager:_connectPlayerEvents()

	Players.PlayerAdded:Connect(function(player)
		self:_loadData(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_saveData(player)
		self._activeRuns[player] = nil
		self._bestTimes[player] = nil
	end)
end

--------------------------------------------------
-- データロード
--------------------------------------------------

function RunManager:_loadData(player: Player)

	local success, data = pcall(function()
		return RunDataStore:GetAsync(player.UserId)
	end)

	if success and type(data) == "number" then
		self._bestTimes[player] = data
	else
		self._bestTimes[player] = math.huge
	end
end

--------------------------------------------------
-- データ保存（UpdateAsync安全版）
--------------------------------------------------

function RunManager:_saveData(player: Player)

	local bestTime = self._bestTimes[player]
	if not bestTime or bestTime == math.huge then
		return
	end

	pcall(function()
		RunDataStore:UpdateAsync(player.UserId, function(oldValue)
			if type(oldValue) ~= "number" then
				return bestTime
			end
			return math.min(oldValue, bestTime)
		end)
	end)

	print("[RunManager] Data saved:", player.Name, bestTime)
end

--------------------------------------------------
-- ラン開始
--------------------------------------------------

function RunManager:StartRun(player: Player)

	if self._activeRuns[player] then
		warn("[RunManager] Start ignored (already running):", player.Name)
		return
	end

	self._activeRuns[player] = os.clock()
end

--------------------------------------------------
-- ラン終了
--------------------------------------------------

function RunManager:FinishRun(player: Player): number?

	local startTime = self._activeRuns[player]
	if not startTime then
		warn("[RunManager] Finish ignored (no start):", player.Name)
		return nil
	end

	local totalTime = os.clock() - startTime
	self._activeRuns[player] = nil

	--------------------------------------------------
	-- 異常値チェック
	--------------------------------------------------

	if totalTime < MIN_VALID_TIME then
		warn("[RunManager] Invalid time (too fast):", player.Name, totalTime)
		return nil
	end

	if totalTime > MAX_VALID_TIME then
		warn("[RunManager] Invalid time (too long):", player.Name, totalTime)
		return nil
	end

	--------------------------------------------------
	-- ベスト更新判定
	--------------------------------------------------

	local currentBest = self._bestTimes[player] or math.huge

	if totalTime < currentBest then
		self._bestTimes[player] = totalTime
		self:_saveData(player)
		print("[RunManager] New best time:", player.Name, totalTime)
	end

	return totalTime
end

--------------------------------------------------
-- ベストタイム取得
--------------------------------------------------

function RunManager:GetBestTime(player: Player): number?
	return self._bestTimes[player]
end

--------------------------------------------------
-- 走行中判定
--------------------------------------------------

function RunManager:IsRunning(player: Player): boolean
	return self._activeRuns[player] ~= nil
end

return RunManager