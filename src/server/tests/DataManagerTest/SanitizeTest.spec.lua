return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	local DefaultData = DataManager.DefaultData

    --// 各防御レイヤーの結合テスト//
	describe("_sanitize (integration)", function()

		local dm

		beforeEach(function()
			dm = DataManager.new()
		end)

		it("[_sanitize]handles completely broken data", function()

			local data = "corrupted"

			local result = dm:_sanitize(data)

			expect(typeof(result)).to.equal("table")
			expect(result.Currency).to.never.equal(nil)
			expect(result.Stats).to.never.equal(nil)
			expect(result.Inventory).to.never.equal(nil)
		end)

		it("[_sanitize]removes undefined top-level keys", function()

			local data = {
				Hack = true,
				Currency = { Gold = 0, Gems = 0 }
			}

			local result = dm:_sanitize(data)

			expect(result.Hack).to.equal(nil)
		end)

		it("[_sanitize]clamps negative and invalid currency", function()

			local data = {
				Currency = {
					Gold = -100,
					Gems = "hack"
				}
			}

			local result = dm:_sanitize(data)

			expect(result.Currency.Gold).to.equal(0)
			expect(result.Currency.Gems).to.equal(0)
		end)

		it("[_sanitize]removes invalid difficulty", function()

			local data = {
				Stats = {
					GodMode = {
						Wins = 999
					}
				}
			}

			local result = dm:_sanitize(data)

			expect(result.Stats.GodMode).to.equal(nil)
			expect(result.Stats.Easy).to.never.equal(nil)
		end)

		it("[_sanitize]repairs missing nested structure", function()

			local data = {
				Currency = {}
			}

			local result = dm:_sanitize(data)

			expect(result.Currency.Gold).to.equal(0)
			expect(result.Currency.Gems).to.equal(0)
		end)

		it("[_sanitize]fully restores Stats structure", function()

			local data = {
				Stats = {}
			}

			local result = dm:_sanitize(data)

			expect(result.Stats.Easy.Wins).to.equal(0)
			expect(result.Stats.Normal.Plays).to.equal(0)
			expect(result.Stats.Hard.BestTime).to.equal(nil)
		end)

	end)

end