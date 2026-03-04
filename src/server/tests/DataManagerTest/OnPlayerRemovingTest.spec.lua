-- tests/OnPlayerRemovingTest.spec.lua

local DataManager = require(
	game.ServerScriptService.Server.DataModule.DataManager
)

return function()

	describe("DataManager:_onPlayerRemoving", function()

		-- afterEach で復元するためにオリジナルを保存する
		local origPerformSave  = DataManager._performSave
		local origSessionData  = DataManager._sessionData
		local origDirtyFlags   = DataManager._dirtyFlags
		local origSaveQueue    = DataManager._saveQueue
		local origLastSaveTime = DataManager._lastSaveTime
		local origIsSaving     = DataManager._isSaving
		local origIsLoading    = DataManager._isLoading

		local saveCalled
		local userId = 2222

		beforeEach(function()

			DataManager._sessionData = {}
			DataManager._dirtyFlags = {}
			DataManager._saveQueue = {}
			DataManager._lastSaveTime = {}
			DataManager._isSaving = {}
			DataManager._isLoading = {}

			saveCalled = false

			DataManager._performSave = function()
				saveCalled = true
			end
		end)

		-- 各テスト後にクラスレベルの書き換えを元に戻す
		afterEach(function()
			DataManager._performSave  = origPerformSave
			DataManager._sessionData  = origSessionData
			DataManager._dirtyFlags   = origDirtyFlags
			DataManager._saveQueue    = origSaveQueue
			DataManager._lastSaveTime = origLastSaveTime
			DataManager._isSaving     = origIsSaving
			DataManager._isLoading    = origIsLoading
		end)

		it("calls save and clears memory", function()

			DataManager._sessionData[userId] = {}
			DataManager._dirtyFlags[userId] = true

			DataManager:_onPlayerRemoving(userId)

			expect(saveCalled).to.equal(true)
			expect(DataManager._sessionData[userId]).to.equal(nil)
			expect(DataManager._dirtyFlags[userId]).to.equal(nil)

		end)

		it("does nothing if no session exists", function()

			DataManager:_onPlayerRemoving(userId)

			expect(saveCalled).to.equal(false)

		end)

		it("is safe to call twice", function()

			DataManager._sessionData[userId] = {}

			DataManager:_onPlayerRemoving(userId)
			DataManager:_onPlayerRemoving(userId)

			expect(saveCalled).to.equal(true)

		end)

	end)

end