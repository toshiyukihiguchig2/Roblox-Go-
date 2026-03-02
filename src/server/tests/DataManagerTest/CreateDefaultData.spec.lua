-- tests/CreateDefaultData.spec.lua

return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	describe("_createDefaultData", function()

		it("[_createDefaultData()]新しいデフォルトのデータ構造を返す：returns new default data structure", function()

			local data1 = DataManager:_createDefaultData()
			local data2 = DataManager:_createDefaultData()

			expect(data1).never.to.equal(data2)

		end)

		it("[_createDefaultData()]必須項目が含まれている：contains required fields", function()

			local data = DataManager:_createDefaultData()

			expect(data).to.be.ok()
			expect(data.Version).to.be.ok()

		end)

        it("[_createDefaultData()]正しいバージョンを設定：sets correct version", function()

			local data = DataManager:_createDefaultData()

			expect(data.Version).to.equal(DataManager.CURRENT_VERSION)

		end)

		it("[_createDefaultData()]デフォルトデータを変更しない：does not modify DefaultData", function()

			local data = DataManager:_createDefaultData()

			data.SomeField = "changed"

			local fresh = DataManager:_createDefaultData()

			expect(fresh.SomeField).never.to.equal("changed")

		end)

		it("[_createDefaultData()]returns completely new deep structure", function()

			local data = DataManager:_createDefaultData()
			local fresh = DataManager:_createDefaultData()

			-- トップレベル参照
			expect(data).never.to.equal(fresh)

			-- ネスト参照
			expect(data.Currency).never.to.equal(fresh.Currency)
			expect(data.Stats).never.to.equal(fresh.Stats)

		end)

		it("[_createDefaultData()]does not mutate DefaultData nested tables", function()

			local data = DataManager:_createDefaultData()

			data.Currency.Gold = 999
			data.Stats.Easy.Wins = 5

			local template = DataManager.DefaultData

			expect(template.Currency.Gold).to.equal(0)
			expect(template.Stats.Easy.Wins).to.equal(0)

		end)

	end)

end