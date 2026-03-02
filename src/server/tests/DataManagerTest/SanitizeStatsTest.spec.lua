return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	describe("sanitizeStats", function()

		local dm

		beforeEach(function()
			dm = DataManager.new()
		end)

		it("[sanitizeStats]creates empty table if Stats is invalid", function()

			local data = {
				Stats = "broken"
			}

			dm:sanitizeStats(data)

			expect(typeof(data.Stats)).to.equal("table")
			expect(next(data.Stats)).to.equal(nil)
		end)

		it("[sanitizeStats]removes invalid difficulty", function()

			local data = {
				Stats = {
					GodMode = {
						Wins = 999
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.GodMode).to.equal(nil)
		end)

		it("[sanitizeStats]keeps valid BestTime", function()

			local data = {
				Stats = {
					Easy = {
						BestTime = 123.5
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.BestTime).to.equal(123.5)
		end)

		it("[sanitizeStats]removes invalid BestTime", function()

			local data = {
				Stats = {
					Easy = {
						BestTime = -10
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.BestTime).to.equal(nil)
		end)

		it("[sanitizeStats]floors and clamps Wins", function()

			local MAX_WINS = DataManager.MAX_WINS

			local data = {
				Stats = {
					Easy = {
						Wins = MAX_WINS + 100.8
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.Wins).to.equal(MAX_WINS)
		end)

		it("[sanitizeStats]removes negative Wins", function()

			local data = {
				Stats = {
					Easy = {
						Wins = -5
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.Wins).to.equal(0)
		end)

		it("[sanitizeStats]floors and clamps Plays", function()

			local MAX_PLAYS = DataManager.MAX_PLAYS

			local data = {
				Stats = {
					Easy = {
						Plays = MAX_PLAYS + 55.9
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.Plays).to.equal(MAX_PLAYS)
		end)

		it("[sanitizeStats]removes negative Plays", function()

			local data = {
				Stats = {
					Easy = {
						Plays = -10
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.Plays).to.equal(nil)
		end)

		it("[sanitizeStats]keeps nil BestTime", function()

			local data = {
				Stats = {
					Easy = {
						BestTime = nil
					}
				}
			}

			dm:sanitizeStats(data)

			expect(data.Stats.Easy.BestTime).to.equal(nil)
		end)

	end)

end