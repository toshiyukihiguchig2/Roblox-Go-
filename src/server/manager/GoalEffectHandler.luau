-- GoalEffectHandler.lua
-- ActiveStage内のGoalTriggerを監視してエフェクトを生成する

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local stageFolder = Workspace:FindFirstChild("ActiveStage")
local GoalEffectEvent = ReplicatedStorage:WaitForChild("GoalEffectEvent")

if not stageFolder then
	warn("ActiveStageが見つかりません")
	return
end

-- デバウンス管理
local debounce = {}

-- GoalTriggerのTouchedイベントを設定する関数
local function setupGoalTrigger(goalTrigger)
	if not goalTrigger:IsA("BasePart") or goalTrigger.Name ~= "GoalTrigger" then
		return
	end

	print("[GoalEffectHandler] GoalTriggerを設定しました: " .. goalTrigger:GetFullName())

	goalTrigger.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		-- 二重発火防止
		if debounce[player] then return end
		debounce[player] = true

		print(player.Name .. " がゴールしました！")

		-- エフェクトを生成
		print("Effect位置:", goalTrigger.position)
		GoalEffectEvent:FireClient(player, goalTrigger.Position)

		-- トリガーを消滅させる
		goalTrigger.Transparency = 1
		goalTrigger.CanTouch = false

		-- トリガーを削除
		task.wait(0.5)
		goalTrigger:Destroy()
		print("[GoalEffectHandler] GoalTriggerを削除しました")

		task.wait(1)
		debounce[player] = nil
	end)
end

-- 既存のGoalTriggerを設定
local function setupExistingGoalTriggers()
	for _, descendant in stageFolder:GetDescendants() do
		setupGoalTrigger(descendant)
	end
end

-- 新しく追加されたGoalTriggerを監視
stageFolder.DescendantAdded:Connect(function(descendant)
	setupGoalTrigger(descendant)
end)

-- 初期設定
setupExistingGoalTriggers()
print("[GoalEffectHandler] 初期化完了")