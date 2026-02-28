-- UI構造の組織化
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- メインUIコンテナ
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "GameInterface"
mainGui.Parent = playerGui

-- UIセクション
local scoreFrame = Instance.new("Frame")
scoreFrame.Name = "ScoreDisplay"
scoreFrame.Size = UDim2.new(0, 200, 0, 100)
scoreFrame.Position = UDim2.new(0, 10, 0, 10)
scoreFrame.BackgroundColor3 = Color3.new(0, 0, 0)
scoreFrame.BackgroundTransparency = 0.5
scoreFrame.Parent = mainGui

-- スコア表示
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreText"
scoreLabel.Size = UDim2.new(1, 0, 0.5, 0)
scoreLabel.Position = UDim2.new(0, 0, 0, 0)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "Score: 0"
scoreLabel.TextColor3 = Color3.new(1, 1, 1)
scoreLabel.TextScaled = true
scoreLabel.Font = Enum.Font.SourceSansBold
scoreLabel.Parent = scoreFrame

-- leaderstats.Score を監視して UI を更新
--local leaderstats = player:WaitForChild("leaderstats")
--local scoreValue = leaderstats:WaitForChild("Score")

local function updateScore(newValue)
	scoreLabel.Text = "Score: " .. newValue

end

-- 初期表示
--updateScore(scoreValue.Value)

-- 値が変わったら更新
--scoreValue.Changed:Connect(updateScore)