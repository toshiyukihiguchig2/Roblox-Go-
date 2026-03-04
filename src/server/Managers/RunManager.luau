--==================================================
-- RunManager (ModuleScript)
-- プレイヤー走行タイム計測（BestTime管理はDataManagerが担当）
--==================================================

local Players = game:GetService("Players")

local RunManager = {}
RunManager.__index = RunManager

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

	self:_connectPlayerEvents()

	return self
end

--------------------------------------------------
-- プレイヤー退出時クリーンアップ
--------------------------------------------------

function RunManager:_connectPlayerEvents()

	Players.PlayerRemoving:Connect(function(player)
		self._activeRuns[player] = nil
	end)
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
-- ラン終了（経過時間を返す、BestTime更新はしない）
--------------------------------------------------

function RunManager:FinishRun(player: Player): number?

	local startTime = self._activeRuns[player]
	if not startTime then
		warn("[RunManager] Finish ignored (no start):", player.Name)
		return nil
	end

	local totalTime = os.clock() - startTime
	self._activeRuns[player] = nil

	if totalTime < MIN_VALID_TIME then
		warn("[RunManager] Invalid time (too fast):", player.Name, totalTime)
		return nil
	end

	if totalTime > MAX_VALID_TIME then
		warn("[RunManager] Invalid time (too long):", player.Name, totalTime)
		return nil
	end

	return totalTime
end

--------------------------------------------------
-- 走行中判定
--------------------------------------------------

function RunManager:IsRunning(player: Player): boolean
	return self._activeRuns[player] ~= nil
end

return RunManager
