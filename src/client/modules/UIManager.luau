--==================================================
-- UIManager.luau
-- クライアント UI 管理
--   ・左上 Gold 表示（leaderstats.Gold 連動）
--   ・ゴール結果画面（GoalReachedEvent 受信）
--==================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes   = ReplicatedStorage:WaitForChild("shared"):WaitForChild("Remotes")
local GoalReachedEvent = SharedRemotes:WaitForChild("GoalReached")

--==================================================
-- メインUIコンテナ
--==================================================

local mainGui = Instance.new("ScreenGui")
mainGui.Name         = "GameInterface"
mainGui.ResetOnSpawn = false
mainGui.Parent       = playerGui

--==================================================
-- 左上 Gold 表示
--==================================================

local goldFrame = Instance.new("Frame")
goldFrame.Name                  = "GoldDisplay"
goldFrame.Size                  = UDim2.new(0, 180, 0, 50)
goldFrame.Position               = UDim2.new(0, 10, 0, 10)
goldFrame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
goldFrame.BackgroundTransparency = 0.5
goldFrame.Parent                 = mainGui

local goldLabel = Instance.new("TextLabel")
goldLabel.Name                  = "GoldText"
goldLabel.Size                  = UDim2.new(1, 0, 1, 0)
goldLabel.BackgroundTransparency = 1
goldLabel.Text                  = "Gold: 0"
goldLabel.TextColor3            = Color3.fromRGB(255, 215, 0)
goldLabel.TextScaled            = true
goldLabel.Font                  = Enum.Font.SourceSansBold
goldLabel.Parent                = goldFrame

--==================================================
-- leaderstats.Gold 連動
--==================================================

local function connectLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		warn("[UIManager] leaderstats not found")
		return
	end

	local goldValue = leaderstats:WaitForChild("Gold", 5)
	if not goldValue then
		warn("[UIManager] Gold value not found")
		return
	end

	goldLabel.Text = "Gold: " .. tostring(goldValue.Value)

	goldValue.Changed:Connect(function(newValue)
		goldLabel.Text = "Gold: " .. tostring(newValue)
	end)
end

local ok, err = pcall(connectLeaderstats)
if not ok then
	warn("[UIManager] leaderstats connect failed:", err)
end

--==================================================
-- ゴール結果フレーム（画面中央、平常時は非表示）
--==================================================

local resultFrame = Instance.new("Frame")
resultFrame.Name                  = "GoalResult"
resultFrame.Size                  = UDim2.new(0, 400, 0, 180)
resultFrame.Position               = UDim2.new(0.5, -200, 0.5, -90)
resultFrame.BackgroundColor3       = Color3.fromRGB(20, 20, 20)
resultFrame.BackgroundTransparency = 0.2
resultFrame.Visible                = false
resultFrame.Parent                 = mainGui

-- "GOAL!" タイトル
local goalTitle = Instance.new("TextLabel")
goalTitle.Name                  = "Title"
goalTitle.Size                  = UDim2.new(1, 0, 0.3, 0)
goalTitle.Position               = UDim2.new(0, 0, 0, 0)
goalTitle.BackgroundTransparency = 1
goalTitle.Text                  = "GOAL!"
goalTitle.TextColor3            = Color3.fromRGB(255, 215, 0)
goalTitle.TextScaled            = true
goalTitle.Font                  = Enum.Font.GothamBold
goalTitle.Parent                = resultFrame

-- タイム表示
local timeLabel = Instance.new("TextLabel")
timeLabel.Name                  = "TimeText"
timeLabel.Size                  = UDim2.new(1, 0, 0.3, 0)
timeLabel.Position               = UDim2.new(0, 0, 0.33, 0)
timeLabel.BackgroundTransparency = 1
timeLabel.Text                  = "Time: --"
timeLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
timeLabel.TextScaled            = true
timeLabel.Font                  = Enum.Font.SourceSansBold
timeLabel.Parent                = resultFrame

-- 順位 / Gold 表示
local rewardLabel = Instance.new("TextLabel")
rewardLabel.Name                  = "RewardText"
rewardLabel.Size                  = UDim2.new(1, 0, 0.3, 0)
rewardLabel.Position               = UDim2.new(0, 0, 0.66, 0)
rewardLabel.BackgroundTransparency = 1
rewardLabel.Text                  = "Rank: #-  Gold: +0"
rewardLabel.TextColor3            = Color3.fromRGB(200, 200, 200)
rewardLabel.TextScaled            = true
rewardLabel.Font                  = Enum.Font.SourceSans
rewardLabel.Parent                = resultFrame

--==================================================
-- ゴール結果表示（5秒後にフェードアウト）
--==================================================

local function showGoalResult(data)
	-- タイム文字列（ミリ秒3桁）
	local timeStr = string.format("%.3f s", data.time)
	if data.isNewBest then
		timeStr = timeStr .. "  ★ NEW BEST"
		timeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	else
		timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	timeLabel.Text   = "Time: " .. timeStr
	rewardLabel.Text = string.format("Rank: #%d  Gold: +%d", data.rank, data.gold)

	-- 表示
	resultFrame.BackgroundTransparency = 0.2
	resultFrame.Visible = true

	-- 4秒後にフェードアウト
	task.delay(4, function()
		local tween = TweenService:Create(
			resultFrame,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Once(function()
			resultFrame.Visible = false
		end)
	end)
end

--==================================================
-- GoalReachedEvent 受信
--==================================================

GoalReachedEvent.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	showGoalResult(data)
end)
