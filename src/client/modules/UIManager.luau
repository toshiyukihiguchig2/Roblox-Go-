--==================================================
-- クライアント用 UI 初期化スクリプト
-- ※ StarterPlayerScripts に配置する LocalScript
--==================================================

-- サービス取得
local Players = game:GetService("Players")

-- ローカルプレイヤー取得（LocalScript専用）
local player = Players.LocalPlayer

-- PlayerGui が生成されるまで待機（非同期対策）
local playerGui = player:WaitForChild("PlayerGui")


--==================================================
-- メインUIコンテナ作成
--==================================================

local mainGui = Instance.new("ScreenGui")
mainGui.Name = "GameInterface"

-- リスポーン時にUIを保持するかどうか
-- trueにするとリスポーンで消えない
mainGui.ResetOnSpawn = false

mainGui.Parent = playerGui


--==================================================
-- スコア表示フレーム
--==================================================

local scoreFrame = Instance.new("Frame")
scoreFrame.Name = "ScoreDisplay"
scoreFrame.Size = UDim2.new(0, 200, 0, 100)
scoreFrame.Position = UDim2.new(0, 10, 0, 10)

-- 半透明の黒背景
scoreFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scoreFrame.BackgroundTransparency = 0.5

scoreFrame.Parent = mainGui


--==================================================
-- スコアテキスト表示
--==================================================

local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreText"
scoreLabel.Size = UDim2.new(1, 0, 0.5, 0)
scoreLabel.Position = UDim2.new(0, 0, 0, 0)

-- 背景を透明にしてフレーム背景を見せる
scoreLabel.BackgroundTransparency = 1

scoreLabel.Text = "Score: 0"
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

-- 画面サイズに応じて自動スケール
scoreLabel.TextScaled = true

-- 可読性の高い太字フォント
scoreLabel.Font = Enum.Font.SourceSansBold

scoreLabel.Parent = scoreFrame


--==================================================
-- スコア更新処理
--==================================================

-- UI更新関数
-- 外部から値を渡してUIを書き換える設計
local function updateScore(newValue)
	-- 数値以外が来た場合の安全対策
	if typeof(newValue) ~= "number" then
		warn("updateScore: newValue is not a number")
		return
	end

	scoreLabel.Text = "Score: " .. tostring(newValue)
end


--==================================================
-- leaderstats 連動（サーバー管理スコア）
--==================================================

-- ▼ 本番ではスコアは必ずサーバー側で管理すること
-- ▼ クライアントだけでスコア管理するとチート可能

local function connectLeaderstats()

	-- leaderstats生成待機（タイムアウト保護）
	local leaderstats = player:WaitForChild("leaderstats", 5)
	if not leaderstats then
		warn("leaderstats not found")
		return
	end

	local scoreValue = leaderstats:WaitForChild("Score", 5)
	if not scoreValue then
		warn("Score value not found")
		return
	end

	-- 初期値反映
	updateScore(scoreValue.Value)

	-- 値変更時に自動更新
	scoreValue.Changed:Connect(function(newValue)
		updateScore(newValue)
	end)
end

-- pcallで安全に実行
local success, err = pcall(connectLeaderstats)
if not success then
	warn("Failed to connect leaderstats:", err)
end