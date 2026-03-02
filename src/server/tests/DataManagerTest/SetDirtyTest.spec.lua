-- tests/SetDirtyTest.spec.lua

local DataManager = require(
	game.ServerScriptService.Server.DataModule.DataManager
)

return function()

	describe("DataManager:SetDirty", function()

		local userId = 2222

		beforeEach(function()

			DataManager._sessionData = {}
			DataManager._dirtyFlags = {}

		end)

		it("sets dirty flag when session exists", function()

			DataManager._sessionData[userId] = {}

			DataManager:SetDirty(userId)

			expect(DataManager._dirtyFlags[userId]).to.equal(true)

		end)

		it("does nothing when session does not exist", function()

			DataManager:SetDirty(userId)

			expect(DataManager._dirtyFlags[userId]).to.equal(nil)

		end)

	end)

end