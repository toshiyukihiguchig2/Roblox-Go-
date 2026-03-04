--==================================================
-- RankingManager.luau
-- OrderedDataStore によるグローバルランキング管理（仕様書 §8）
--
-- ［仕様§8.1］ OrderedDataStore 使用
-- ［仕様§8.2］ BestTime 更新時のみ書き込み
-- ［仕様§8.3］ 難易度別 TOP50 取得
--
-- ［スコア保存方針］
--   BestTime は「小さいほど良い」タイムのため、
--   OrderedDataStore（降順ソート）に対して
--   スコア = SCORE_BASE - elapsedTime（整数化）で保存する。
--   取得時に SCORE_BASE から引き戻して実タイムに変換する。
--==================================================
local RankingManager = {}
RankingManager.__index = RankingManager

--// Services
local DataStoreService = game:GetService("DataStoreService")

--// Constants
local SCORE_BASE        = 1_000_000  -- タイムの符号反転基準値（秒単位で最大16666分相当）
local SCORE_MULTIPLIER  = 1000       -- ミリ秒精度で保存（小数3桁）
local VALID_DIFFICULTIES = { Easy = true, Normal = true, Hard = true }

--==================================================
-- コンストラクタ
--==================================================
function RankingManager.new()
	local self = setmetatable({}, RankingManager)

	-- 難易度別 OrderedDataStore（仕様§8.1）
	self._stores = {
		Easy   = DataStoreService:GetOrderedDataStore("Ranking_Easy_v1"),
		Normal = DataStoreService:GetOrderedDataStore("Ranking_Normal_v1"),
		Hard   = DataStoreService:GetOrderedDataStore("Ranking_Hard_v1"),
	}

	return self
end

--==================================================
-- BestTime をランキングに登録（仕様§8.2）
-- ※BestTime が更新された場合のみ呼び出す（GoalManager 側で判定）
-- @param userId     number
-- @param difficulty "Easy" | "Normal" | "Hard"
-- @param elapsedTime number（秒、小数あり）
--==================================================
function RankingManager:Submit(userId, difficulty, elapsedTime)
	if not VALID_DIFFICULTIES[difficulty] then
		warn("[RankingManager] Invalid difficulty:", difficulty)
		return
	end

	local store = self._stores[difficulty]
	local key   = tostring(userId)

	-- タイムを整数スコアに変換（小さいタイム = 大きいスコア）
	local score = SCORE_BASE - math.floor(elapsedTime * SCORE_MULTIPLIER)
	if score < 0 then
		warn("[RankingManager] elapsedTime too large to rank:", elapsedTime)
		return
	end

	local success, err = pcall(function()
		store:SetAsync(key, score)
	end)

	if not success then
		warn("[RankingManager] Submit failed:", err)
	else
		print(string.format(
			"[RankingManager] Submitted userId=%s difficulty=%s time=%.3fs score=%d",
			key, difficulty, elapsedTime, score
		))
	end
end

--==================================================
-- TOP N ランキング取得（仕様§8.3 TOP50）
-- @param difficulty "Easy" | "Normal" | "Hard"
-- @param count      取得件数（デフォルト 50）
-- @return entries   { {rank, userId, time}, ... }
--==================================================
function RankingManager:GetTop(difficulty, count)
	count = count or 50

	if not VALID_DIFFICULTIES[difficulty] then
		warn("[RankingManager] Invalid difficulty:", difficulty)
		return {}
	end

	local store = self._stores[difficulty]
	local entries = {}

	local success, pages = pcall(function()
		return store:GetSortedAsync(
			false,  -- descending（スコア降順 = タイム昇順）
			count
		)
	end)

	if not success then
		warn("[RankingManager] GetTop failed:", pages)
		return {}
	end

	local rank = 1
	local success2, err2 = pcall(function()
		local page = pages:GetCurrentPage()
		for _, entry in ipairs(page) do
			local rawTime = (SCORE_BASE - entry.value) / SCORE_MULTIPLIER
			table.insert(entries, {
				rank   = rank,
				userId = tonumber(entry.key),
				time   = rawTime,
			})
			rank += 1
		end
	end)

	if not success2 then
		warn("[RankingManager] Page read failed:", err2)
	end

	return entries
end

return RankingManager
