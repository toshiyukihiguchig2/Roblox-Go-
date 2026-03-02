-- tests/OnPlayerRemovingTest.spec.lua

local DataManager = require(
	game.ServerScriptService.Server.DataModule.DataManager
)

return function()

	describe("DataManager:_onPlayerRemoving", function()

		local saveCalled
		local userId = 2222

		beforeEach(function()

			DataManager._sessionData = {}
			DataManager._dirtyFlags = {}
			DataManager._saveQueue = {}
			DataManager._lastSaveTime = {}
			DataManager._isSaving = {}

			saveCalled = false

			DataManager._performSave = function()
				saveCalled = true
			end
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