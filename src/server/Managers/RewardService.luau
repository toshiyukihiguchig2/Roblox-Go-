--==================================================
-- RewardService.luau
-- 難易度倍率×順位補正で報酬を算出・付与（仕様書 §3.1, §6）
--
-- ［報酬計算式（§6.2）］
--   報酬 = 基本値 × 難易度倍率 × 順位補正
--
-- ［難易度倍率（§6.1）］
--   Easy 1.0 / Normal 1.5 / Hard 2.5
--==================================================
local RewardService = {}
RewardService.__index = RewardService

--// Shared
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Constants"))

--// 報酬定数（Constants.luau から参照）
local BASE_GOLD   = Constants.REWARD_BASE_GOLD       -- 100
local MULTIPLIERS = Constants.DIFFICULTY_MULTIPLIERS  -- Easy=1.0, Normal=1.5, Hard=2.5
local RANK_BONUS  = Constants.RANK_BONUS              -- [1]=1.5, [2]=1.2, default=1.0

--==================================================
-- コンストラクタ
-- @param dataManager DataManager インスタンス
--==================================================
function RewardService.new(dataManager)
	local self = setmetatable({}, RewardService)
	self._dataManager = dataManager
	return self
end

--==================================================
-- 報酬付与（仕様§6.2, §6.3）
-- @param player    Player
-- @param difficulty "Easy" | "Normal" | "Hard"
-- @param rank      到達順位（1始まり）
-- @return goldAwarded 付与ゴールド量
--==================================================
function RewardService:AwardReward(player, difficulty, rank)
	local multiplier = MULTIPLIERS[difficulty] or 1.0
	local rankBonus  = RANK_BONUS[rank] or 1.0

	local goldAwarded = math.floor(BASE_GOLD * multiplier * rankBonus)

	-- DataManager 経由で通貨付与（仕様§3.1 DataManager責務）
	self._dataManager:UpdateCurrency(player, "Gold", goldAwarded)
	self._dataManager:RequestSave(player)

	print(string.format(
		"[RewardService] %s awarded %d Gold (difficulty=%s rank=%d)",
		player.Name, goldAwarded, difficulty, rank
	))

	return goldAwarded
end

--==================================================
-- 報酬計算のみ（付与なし・UIプレビュー用）
-- @return goldAmount 計算値
--==================================================
function RewardService:CalcReward(difficulty, rank)
	local multiplier = MULTIPLIERS[difficulty] or 1.0
	local rankBonus  = RANK_BONUS[rank] or 1.0
	return math.floor(BASE_GOLD * multiplier * rankBonus)
end

return RewardService
