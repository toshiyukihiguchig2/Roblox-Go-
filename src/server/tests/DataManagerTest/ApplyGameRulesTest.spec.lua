return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	describe("_applyGameRules", function()

		local dm

		beforeEach(function()
			dm = DataManager.new()
		end)

		----------------------------------------------------------------
		-- Currency Sanitize（通貨改ざん対策）
		----------------------------------------------------------------
		describe("Currency - Anti Tamper", function()

			it("replaces non-number values with 0", function()
				-- 観点：
				-- 型改ざん（string, booleanなど）を防ぐ
				local data = {
					Currency = {
						Gold = "hack",
						Gems = false
					}
				}

				dm:_applyGameRules(data)

				expect(data.Currency.Gold).to.equal(0)
				expect(data.Currency.Gems).to.equal(0)
			end)

			it("replaces NaN and Infinity with 0", function()
				-- 観点：
				-- 数値だが不正値（NaN / ±inf）の混入対策
				local data = {
					Currency = {
						Gold = 0/0,
						Gems = math.huge
					}
				}

				dm:_applyGameRules(data)

				expect(data.Currency.Gold).to.equal(0)
				expect(data.Currency.Gems).to.equal(0)
			end)

		end)

		----------------------------------------------------------------
		-- Currency Clamp（範囲制限）
		----------------------------------------------------------------
		describe("Currency - Range Clamp", function()

			it("clamps negative values to 0", function()
				-- 観点：
				-- マイナス通貨注入対策
				local data = {
					Currency = {
						Gold = -50,
						Gems = -1
					}
				}

				dm:_applyGameRules(data)

				expect(data.Currency.Gold).to.equal(0)
				expect(data.Currency.Gems).to.equal(0)
			end)

			it("clamps values above max", function()
				-- 観点：
				-- 上限突破改ざん対策
				local MAX_GOLD = DataManager.MAX_GOLD
				local MAX_GEMS = DataManager.MAX_GEMS

				local data = {
					Currency = {
						Gold = MAX_GOLD + 1000,
						Gems = MAX_GEMS + 999
					}
				}

				dm:_applyGameRules(data)

				expect(data.Currency.Gold).to.equal(MAX_GOLD)
				expect(data.Currency.Gems).to.equal(MAX_GEMS)
			end)

		end)

		----------------------------------------------------------------
		-- Currency Normalization（正規化）
		----------------------------------------------------------------
		describe("Currency - Normalization", function()

			it("floors decimal values", function()
				-- 観点：
				-- 小数通貨を整数化（仕様統一）
				local data = {
					Currency = {
						Gold = 10.7,
						Gems = 3.9
					}
				}

				dm:_applyGameRules(data)

				expect(data.Currency.Gold).to.equal(10)
				expect(data.Currency.Gems).to.equal(3)
			end)

			it("recreates broken currency table", function()
				-- 観点：
				-- 構造破壊データ修復
				local data = {
					Currency = "broken"
				}

				dm:_applyGameRules(data)

				expect(typeof(data.Currency)).to.equal("table")
				expect(data.Currency.Gold).to.equal(0)
				expect(data.Currency.Gems).to.equal(0)
			end)

		end)
        describe("Stats - Integrity", function()

	        it("prevents Wins from exceeding Plays", function()
		        local data = {
	        		Stats = {
	        			Easy = {
	        				Wins = 10,
		        			Plays = 5,
	        				BestTime = 50
		        		}
	        		}
	        	}

        		dm:_applyGameRules(data)

        		expect(data.Stats.Easy.Wins).to.equal(5)
        	end)

        	it("removes BestTime if Wins is zero", function()
        		local data = {
        			Stats = {
	        			Easy = {
	        				Wins = 0,
	        				Plays = 10,
	        				BestTime = 45
	        			}
	        		}
	        	}

	        	dm:_applyGameRules(data)

	        	expect(data.Stats.Easy.BestTime).to.equal(nil)
	        end)

	        it("removes invalid BestTime (too small)", function()
				local MIN_BEST_TIME = DataManager.MIN_BEST_TIME
	        	local data = {
	        		Stats = {
	        			Easy = {
		        			Wins = 1,
		        			Plays = 1,
		        			BestTime = MIN_BEST_TIME - 1
		        		}
		        	}
		        }

		        dm:_applyGameRules(data)

		        expect(data.Stats.Easy.BestTime).to.equal(nil)
	        end)

	        it("removes invalid BestTime (too large)", function()
				local MAX_BEST_TIME = DataManager.MAX_BEST_TIME
	        	local data = {
	        		Stats = {
	        			Easy = {
	        				Wins = 1,
	        				Plays = 1,
	        				BestTime = MAX_BEST_TIME + 1
	        			}
	        		}
	        	}

	        	dm:_applyGameRules(data)

	        	expect(data.Stats.Easy.BestTime).to.equal(nil)
	        end)

	        it("sanitizes type-mismatched stats", function()
	        	local data = {
	        		Stats = {
	        			Easy = {
	        				Wins = "hack",
	        				Plays = "broken",
	        				BestTime = "cheat"
	        			}
	        		}
	        	}

	        	dm:_applyGameRules(data)

	        	expect(data.Stats.Easy.Wins).to.equal(0)
	        	expect(data.Stats.Easy.Plays).to.equal(0)
	        	expect(data.Stats.Easy.BestTime).to.equal(nil)
	        end)

        end)

	end)

end