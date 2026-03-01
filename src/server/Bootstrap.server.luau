--==================================================
-- Bootstrap.server.luau
-- サーバー初期化管理
--==================================================

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- フォルダ取得
--------------------------------------------------

local ManagersFolder = script.Parent:WaitForChild("Managers")

local ActiveStage = Workspace:WaitForChild("ActiveStage")
local StageModels = ReplicatedStorage:WaitForChild("StageModels")
local EasyFolder = StageModels:WaitForChild("Easy")
local SharedFolder = ReplicatedStorage:WaitForChild("shared")

--------------------------------------------------
-- ModuleScript 読み込み
--------------------------------------------------

local CheckpointManager   = require(ManagersFolder:WaitForChild("CheckpointManager"))
local GoalManager         = require(ManagersFolder:WaitForChild("GoalManager"))
local GoalEffectManager   = require(ManagersFolder:WaitForChild("GoalEffectManager"))
local RunManager          = require(ManagersFolder:WaitForChild("RunManager"))
local StageGenerator      = require(ManagersFolder:WaitForChild("StageGenerator"))
local BGMManager          = require(ManagersFolder:WaitForChild("BGMManager"))

--------------------------------------------------
-- インスタンス生成
--------------------------------------------------

-- タイム管理
local runManager = RunManager.new()

-- ステージ生成
local stageGenerator = StageGenerator.new(ActiveStage, EasyFolder)
stageGenerator:Generate()

-- 各種マネージャー初期化
local checkpointManager = CheckpointManager.new(ActiveStage)
-- local goalManager       = GoalManager.new(ActiveStage)
local goalEffectManager = GoalEffectManager.new(ActiveStage)

print("All Managers initialized")