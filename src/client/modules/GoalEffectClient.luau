--==================================================
-- GoalEffectClient
-- クライアント専用ゴール演出処理
--==================================================

-- サービス取得
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService") -- 今後の拡張用
local Debris = game:GetService("Debris")
local SharedFolder = ReplicatedStorage:WaitForChild("shared")
local RemotesFolder = SharedFolder:WaitForChild("Remotes")

-- サーバーから発火されるRemoteEvent
local GoalEffectEvent = RemotesFolder:WaitForChild("GoalEffectEvent")


--==================================================
-- ゴール演出生成関数
--==================================================

local function createGoalEffect(position)

	-- 不正データ対策（重要）
	if typeof(position) ~= "Vector3" then
		warn("GoalEffectClient: invalid position received")
		return
	end

	-- エフェクト用の透明パーツ（Particleの親）
	local effectPart = Instance.new("Part")
	effectPart.Name = "GoalEffectPart"
	effectPart.Size = Vector3.new(1, 1, 1)

	-- 少し上に表示（地面埋まり防止）
	effectPart.Position = position + Vector3.new(0, 2, 0)

	effectPart.Anchored = true
	effectPart.CanCollide = false
	effectPart.CanQuery = false
	effectPart.CanTouch = false
	effectPart.Transparency = 1
	effectPart.Parent = workspace

	--==================================================
	-- パーティクル設定
	--==================================================

	local particles = Instance.new("ParticleEmitter")

	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"

	-- サイズ変化（大→小）
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0)
	})

	-- 金色（ゴール演出）
	particles.Color = ColorSequence.new(
		Color3.fromRGB(255, 215, 0) -- ゴールド色
	)

	-- 生存時間
	particles.Lifetime = NumberRange.new(0.6, 1)

	-- 放出速度
	particles.Speed = NumberRange.new(25, 35)

	-- 拡散角度
	particles.SpreadAngle = Vector2.new(40, 40)

	-- 上昇加速（ふわっと上へ）
	particles.Acceleration = Vector3.new(0, 40, 0)

	-- 常時発生させない
	particles.Rate = 0

	particles.Parent = effectPart

	-- 一瞬だけ大量放出
	particles:Emit(120)

	-- Debrisで自動削除（安全）
	Debris:AddItem(effectPart, 1.5)
end


--==================================================
-- RemoteEvent受信
--==================================================

GoalEffectEvent.OnClientEvent:Connect(function(position)
	createGoalEffect(position)
end)