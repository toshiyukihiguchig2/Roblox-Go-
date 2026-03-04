--==================================================
-- MatchmakingManager.luau
-- 難易度別カウントダウン＋グループテレポート管理
--
-- ［カウントダウン仕様］
--   1. 最初のプレイヤーがゲートタッチ → 30秒カウントダウン開始
--   2. 追加参加 → カウントダウン継続
--   3. 定員到達 → 現タイマーをキャンセルし5秒タイマーに切り替え
--   4. 0秒 → TeleportAsync で専用サーバーへ転送
--   5. キューが空になった → タイマーキャンセル
--==================================================
local MatchmakingManager = {}
MatchmakingManager.__index = MatchmakingManager

--// Services
local TeleportService = game:GetService("TeleportService")
local RunService      = game:GetService("RunService")

--==================================================
-- コンストラクタ
-- @param lobbyManager  LobbyManager インスタンス
-- @param config        設定テーブル
--   .placeIds          { Easy=PlaceId, Normal=PlaceId, Hard=PlaceId }
--   .maxPlayers        { Easy=8, Normal=6, Hard=4 }
--   .countdownInitial  number（秒、最初の1人目開始）
--   .countdownFullRoom number（秒、定員到達後）
--==================================================
function MatchmakingManager.new(lobbyManager, config)
	local self = setmetatable({}, MatchmakingManager)

	self._lobbyManager      = lobbyManager
	self._placeIds          = config.placeIds
	self._maxPlayers        = config.maxPlayers       or { Easy = 8, Normal = 6, Hard = 4 }
	self._countdownInitial  = config.countdownInitial  or 30
	self._countdownFullRoom = config.countdownFullRoom or 5

	-- 難易度別タイムアウトスレッド { [difficulty] = thread }
	self._timers     = {}
	-- タイマー開始情報 { [difficulty] = { startedAt=tick(), duration=seconds } }
	self._timerMeta  = {}

	-- セッション通番（ログ用）
	self._sessionCount = { Easy = 0, Normal = 0, Hard = 0 }

	return self
end

--==================================================
-- 初期化（LobbyBootstrap から呼ぶ）
--==================================================
function MatchmakingManager:Init()
	self._lobbyManager.OnQueueChanged = function(difficulty, queue)
		self:_onQueueChanged(difficulty, queue)
	end

	print("[MatchmakingManager] Init",
		"| countdownInitial:", self._countdownInitial,
		"| countdownFullRoom:", self._countdownFullRoom)
	for diff, max in pairs(self._maxPlayers) do
		print(string.format("  %s: max %d", diff, max))
	end
end

--==================================================
-- キュー変化ハンドラ
--==================================================
function MatchmakingManager:_onQueueChanged(difficulty, queue)
	local players = {}
	for _, player in pairs(queue) do
		table.insert(players, player)
	end
	local count = #players
	local max   = self._maxPlayers[difficulty] or 4

	-- キューが空 → タイマーキャンセル
	if count == 0 then
		self:_cancelTimer(difficulty)
		return
	end

	-- 定員到達 → 残り時間が countdownFullRoom より多い場合のみ短縮
	if count >= max then
		local meta = self._timerMeta[difficulty]
		if meta then
			local remaining = meta.duration - (tick() - meta.startedAt)
			if remaining <= self._countdownFullRoom then
				-- 残り5秒以内 → そのまま継続（短縮不要）
				return
			end
		end
		self:_cancelTimer(difficulty)
		self:_startTimer(difficulty, self._countdownFullRoom, players)
		return
	end

	-- 最初の1人 → 30秒タイマー開始（既に動いていれば何もしない）
	if count == 1 and not self._timers[difficulty] then
		self:_startTimer(difficulty, self._countdownInitial, nil)
	end
end

--==================================================
-- カウントダウンタイマー開始
-- @param difficulty string
-- @param seconds    number  カウントダウン秒数
-- @param snapshot   { Player } | nil  定員時のスナップショット（nil = タイマー終了時に取得）
--==================================================
function MatchmakingManager:_startTimer(difficulty, seconds, snapshot)
	self._timerMeta[difficulty] = { startedAt = tick(), duration = seconds }

	local thread = task.delay(seconds, function()
		self._timers[difficulty]    = nil
		self._timerMeta[difficulty] = nil

		-- テレポート対象プレイヤーを確定
		local players = snapshot
		if not players then
			local queue = self._lobbyManager:GetQueue(difficulty)
			players = {}
			for _, player in pairs(queue) do
				table.insert(players, player)
			end
		end

		if #players >= 1 then
			self:_startSession(difficulty, players)
		end
	end)

	self._timers[difficulty] = thread
	print(string.format("[MatchmakingManager] %s: カウントダウン %ds 開始", difficulty, seconds))
end

--==================================================
-- タイマーキャンセル
--==================================================
function MatchmakingManager:_cancelTimer(difficulty)
	if self._timers[difficulty] then
		task.cancel(self._timers[difficulty])
		self._timers[difficulty]    = nil
		self._timerMeta[difficulty] = nil
		print("[MatchmakingManager] タイマーキャンセル:", difficulty)
	end
end

--==================================================
-- セッション開始（MAX 単位で分割し複数セッション対応）
--==================================================
function MatchmakingManager:_startSession(difficulty, allPlayers)
	local placeId = self._placeIds[difficulty]
	local max     = self._maxPlayers[difficulty] or 4

	if not placeId or placeId == 0 then
		warn("[MatchmakingManager] PlaceId 未設定:", difficulty)
		return
	end

	-- キューから先に除去（二重セッション防止）
	self._lobbyManager:RemovePlayersFromQueue(difficulty, allPlayers)

	-- MAX 単位でグループ分割
	local groups  = {}
	local current = {}
	for _, player in ipairs(allPlayers) do
		table.insert(current, player)
		if #current >= max then
			table.insert(groups, current)
			current = {}
		end
	end
	if #current > 0 then
		table.insert(groups, current)
	end

	for _, group in ipairs(groups) do
		self._sessionCount[difficulty] += 1
		local sessionId = self._sessionCount[difficulty]
		task.spawn(function()
			self:_teleportGroup(difficulty, group, placeId, sessionId)
		end)
	end
end

--==================================================
-- グループテレポート
--==================================================
function MatchmakingManager:_teleportGroup(difficulty, players, placeId, sessionId)
	if RunService:IsStudio() then
		local names = {}
		for _, p in ipairs(players) do table.insert(names, p.Name) end
		warn(string.format(
			"[MatchmakingManager] [Studio制限] %s Session-%d テレポートをスキップ: [%s]",
			difficulty, sessionId, table.concat(names, ", ")
		))
		return
	end

	local activePlayers = {}
	for _, player in ipairs(players) do
		if player.Parent then
			table.insert(activePlayers, player)
		end
	end
	if #activePlayers == 0 then return end

	local names = {}
	for _, p in ipairs(activePlayers) do table.insert(names, p.Name) end
	print(string.format(
		"[MatchmakingManager] %s Session-%d: teleporting [%s]",
		difficulty, sessionId, table.concat(names, ", ")
	))

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({ Difficulty = difficulty })

	local success, err = pcall(function()
		TeleportService:TeleportAsync(placeId, activePlayers, options)
	end)

	if not success then
		warn("[MatchmakingManager] TeleportAsync 失敗:", err)
		-- 差し戻し
		local queue = self._lobbyManager:GetQueue(difficulty)
		for _, player in ipairs(activePlayers) do
			if player.Parent then
				queue[player.UserId] = player
			end
		end
	end
end

return MatchmakingManager
