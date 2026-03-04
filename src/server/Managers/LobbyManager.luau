--==================================================
-- LobbyManager.luau
-- ロビー待機プレイヤー管理・難易度ゲートタッチ受付
--
-- ［責務］
--   ・参加プレイヤーを _lobbyPlayers で管理
--   ・DifficultyGate（Attribute "Difficulty"）タッチ受付
--   ・難易度別キュー管理（_gateQueues）
--   ・キュー変化を OnQueueChanged コールバックで通知（MatchmakingManager 用）
--   ・プレイヤー退出時のキュー自動クリーンアップ
--
-- ［Workspace 要件］
--   LobbyStage 配下に BasePart "DifficultyGate" を配置し、
--   Attribute "Difficulty" = "Easy" | "Normal" | "Hard" を設定すること。
--==================================================
local LobbyManager = {}
LobbyManager.__index = LobbyManager

--// Services
local Players = game:GetService("Players")

--// Constants
local VALID_DIFFICULTIES = { Easy = true, Normal = true, Hard = true }

--==================================================
-- コンストラクタ
-- @param lobbyStage  Workspace の LobbyStage フォルダ/モデル
--==================================================
function LobbyManager.new(lobbyStage)
	local self = setmetatable({}, LobbyManager)

	self._lobbyStage   = lobbyStage
	self._connections  = {}

	-- ロビー在室プレイヤー { [userId] = Player }
	self._lobbyPlayers = {}

	-- 難易度別待機キュー { [difficulty] = { [userId] = Player } }
	self._gateQueues = {
		Easy   = {},
		Normal = {},
		Hard   = {},
	}

	-- キュー変化コールバック（MatchmakingManager が登録する）
	-- function(difficulty: string, queue: { [userId]: Player })
	self.OnQueueChanged = nil

	return self
end

--==================================================
-- 初期化（LobbyBootstrap から呼ぶ）
--==================================================
function LobbyManager:Init()
	self:_setupGates()

	local c1 = Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	local c2 = Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)
	table.insert(self._connections, c1)
	table.insert(self._connections, c2)

	-- 既参加プレイヤー対応（Studio テスト等）
	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end

	print("[LobbyManager] Init")
end

--==================================================
-- キュー参照（MatchmakingManager 用）
--==================================================
function LobbyManager:GetQueue(difficulty)
	return self._gateQueues[difficulty] or {}
end

--==================================================
-- テレポート後にキューから削除（MatchmakingManager が呼ぶ）
-- @param difficulty string
-- @param players    { Player }
--==================================================
function LobbyManager:RemovePlayersFromQueue(difficulty, players)
	local queue = self._gateQueues[difficulty]
	if not queue then return end

	for _, player in ipairs(players) do
		queue[player.UserId] = nil
	end
end

--==================================================
-- プレイヤー参加
--==================================================
function LobbyManager:_onPlayerAdded(player)
	self._lobbyPlayers[player.UserId] = player
	print("[LobbyManager] Player joined lobby:", player.Name)
end

--==================================================
-- プレイヤー退出
--==================================================
function LobbyManager:_onPlayerRemoving(player)
	self._lobbyPlayers[player.UserId] = nil
	self:_removeFromAllQueues(player)
end

--==================================================
-- 全難易度キューから除去（退出・難易度変更時）
--==================================================
function LobbyManager:_removeFromAllQueues(player)
	for difficulty, queue in pairs(self._gateQueues) do
		if queue[player.UserId] then
			queue[player.UserId] = nil
			self:_notifyQueueChanged(difficulty)
		end
	end
end

--==================================================
-- キュー変化通知
--==================================================
function LobbyManager:_notifyQueueChanged(difficulty)
	if self.OnQueueChanged then
		self.OnQueueChanged(difficulty, self._gateQueues[difficulty])
	end
end

--==================================================
-- ゲートを検索してタッチイベントを設定
-- Attribute "Difficulty" = "Easy" | "Normal" | "Hard" を持つ
-- BasePart であればどんな Part 名でも対応する
--==================================================
function LobbyManager:_setupGates()
	local function trySetup(part)
		if not part:IsA("BasePart") then return end
		local difficulty = part:GetAttribute("Difficulty")
		if not difficulty then return end  -- Attribute なし → 対象外
		if not VALID_DIFFICULTIES[difficulty] then
			warn(string.format(
				"[LobbyManager] %s の Difficulty=\"%s\" は無効です（Easy/Normal/Hard のいずれか）",
				part.Name, tostring(difficulty)
			))
			return
		end

		local conn = part.Touched:Connect(function(hit)
			if hit.Name ~= "HumanoidRootPart" then return end
			local character = hit.Parent
			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end
			self:_onGateTouch(player, difficulty)
		end)
		table.insert(self._connections, conn)

		print("[LobbyManager] Gate registered:", difficulty)
	end

	for _, desc in ipairs(self._lobbyStage:GetDescendants()) do
		trySetup(desc)
	end

	-- 動的追加対応
	local conn = self._lobbyStage.DescendantAdded:Connect(trySetup)
	table.insert(self._connections, conn)
end

--==================================================
-- ゲートタッチ処理
--==================================================
function LobbyManager:_onGateTouch(player, difficulty)
	local userId = player.UserId

	-- 既にこの難易度キューに入っている → 無視
	if self._gateQueues[difficulty][userId] then return end

	-- 他の難易度キューから除去（難易度変更）
	self:_removeFromAllQueues(player)

	-- キューに追加
	self._gateQueues[difficulty][userId] = player
	print(string.format("[LobbyManager] %s → %s queue", player.Name, difficulty))

	-- 待機ゾーンへ転送
	self:_teleportToWaitingZone(player, difficulty)

	self:_notifyQueueChanged(difficulty)
end

--==================================================
-- 待機ゾーンへキャラクター転送
-- LobbyStage 配下に "WaitingZone_Easy" / "WaitingZone_Normal" / "WaitingZone_Hard"
-- という名前の BasePart（球体）を配置すること
-- 引力・姿勢制御はクライアント側（GravityZoneClient）が担当
--==================================================
function LobbyManager:_teleportToWaitingZone(player, difficulty)
	local zoneName = "WaitingZone_" .. difficulty
	local zone = self._lobbyStage:FindFirstChild(zoneName, true)
	if not zone then
		warn("[LobbyManager] WaitingZone not found:", zoneName, "（LobbyStage 配下に配置してください）")
		return
	end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- 球体頂上にスポーン（半径 + キャラクター高さ分）
	root.CFrame = zone.CFrame + Vector3.new(0, zone.Size.Y / 2 + 3, 0)
end

--==================================================
-- クリーンアップ
--==================================================
function LobbyManager:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
end

return LobbyManager
