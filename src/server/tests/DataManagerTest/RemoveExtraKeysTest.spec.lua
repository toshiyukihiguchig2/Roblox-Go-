return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	local DefaultData = DataManager.DefaultData

	describe("removeExtraKeys", function()

		local dm

		beforeEach(function()
			dm = DataManager.new()
		end)

		it("[removeExtraKeys]removes top level extra keys", function()

			local data = {
				Hack = true,
				Currency = {
					Gold = 0,
					Gems = 0
				}
			}

			dm:removeExtraKeys(data, DefaultData)

			expect(data.Hack).to.equal(nil)
		end)

		it("[removeExtraKeys]removes nested extra keys", function()

			local data = {
				Currency = {
					Gold = 0,
					Gems = 0,
					HackMoney = 999999
				}
			}

			dm:removeExtraKeys(data, DefaultData)

			expect(data.Currency.HackMoney).to.equal(nil)
		end)

		it("[removeExtraKeys]keeps Version even if not in template", function()

			local data = {
				Version = 999
			}

			dm:removeExtraKeys(data, DefaultData)

			expect(data.Version).to.equal(999)
		end)

	end)

end