--==================================================
-- GoalEffectManager (ModuleScript)
-- ゴール到達時のクライアント演出通知専用
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedFolder = ReplicatedStorage:WaitForChild("shared")
local RemotesFolder = SharedFolder:WaitForChild("Remotes")

local GoalEffectManager = {}
GoalEffectManager.__index = GoalEffectManager

--------------------------------------------------
-- コンストラクタ
--------------------------------------------------

function GoalEffectManager.new(activeStage)

	local self = setmetatable({}, GoalEffectManager)

	self.ActiveStage = activeStage
	self.GoalEffectEvent = RemotesFolder:WaitForChild("GoalEffectEvent")

	self._debounce = {}

	self:_setupStage()
	self:_connectCleanup()

	return self
end

--------------------------------------------------
-- プレイヤー削除時のクリーンアップ
--------------------------------------------------

function GoalEffectManager:_connectCleanup()

	Players.PlayerRemoving:Connect(function(player)
		self._debounce[player] = nil
	end)
end

--------------------------------------------------
-- GoalTrigger設定
--------------------------------------------------

function GoalEffectManager:_setupGoalTrigger(goalTrigger)

	-- 二重初期化防止
	if goalTrigger:GetAttribute("EffectInitialized") then
		return
	end
	goalTrigger:SetAttribute("EffectInitialized", true)

	goalTrigger.Touched:Connect(function(hit)

		-- RootPart限定（多重発火防止）
		if hit.Name ~= "HumanoidRootPart" then
			return
		end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		-- プレイヤー単位デバウンス
		if self._debounce[player] then
			return
		end
		self._debounce[player] = true

		print("[GoalEffectManager] Effect fired for:", player.Name)

		--------------------------------------------------
		-- クライアントへ演出通知
		--------------------------------------------------

		self.GoalEffectEvent:FireClient(player, goalTrigger.Position)

		--------------------------------------------------
		-- Trigger一時無効化（スパム防止）
		--------------------------------------------------

		goalTrigger.CanTouch = false
		goalTrigger.Transparency = 1

		task.delay(0.5, function()
			if goalTrigger and goalTrigger.Parent then
				goalTrigger:Destroy()
			end
		end)

		-- デバウンス解除
		task.delay(1, function()
			self._debounce[player] = nil
		end)
	end)
end

--------------------------------------------------
-- ステージ内監視
--------------------------------------------------

function GoalEffectManager:_setupStage()

	for _, obj in ipairs(self.ActiveStage:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "GoalTrigger" then
			self:_setupGoalTrigger(obj)
		end
	end

	self.ActiveStage.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") and obj.Name == "GoalTrigger" then
			self:_setupGoalTrigger(obj)
		end
	end)
end

return GoalEffectManager