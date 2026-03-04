--==================================================
-- CheckpointManager (ModuleScript)
-- サーバー側チェックポイント管理（セッション内のみ有効）
--
-- ［仕様］
--   CheckpointPart（CheckpointID 属性付き）に HumanoidRootPart が触れると
--   サーバー側テーブルにリスポーン CFrame を記録する。
--   CharacterAdded 時にその CFrame へ移動させてリスポーン地点を実現する。
--
-- ［注意］
--   Roblox の SetAttribute は CFrame 型を未対応のため、
--   サーバー側テーブル (_checkpoints) で管理する。
--==================================================

local Players = game:GetService("Players")

local CheckpointManager = {}
CheckpointManager.__index = CheckpointManager

--------------------------------------------------
-- コンストラクタ
--------------------------------------------------

function CheckpointManager.new(activeStage)
	local self = setmetatable({}, CheckpointManager)

	self.ActiveStage   = activeStage
	self._checkpoints  = {}  -- [userId] = { id = CheckpointID, cf = CFrame }

	self:_setupStage()
	self:_connectPlayers()

	return self
end

--------------------------------------------------
-- プレイヤー接続
-- CharacterAdded 時にチェックポイントへ復元
--------------------------------------------------

function CheckpointManager:_connectPlayers()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:_restoreCheckpoint(player, character)
		end)
	end)

	-- 既に参加済みのプレイヤー対応
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			self:_restoreCheckpoint(player, character)
		end)
	end

	-- プレイヤー退出時にデータ削除
	Players.PlayerRemoving:Connect(function(player)
		self._checkpoints[player.UserId] = nil
	end)
end

--------------------------------------------------
-- チェックポイント復元（リスポーン時）
--------------------------------------------------

function CheckpointManager:_restoreCheckpoint(player, character)
	local data = self._checkpoints[player.UserId]
	if not data then return end

	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	-- 物理演算の確定を待ってから移動
	task.defer(function()
		root.CFrame = data.cf
	end)
end

--------------------------------------------------
-- チェックポイント登録
--------------------------------------------------

function CheckpointManager:_setupCheckpoint(part)
	if part:GetAttribute("Initialized") then return end
	part:SetAttribute("Initialized", true)

	part.Touched:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local checkpointID = part:GetAttribute("CheckpointID")
		if not checkpointID then return end

		-- 既に同じチェックポイントを通過済みならスキップ
		local existing = self._checkpoints[player.UserId]
		if existing and existing.id == checkpointID then return end

		-- リスポーン CFrame を計算（進行方向を向く・少し上に）
		local forward  = -part.CFrame.LookVector
		local position = part.Position + Vector3.new(0, 4, 0)
		local fixedCFrame = CFrame.new(position, position + forward)

		self._checkpoints[player.UserId] = { id = checkpointID, cf = fixedCFrame }

		print(string.format("[CheckpointManager] %s: checkpoint %d 更新", player.Name, checkpointID))

		-- デバウンス（1秒間タッチ無効）
		part.CanTouch = false
		task.delay(1, function()
			if part.Parent then
				part.CanTouch = true
			end
		end)
	end)
end

--------------------------------------------------
-- ステージ内の CheckpointPart を全登録
-- DescendantAdded で StageGenerator の動的生成にも対応
--------------------------------------------------

function CheckpointManager:_setupStage()
	for _, obj in ipairs(self.ActiveStage:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "CheckpointPart" then
			self:_setupCheckpoint(obj)
		end
	end

	self.ActiveStage.DescendantAdded:Connect(function(obj)
		if obj:IsA("BasePart") and obj.Name == "CheckpointPart" then
			self:_setupCheckpoint(obj)
		end
	end)
end

return CheckpointManager
