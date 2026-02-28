-- GoalEffectClient (LocalScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GoalEffectEvent = ReplicatedStorage:WaitForChild("GoalEffectEvent")

local function createGoalEffect(position)

	local effectPart = Instance.new("Part")
	effectPart.Size = Vector3.new(1,1,1)
	effectPart.Position = position + Vector3.new(0,2,0)
	effectPart.Anchored = true
	effectPart.CanCollide = false
	effectPart.Transparency = 1
	effectPart.Parent = workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- ã‡êF
	particles.Lifetime = NumberRange.new(0.6, 1)
	particles.Speed = NumberRange.new(25, 35)
	particles.SpreadAngle = Vector2.new(40, 40)
	particles.Acceleration = Vector3.new(0, 40, 0) -- è„è∏
	particles.Rate = 0
	particles.Parent = effectPart

	particles:Emit(120)

	task.delay(1.2, function()
		effectPart:Destroy()
	end)
end

GoalEffectEvent.OnClientEvent:Connect(function(position)
	createGoalEffect(position)
end)