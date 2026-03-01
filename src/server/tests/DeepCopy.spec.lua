-- tests/DeepCopy.spec.lua

return function()

	local DataManager = require(
		game.ServerScriptService.Server.DataModule.DataManager
	)

	describe("deepCopy", function()

		it("[deepCopy()]プリミティブ値を正しく複製：copies primitive values correctly", function()

			local original = { a = 10 }
			local copy = DataManager._deepCopy(original)

			expect(copy.a).to.equal(10)

		end)

		it("[deepCopy()]新しいテーブル参照を作成：creates a new table reference", function()

			local original = { a = 1 }
			local copy = DataManager._deepCopy(original)

			expect(copy).never.to.equal(original)

		end)

		it("[deepCopy()]ネストされたテーブルの深部コピー：deep copies nested tables", function()

			local original = {
				a = 1,
				b = {
					c = 2
				}
			}

			local copy = DataManager._deepCopy(original)

			expect(copy.b.c).to.equal(2)
			expect(copy.b).never.to.equal(original.b)

		end)

		it("[deepCopy()]コピーを修正してもオリジナルには影響しない：does not affect original when modifying copy", function()

			local original = {
				nested = { value = 5 }
			}

			local copy = DataManager._deepCopy(original)

			copy.nested.value = 99

			expect(original.nested.value).to.equal(5)

		end)

        it("[deepCopy()]循環参照テスト：handles circular references", function()

	        local original = {}
	        original.self = original

	        local copy = DataManager._deepCopy(original)

	        expect(copy).never.to.equal(original)
	        expect(copy.self).to.equal(copy)

        end)

	end)

end