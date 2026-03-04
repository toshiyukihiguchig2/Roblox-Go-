--==================================================
-- TeleportHandler.luau
-- 難易度検証・不正プレイヤーをロビーへリダイレクト（仕様書 §3.1, §4）
--
-- ［仕様§4.2 TeleportData仕様］
--   { Difficulty = "Easy" | "Normal" | "Hard" }
--
-- ［仕様§4.3 サーバー側検証］
--   ・文字列ホワイトリスト照合
--   ・nil の場合 → 初期ロビーへ送還
--   ・改ざん検知 → 接続拒否ではなくロビーへリダイレクト（UX重視）
--
-- ［セキュリティ§4.3 理由］
--   クライアントは信頼しない。TeleportData は必ずサーバーで検証。
--==================================================
local TeleportHandler = {}
TeleportHandler.__index = TeleportHandler

--// Services
local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")

--// Constants（仕様§4.3 ホワイトリスト）
local Constants = require(ReplicatedStorage:WaitForChild("shared"):WaitForChild("Constants"))
local VALID_DIFFICULTIES = Constants.VALID_DIFFICULTIES  -- { Easy=true, Normal=true, Hard=true }
local LOBBY_PLACE_ID     = Constants.LOBBY_PLACE_ID      -- 仮ID: 0（後で差し替え要）

--// リダイレクト待機時間（プレイヤーが完全に参加してから処理）
local JOIN_GRACE_PERIOD = 2.0  -- 秒

--==================================================
-- コンストラクタ
-- @param serverDifficulty このサーバーの難易度（"Easy" | "Normal" | "Hard"）
--==================================================
function TeleportHandler.new(serverDifficulty)
	local self = setmetatable({}, TeleportHandler)
	self._serverDifficulty = serverDifficulty
	self._connections      = {}
	return self
end

--==================================================
-- 初期化（Bootstrap から呼ぶ）
--==================================================
function TeleportHandler:Init()
	local conn = Players.PlayerAdded:Connect(function(player)
		-- CharacterAdded を待ってからリダイレクト（UX: ロード後に転送）
		task.delay(JOIN_GRACE_PERIOD, function()
			if player.Parent then  -- まだ接続中か確認
				self:_validate(player)
			end
		end)
	end)

	table.insert(self._connections, conn)
	print("[TeleportHandler] Init - serverDifficulty:", self._serverDifficulty)
end

--==================================================
-- TeleportData を検証し、不正なら送還（仕様§4.3）
--==================================================
function TeleportHandler:_validate(player)
	-- Studio 実行時は TeleportData が存在しないためスキップ
	if RunService:IsStudio() then
		return
	end

	-- サーバー側で JoinData を取得
	-- GetJoinData().TeleportData は client から送られた TeleportData
	local joinData    = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	local difficulty   = teleportData and teleportData.Difficulty

	-- ① ホワイトリスト照合（仕様§4.3）
	local isValidDifficulty = type(difficulty) == "string"
		and VALID_DIFFICULTIES[difficulty] == true

	-- ② サーバー難易度と一致するか
	local isCorrectServer = (difficulty == self._serverDifficulty)

	if isValidDifficulty and isCorrectServer then
		-- 正常：何もしない
		return
	end

	-- ③ 不正検知 → ロビーへリダイレクト（UX重視、接続拒否しない）
	warn(string.format(
		"[TeleportHandler] Invalid TeleportData for %s: difficulty=%s expected=%s -> redirecting to lobby",
		player.Name,
		tostring(difficulty),
		self._serverDifficulty
	))

	if LOBBY_PLACE_ID == 0 then
		-- 開発環境（LOBBY_PLACE_ID 未設定）はキックで代用
		player:Kick("難易度設定が正しくありません。ロビーから再度参加してください。")
		return
	end

	local success, err = pcall(function()
		TeleportService:Teleport(LOBBY_PLACE_ID, player)
	end)

	if not success then
		warn("[TeleportHandler] Teleport failed:", err)
		player:Kick("難易度設定エラー。ロビーから再接続してください。")
	end
end

--==================================================
-- クリーンアップ
--==================================================
function TeleportHandler:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
end

return TeleportHandler
