return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	local DefaultData = DataManager.DefaultData

	describe("reconcile", function()

		local dm

		beforeEach(function()
			dm = DataManager.new()
		end)

		it("[reconcile]adds missing top level keys", function()

			local data = {}

			dm:reconcile(data, DefaultData)

			expect(data.Currency).to.never.equal(nil)
			expect(data.Stats).to.never.equal(nil)
			expect(data.Inventory).to.never.equal(nil)
		end)

		it("[reconcile]adds missing nested keys", function()

			local data = {
				Currency = {}
			}

			dm:reconcile(data, DefaultData)

			expect(data.Currency.Gold).to.equal(0)
			expect(data.Currency.Gems).to.equal(0)
		end)

		it("[reconcile]does not overwrite existing values", function()

			local data = {
				Currency = {
					Gold = 500
				}
			}

			dm:reconcile(data, DefaultData)

			expect(data.Currency.Gold).to.equal(500)
		end)

		it("[reconcile]creates full Stats structure", function()

			local data = {
				Stats = {}
			}

			dm:reconcile(data, DefaultData)

			expect(data.Stats.Easy).to.never.equal(nil)
			expect(data.Stats.Normal).to.never.equal(nil)
			expect(data.Stats.Hard).to.never.equal(nil)

			expect(data.Stats.Easy.Wins).to.equal(0)
			expect(data.Stats.Easy.Plays).to.equal(0)
		end)

		it("[reconcile]deep copies tables (no reference sharing)", function()

			local data = {}

			dm:reconcile(data, DefaultData)

			-- 書き換えてもDefaultDataが変わらないか確認
			data.Currency.Gold = 999

			expect(DefaultData.Currency.Gold).to.equal(0)
		end)

		it("does not share nested references with DefaultData", function()

			local data = {}

			dm:reconcile(data, DefaultData)

			data.Stats.Easy.Wins = 123

			expect(DefaultData.Stats.Easy.Wins).to.equal(0)

		end)

	end)

end