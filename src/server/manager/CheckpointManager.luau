local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local activeStage = Workspace:WaitForChild("ActiveStage")

--------------------------------------------------
-- ?? リスポーン制御（最重要）
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)

	player.CharacterAdded:Connect(function(character)

		local savedCFrame = player:GetAttribute("CheckpointCFrame")
		if savedCFrame then

			local root = character:WaitForChild("HumanoidRootPart")

			-- デフォルトスポーン後にワープ
			task.defer(function()
				root.CFrame = savedCFrame
			end)
		end
	end)
end)

--------------------------------------------------
-- チェックポイント設定
--------------------------------------------------

local function setupCheckpoint(checkpointPart)

	checkpointPart.Touched:Connect(function(hit)

		print("Touched:", hit.Name)

		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			print("player 取得失敗")
			return
		end

		print("player OK")

		local checkpointID = checkpointPart:GetAttribute("CheckpointID")
		print("checkpointID:", checkpointID)

		if not checkpointID then
			print("IDなし")
			return
		end

		if player:GetAttribute("LastCheckpointID") == checkpointID then
			print("すでに保存済み")
			return
		end

		print("保存処理へ")

		local forward = -checkpointPart.CFrame.LookVector
		local position = checkpointPart.Position + Vector3.new(0, 4, 0)
		local fixedCFrame = CFrame.new(position, position + forward)

		player:SetAttribute("CheckpointCFrame", fixedCFrame)
		player:SetAttribute("LastCheckpointID", checkpointID)

		print(player.Name .. " のチェックポイント保存")

		-- ?? 追加
		checkpointPart.CanTouch = false

		task.delay(1, function()
			checkpointPart.CanTouch = true
		end)
	end)
end

--------------------------------------------------
-- 既存チェックポイント登録
--------------------------------------------------

for _, obj in ipairs(activeStage:GetDescendants()) do
	if obj:IsA("Part") and obj.Name == "CheckpointPart" then
		setupCheckpoint(obj)
	end
end

--------------------------------------------------
-- 生成時対応
--------------------------------------------------

activeStage.DescendantAdded:Connect(function(obj)
	if obj:IsA("Part") and obj.Name == "CheckpointPart" then
		setupCheckpoint(obj)
	end
end)