-- tests/_getAsyncWithRetry.spec.lua

return function()

	local DataManager = require(
		game.ServerScriptService.Server.DataModule.DataManager
	)

	describe("_getAsyncWithRetry", function()

        it("[_getAsyncWithRetry]初回試行で成功した場合にデータを返す：returns data when success on first try", function()

			local mockStore = {}

			function mockStore:GetAsync(key)
				return "DATA"
			end

			local result = DataManager:_getAsyncWithRetry(mockStore, "key")

			expect(result).to.equal("DATA")

		end)

        -- 再試行するためwarning出力するケース
		it("[_getAsyncWithRetry]再試行して成功する：retries and succeeds", function()

			local mockStore = {}
			local callCount = 0

			function mockStore:GetAsync(key)
				callCount += 1

				if callCount < 3 then
					error("fail")
				end

				return "SUCCESS"
			end

			local result = DataManager:_getAsyncWithRetry(mockStore, "key")

			expect(result).to.equal("SUCCESS")
			expect(callCount).to.equal(3)

		end)

        -- 再試行するためwarning出力するケース
		it("[_getAsyncWithRetry]最大再試行回数後にnilを返す：returns nil after max retries", function()

			local mockStore = {}
			local callCount = 0

			function mockStore:GetAsync(key)
				callCount += 1
				error("always fail")
			end

			local result = DataManager:_getAsyncWithRetry(mockStore, "key")

			expect(result).to.equal(nil)
			expect(callCount).to.equal(DataManager.MAX_RETRIES)

		end)

	end)

end