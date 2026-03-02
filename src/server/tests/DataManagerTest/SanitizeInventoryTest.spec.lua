return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	describe("sanitizeInventory", function()

		local dm

		beforeEach(function()
			dm = DataManager.new()
		end)

		it("[sanitizeInventory]removes invalid types", function()
			local data = {
				Inventory = {
					GoodItem = 3,
					BadItem = "hack",
					Another = {}
				}
			}

			dm:sanitizeInventory(data)

			expect(data.Inventory.GoodItem).to.equal(3)
			expect(data.Inventory.BadItem).to.equal(nil)
			expect(data.Inventory.Another).to.equal(nil)
		end)

		it("[sanitizeInventory]removes zero and negative values", function()
			local data = {
				Inventory = {
					A = 0,
					B = -5,
					C = 2
				}
			}

			dm:sanitizeInventory(data)

			expect(data.Inventory.A).to.equal(nil)
			expect(data.Inventory.B).to.equal(nil)
			expect(data.Inventory.C).to.equal(2)
		end)

		it("[sanitizeInventory]floors decimal values", function()
			local data = {
				Inventory = {
					A = 3.8
				}
			}

			dm:sanitizeInventory(data)

			expect(data.Inventory.A).to.equal(3)
		end)

		it("[sanitizeInventory]clamps over max", function()
			local data = {
				Inventory = {
					A = 999999
				}
			}

			dm:sanitizeInventory(data)

			expect(data.Inventory.A).to.equal(999)
		end)

		it("[sanitizeInventory]creates empty inventory if broken", function()
			local data = {
				Inventory = "broken"
			}

			dm:sanitizeInventory(data)

			expect(typeof(data.Inventory)).to.equal("table")
		end)

	end)

end