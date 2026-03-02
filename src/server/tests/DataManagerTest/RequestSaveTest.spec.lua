-- tests/RequestSaveTest.spec.lua

return function()

    local DataManager = require(
	    script.Parent.Parent.Parent.DataModule.DataManager
    )

	describe("RequestSave", function()

		local dataManager
		local mockPlayer

		beforeEach(function()
			dataManager = DataManager.new()

			mockPlayer = {
				UserId = 123456,
				Name = "TestPlayer"
			}
		end)

		it("[RequestSave()]セッションが存在する場合に真を返しキューに追加する：returns true and enqueues when session exists", function()

			-- セッション登録（userIdキーにする）
			dataManager._sessionData[mockPlayer.UserId] = {}

			local result = dataManager:RequestSave(mockPlayer)

			expect(result).to.equal(true)
			expect(dataManager._saveQueue[mockPlayer.UserId]).to.equal(true)
		end)

		it("[RequestSave()]プレイヤーがnilの場合にfalseを返す：returns false when player is nil", function()

			local result = dataManager:RequestSave(nil)

			expect(result).to.equal(false)
		end)

		it("[RequestSave()]セッションが存在しない場合にfalseを返す：returns false when session does not exist", function()

			local result = dataManager:RequestSave(mockPlayer)

			expect(result).to.equal(false)
			expect(dataManager._saveQueue[mockPlayer.UserId]).to.equal(nil)
		end)

		it("[RequestSave()]キューエントリを重複させない：does not duplicate queue entries", function()

			dataManager._sessionData[mockPlayer.UserId] = {}

			dataManager:RequestSave(mockPlayer)
			dataManager:RequestSave(mockPlayer)

			local count = 0
			for _ in pairs(dataManager._saveQueue) do
				count += 1
			end

			expect(count).to.equal(1)
		end)

	end)
end