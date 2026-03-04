--==================================================
-- LobbyLeaderboardManager.luau
-- ロビー掲示板（Wins / BestTime / TopScore）管理
--
-- OrderedDataStore でランキングデータを保持し、
-- LobbyBoard 内の SurfaceGui に TOP_N 件を表示する
--
-- ［データソース］
--   Wins     : 全難易度合計勝利数
--   BestTime : 全難易度中の最速タイム
--   TopScore : 所持 Gold 残高
--
-- ［呼び出し元］
--   LobbyBootstrap → Init() + Submit(userId, data)
--==================================================
local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")

local LobbyLeaderboardManager = {}
LobbyLeaderboardManager.__index = LobbyLeaderboardManager

--// 設定
local TOP_N            = 10   -- 表示件数
local REFRESH_INTERVAL = 60   -- 自動更新間隔（秒）

--// OrderedDataStore 名
local STORE_WINS      = "LB_Wins_v1"
local STORE_BEST_TIME = "LB_BestTime_v1"
local STORE_GOLD      = "LB_Gold_v1"

--// BestTime スコア変換（小さい時間 → 大きいスコアに変換して降順ソート）
local TIME_BASE = 1_000_000
local function timeToScore(t)
	return TIME_BASE - math.floor(t * 1000)
end
local function scoreToTime(s)
	return (TIME_BASE - s) / 1000
end

local function formatTime(seconds)
	local m  = math.floor(seconds / 60)
	local s  = math.floor(seconds % 60)
	local cs = math.floor((seconds % 1) * 100)
	return string.format("%d:%02d.%02d", m, s, cs)
end

--==================================================
-- コンストラクタ
-- @param lobbyBoard  LobbyBoard Instance（Workspace 内）
--==================================================
function LobbyLeaderboardManager.new(lobbyBoard)
	local self = setmetatable({}, LobbyLeaderboardManager)
	self._lobbyBoard = lobbyBoard

	-- 各ランキングボードの Frame を取得
	self._frames = {
		Wins     = self:_getFrame("WinsLeaderBoard"),
		BestTime = self:_getFrame("BestTimeLeaderBoard"),
		TopScore = self:_getFrame("TopScoreLeaderBoard"),
	}

	-- Studio では OrderedDataStore を使用しない
	self._isStudio = RunService:IsStudio()
	if not self._isStudio then
		self._storeWins     = DataStoreService:GetOrderedDataStore(STORE_WINS)
		self._storeBestTime = DataStoreService:GetOrderedDataStore(STORE_BEST_TIME)
		self._storeGold     = DataStoreService:GetOrderedDataStore(STORE_GOLD)
	end

	return self
end

--==================================================
-- SurfaceGui → Frame を取得するヘルパー
--==================================================
function LobbyLeaderboardManager:_getFrame(boardName)
	local board = self._lobbyBoard:FindFirstChild(boardName, true)
	if not board then
		warn("[LeaderboardManager] Part が見つかりません:", boardName)
		return nil
	end
	local gui = board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then
		warn("[LeaderboardManager] SurfaceGui が見つかりません:", boardName)
		return nil
	end
	return gui:FindFirstChild("Frame")
end

--==================================================
-- 初期化（LobbyBootstrap から呼ぶ）
--==================================================
function LobbyLeaderboardManager:Init()
	-- 初回表示
	self:Refresh()

	-- 定期リフレッシュ
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			self:Refresh()
		end
	end)

	print("[LeaderboardManager] Init")
end

--==================================================
-- プレイヤーデータをランキングに登録
-- PlayerAdded → データロード完了後に呼ぶ
-- @param userId  number
-- @param data    DataManager セッションデータ
--==================================================
function LobbyLeaderboardManager:Submit(userId, data)
	if self._isStudio then return end
	if not data then return end

	task.spawn(function()
		-- Wins（全難易度合計）
		local totalWins = 0
		if data.Stats then
			for _, diffStats in pairs(data.Stats) do
				if type(diffStats) == "table" and type(diffStats.Wins) == "number" then
					totalWins += diffStats.Wins
				end
			end
		end
		if totalWins > 0 then
			pcall(function()
				self._storeWins:SetAsync(tostring(userId), totalWins)
			end)
		end

		-- BestTime（全難易度中の最速タイム → スコア変換）
		local bestTime = nil
		if data.Stats then
			for _, diffStats in pairs(data.Stats) do
				if type(diffStats) == "table" and type(diffStats.BestTime) == "number" then
					if bestTime == nil or diffStats.BestTime < bestTime then
						bestTime = diffStats.BestTime
					end
				end
			end
		end
		if bestTime then
			local newScore = timeToScore(bestTime)
			pcall(function()
				-- より良いスコア（タイムが速い）のみ更新
				self._storeBestTime:UpdateAsync(tostring(userId), function(old)
					if old == nil or newScore > old then return newScore end
					return nil
				end)
			end)
		end

		-- TopScore（獲得Gold累計）
		local totalGold = 0
		if data.Currency and type(data.Currency.TotalGoldEarned) == "number" then
			totalGold = data.Currency.TotalGoldEarned
		end
		if totalGold > 0 then
			pcall(function()
				self._storeGold:SetAsync(tostring(userId), totalGold)
			end)
		end
	end)
end

--==================================================
-- 全ランキング表示を更新
--==================================================
function LobbyLeaderboardManager:Refresh()
	if self._isStudio then return end

	task.spawn(function()
		self:_refreshBoard("Wins",     self._storeWins,     self._frames.Wins,
			"WinsLabel",  function(v) return tostring(v) end)

		self:_refreshBoard("BestTime", self._storeBestTime, self._frames.BestTime,
			"TimeLabel",  function(v) return formatTime(scoreToTime(v)) end)

		self:_refreshBoard("TopScore", self._storeGold,     self._frames.TopScore,
			"ScoreLabel", function(v) return tostring(v) end)
	end)
end

--==================================================
-- ランキングボード表示更新（内部）
-- @param boardType      string  ログ用識別名
-- @param store          OrderedDataStore
-- @param frame          Frame Instance（SurfaceGui 内）
-- @param valueLabelName string  値ラベル名（WinsLabel / TimeLabel / ScoreLabel）
-- @param valueFormatter function(value) → string
--==================================================
function LobbyLeaderboardManager:_refreshBoard(boardType, store, frame, valueLabelName, valueFormatter)
	if not frame or not store then return end

	-- TOP_N 件を降順で取得
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_N)
	end)
	if not ok or not pages then return end

	local ok2, entries = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 then return end

	-- 既存の行を削除（RowTemplate / UIListLayout / Title は残す）
	local template = frame:FindFirstChild("RowTemplate")
	for _, child in ipairs(frame:GetChildren()) do
		if child ~= template
			and child.Name ~= "UIListLayout"
			and child.Name ~= "Title" then
			child:Destroy()
		end
	end

	if not template then
		warn("[LeaderboardManager] RowTemplate が見つかりません:", boardType)
		return
	end

	-- 各エントリの行を生成
	for rank, entry in ipairs(entries) do
		local userId = tonumber(entry.key)
		local value  = entry.value

		-- プレイヤー名を取得
		local name = "---"
		local nameOk, result = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if nameOk then name = result end

		local row = template:Clone()
		row.Name        = "Row_" .. rank
		row.LayoutOrder = rank
		row.Visible     = true

		local rankLabel  = row:FindFirstChild("RankLabel")
		local nameLabel  = row:FindFirstChild("NameLabel")
		local valueLabel = row:FindFirstChild(valueLabelName)

		-- Studio 側に未定義の場合のフォールバック生成（外観は Studio で管理）
		if not rankLabel then
			rankLabel = Instance.new("TextLabel")
			rankLabel.Name                  = "RankLabel"
			rankLabel.BackgroundTransparency = 1
			rankLabel.Parent               = row
		end
		if not nameLabel then
			nameLabel = Instance.new("TextLabel")
			nameLabel.Name                  = "NameLabel"
			nameLabel.BackgroundTransparency = 1
			nameLabel.Parent               = row
		end
		if not valueLabel then
			valueLabel = Instance.new("TextLabel")
			valueLabel.Name                  = valueLabelName
			valueLabel.BackgroundTransparency = 1
			valueLabel.Parent               = row
		end

		rankLabel.Text  = "#" .. rank
		nameLabel.Text  = name
		valueLabel.Text = valueFormatter(value)

		row.Parent = frame
	end

	print(string.format("[LeaderboardManager] %s: %d 件更新", boardType, #entries))
end

return LobbyLeaderboardManager
