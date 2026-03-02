return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	describe("isValidNumber", function()

		it("returns true for valid numbers", function()
			expect(DataManager:isValidNumber(10)).to.equal(true)
			expect(DataManager:isValidNumber(0)).to.equal(true)
			expect(DataManager:isValidNumber(-5)).to.equal(true)
		end)

		it("returns false for nil", function()
			expect(DataManager:isValidNumber(nil)).to.equal(false)
		end)

		it("returns false for non-number types", function()
			expect(DataManager:isValidNumber("10")).to.equal(false)
			expect(DataManager:isValidNumber({})).to.equal(false)
		end)

		it("returns false for NaN", function()
			expect(DataManager:isValidNumber(0/0)).to.equal(false)
		end)

		it("returns false for infinite values", function()
			expect(DataManager:isValidNumber(math.huge)).to.equal(false)
			expect(DataManager:isValidNumber(-math.huge)).to.equal(false)
		end)

	end)

end