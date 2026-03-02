-- tests/OnPlayerAddedTest.spec.lua
-- セッション生成
-- dirty初期値false
-- 二重ロード防止

local DataManager = require(
	game.ServerScriptService.Server.DataModule.DataManager
)

return function()

	describe("DataManager:_onPlayerAdded", function()

		local mockPlayer

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