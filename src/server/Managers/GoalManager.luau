--==================================================
-- GoalManager.luau
-- ゴール判定・順位記録・報酬付与（仕様書 §3.1, §6.3, §10）
--
-- ［責務］
--   ・ GoalTrigger の Touched 検出（サーバー側主権、仕様§10）
--   ・ RunManager:FinishRun で経過時間取得
--   ・ DataManager:RecordRun で Stats 永続化
--   ・ 到達順を server-side スタックで記録（仕様§6.3）
--   ・ RewardService:AwardReward で報酬付与（仕様§6）
--   ・ RankingManager:Submit で OrderedDataStore 更新（仕様§8.2）
--   ・ GoalReached RemoteEvent でクライアント通知
--   ・ GoalEffectEvent でゴール演出トリガー（仕様§3.1 GoalManager）
--==================================================
local GoalManager = {}
GoalManager.__index = GoalManager

--// Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Remotes
local SharedRemotes   = ReplicatedStorage:WaitForChild("shared"):WaitForChild("Remotes")
local GoalReachedEvent = SharedRemotes:WaitForChild("GoalReached")
local GoalEffectEvent  = SharedRemotes:WaitForChild("GoalEffectEvent")

--// Constants
local DEBOUNCE_COOLDOWN = 1.0  -- 同プレイヤーの二重ゴール防止（秒）

--==================================================
-- コンストラクタ
-- @param activeStage  Workspace の ActiveStage フォルダ
-- @param deps テーブル
--   .runManager     RunManager インスタンス
--   .dataManager    DataManager インスタンス
--   .rewardService  RewardService インスタンス
--   .rankingManager RankingManager インスタンス
--   .difficulty     "Easy" | "Normal" | "Hard"
--==================================================
function GoalManager.new(activeStage, deps)
	local self = setmetatable({}, GoalManager)

	self._activeStage    = activeStage
	self._runManager     = deps.runManager
	self._dataManager    = deps.dataManager
	self._rewardService  = deps.rewardService
	self._rankingManager = deps.rankingManager
	self._difficulty     = deps.difficulty

	-- 到達順スタック（仕様§6.3）
	self._finishOrder = {}   -- { [userId] = rank }
	self._finishCount = 0

	-- デバウンス管理（仕様§10 ゴール判定）
	self._debounce = {}      -- { [userId] = lastTouchTime }

	-- 登録済み接続を管理（クリーンアップ用）
	self._connections = {}

	return self
end

--==================================================
-- 初期化
-- ※ Bootstrap から呼ぶ
--==================================================
function GoalManager:Init()
	self:_setupStage()
	self:_connectCleanup()
	print("[GoalManager] Init - difficulty:", self._difficulty)
end

--==================================================
-- ステージ内の GoalTrigger を監視
--==================================================
function GoalManager:_setupStage()
	for _, descendant in ipairs(self._activeStage:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "GoalTrigger" then
				self:_setupGoalTrigger(descendant)
			elseif descendant.Name == "StartTrigger" then
				self:_setupStartTrigger(descendant)
			end
		end
	end

	-- 動的追加に対応（StageGenerator:Generate() 後に追加されるケース）
	local conn = self._activeStage.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			if descendant.Name == "GoalTrigger" then
				self:_setupGoalTrigger(descendant)
			elseif descendant.Name == "StartTrigger" then
				self:_setupStartTrigger(descendant)
			end
		end
	end)
	table.insert(self._connections, conn)
end

--==================================================
-- StartTrigger タッチ → RunManager:StartRun
--==================================================
function GoalManager:_setupStartTrigger(startTrigger)
	local conn = startTrigger.Touched:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end

		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- 既に走行中なら無視
		if self._runManager:IsRunning(player) then return end

		self._runManager:StartRun(player)
		print("[GoalManager] StartRun:", player.Name)
	end)

	table.insert(self._connections, conn)
end

--==================================================
-- GoalTrigger 1つのタッチイベントを設定
--==================================================
function GoalManager:_setupGoalTrigger(goalTrigger)
	local conn = goalTrigger.Touched:Connect(function(hit)
		-- HumanoidRootPart のみ対象（仕様§10 位置照合）
		if hit.Name ~= "HumanoidRootPart" then
			return
		end

		local character = hit.Parent
		local player    = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local userId = player.UserId
		local now    = os.clock()

		-- デバウンス（二重ゴール防止）
		if self._debounce[userId] and now - self._debounce[userId] < DEBOUNCE_COOLDOWN then
			return
		end
		self._debounce[userId] = now

		-- ランナーとして走行中か確認
		if not self._runManager:IsRunning(player) then
			return
		end

		self:_onPlayerGoal(player, goalTrigger.Position)
	end)

	table.insert(self._connections, conn)
end

--==================================================
-- ゴール到達処理（仕様§6.3 順位保存フロー）
--==================================================
function GoalManager:_onPlayerGoal(player, goalPosition)
	local userId = player.UserId

	-- 既にゴール済みなら無視
	if self._finishOrder[userId] then
		return
	end

	-- ① RunManager からタイムを取得（仕様§5.2 サーバー基準時間）
	local elapsedTime = self._runManager:FinishRun(player)

	if not elapsedTime or elapsedTime <= 0 then
		warn("[GoalManager] Invalid elapsedTime for", player.Name, elapsedTime)
		return
	end

	-- ② 到達順位を記録（仕様§6.3 サーバー側でstack保存）
	self._finishCount += 1
	local rank = self._finishCount
	self._finishOrder[userId] = rank

	-- ③ DataManager で Stats 更新（Wins, Plays, BestTime）
	local isNewBest = self._dataManager:RecordRun(
		player,
		self._difficulty,
		elapsedTime,
		true  -- didWin
	)

	-- ④ RewardService で報酬付与（仕様§6）
	local goldAwarded = self._rewardService:AwardReward(
		player,
		self._difficulty,
		rank
	)

	-- ⑤ BestTime 更新時はランキングに登録（仕様§8.2）
	if isNewBest then
		self._rankingManager:Submit(userId, self._difficulty, elapsedTime)
	end

	-- ⑥ ゴール演出トリガー（GoalEffectClient へ通知）
	pcall(function()
		GoalEffectEvent:FireClient(player, goalPosition)
	end)

	-- ⑦ GoalReached でクライアントに結果通知
	pcall(function()
		GoalReachedEvent:FireClient(player, {
			time       = elapsedTime,
			rank       = rank,
			gold       = goldAwarded,
			isNewBest  = isNewBest,
			difficulty = self._difficulty,
		})
	end)

	print(string.format(
		"[GoalManager] %s Goal! time=%.3fs rank=%d gold=%d newBest=%s",
		player.Name, elapsedTime, rank, goldAwarded, tostring(isNewBest)
	))
end

--==================================================
-- プレイヤー退出時クリーンアップ
--==================================================
function GoalManager:_connectCleanup()
	local conn = Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		self._debounce[userId]    = nil
		self._finishOrder[userId] = nil
	end)
	table.insert(self._connections, conn)
end

--==================================================
-- レース終了（次ラウンド用にリセット）
--==================================================
function GoalManager:Reset()
	self._finishOrder = {}
	self._finishCount = 0
	self._debounce    = {}
	print("[GoalManager] Reset")
end

return GoalManager
