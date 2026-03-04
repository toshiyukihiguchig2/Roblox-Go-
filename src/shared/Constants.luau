--==================================================
-- Constants.luau
-- ゲーム全体で共有する定数（仕様書 §6, §8 準拠）
--==================================================

local Constants = {}

--------------------------------------------------
-- Teleport
--------------------------------------------------

-- ロビーの PlaceId（GO_MainLobby）
Constants.LOBBY_PLACE_ID = 121197168152258

-- 難易度別専用サーバー PlaceId
Constants.EASY_PLACE_ID   = 89637531958435   -- GO_EasyPlace
Constants.NORMAL_PLACE_ID = 79698966629586   -- GO_NormalPlace
Constants.HARD_PLACE_ID   = 112279469042537  -- GO_HardPlace

-- 難易度別最大プレイヤー数（定員）
Constants.MAX_PLAYERS = {
	Easy   = 8,
	Normal = 6,
	Hard   = 4,
}

-- カウントダウン設定（秒）
Constants.COUNTDOWN_INITIAL  = 30  -- 最初のプレイヤーがゲートタッチ後
Constants.COUNTDOWN_FULLROOM = 5   -- 定員到達後に短縮

-- 有効な難易度一覧
Constants.VALID_DIFFICULTIES = {
	Easy   = true,
	Normal = true,
	Hard   = true,
}

--------------------------------------------------
-- 報酬設計（仕様書 §6）
--------------------------------------------------

-- 基本報酬ゴールド
Constants.REWARD_BASE_GOLD = 100

-- 難易度倍率（§6.1）
Constants.DIFFICULTY_MULTIPLIERS = {
	Easy   = 1.0,
	Normal = 1.5,
	Hard   = 2.5,
}

-- 順位補正（§6.3：サーバー側で到達順をstack保存）
-- テーブルに存在しない順位はデフォルト 1.0
Constants.RANK_BONUS = {
	[1] = 1.5,
	[2] = 1.2,
}

--------------------------------------------------
-- ランキング（仕様書 §8）
--------------------------------------------------

-- 難易度別TOP表示件数
Constants.RANKING_TOP_N = 50

return Constants
