-- tests/OnPlayerAddedTest.spec.lua
-- セッション生成
-- dirty初期値false
-- 二重ロード防止

local DataManager = require(
	game.ServerScriptService.Server.DataModule.DataManager
)

return function()

	describe("DataManager:_onPlayerAdded", function()

		-- afterEach で復元するためにテスト前のオリジナルを保存する
		-- ※ describe スコープで宣言することで beforeEach より先に確定する
		local origGetAsync       = DataManager._getAsyncWithRetry
		local origCreateDefault  = DataManager._createDefaultData
		local origMigrate        = DataManager._migrate
		local origSanitize       = DataManager._sanitize
		local origApplyGameRules = DataManager._applyGameRules
		local origSessionData    = DataManager._sessionData
		local origDirtyFlags     = DataManager._dirtyFlags
		local origIsLoading      = DataManager._isLoading
		local origLastSaveTime   = DataManager._lastSaveTime

		beforeEach(function()

			DataManager._sessionData = {}
			DataManager._dirtyFlags = {}
			DataManager._isLoading = {}
			DataManager._lastSaveTime = {}

			-- 依存モック
			DataManager._getAsyncWithRetry = function()
				return nil
			end

			DataManager._createDefaultData = function()
				return { Version = 1 }
			end

			DataManager._migrate = function(_, data)
				return data
			end

			DataManager._sanitize = function(_, data)
				return data
			end

			DataManager._applyGameRules = function(_, data)
				return data
			end

		end)

		-- 各テスト後にクラスレベルの書き換えを元に戻す
		-- ※ Lua モジュールはシングルトンのため、後続テストに影響しないよう必須
		afterEach(function()
			DataManager._getAsyncWithRetry = origGetAsync
			DataManager._createDefaultData = origCreateDefault
			DataManager._migrate           = origMigrate
			DataManager._sanitize          = origSanitize
			DataManager._applyGameRules    = origApplyGameRules
			DataManager._sessionData       = origSessionData
			DataManager._dirtyFlags        = origDirtyFlags
			DataManager._isLoading         = origIsLoading
			DataManager._lastSaveTime      = origLastSaveTime
		end)

        it("creates session data when no existing data", function()

            local userId = 2222

            DataManager:_onPlayerAdded(userId)

            expect(DataManager._sessionData[userId]).never.to.equal(nil)
            expect(DataManager._dirtyFlags[userId]).to.equal(false)

        end)

        it("prevents double loading", function()

            local userId = 2222

            DataManager._sessionData[userId] = {}

            DataManager:_onPlayerAdded(userId)

            expect(DataManager._isLoading[userId]).to.equal(nil)

        end)

	end)

end