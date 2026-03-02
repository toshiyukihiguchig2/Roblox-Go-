-- tests/Migrate.spec.lua

return function()

	local DataManager = require(
		script.Parent.Parent.Parent.DataModule.DataManager
	)

	describe("_migrate", function()

        it("[_migrate()]バージョンの返却がnil：returns default when data is nil", function()

	        local result = DataManager:_migrate(nil)

	        expect(result.Version).to.equal(DataManager.CURRENT_VERSION)

        end)

	    it("[_migrate()]Versionが無い場合1に設定され移行しない", function()

	        local oldData = {} -- Versionなし

	        local migrated = DataManager:_migrate(oldData)

	        expect(migrated.Version).to.equal(DataManager.CURRENT_VERSION)

        end)

		it("[_migrate()]バージョン1から現在のバージョンへ移行：migrates from version 1 to current", function()

			local data = {
				Version = 1
			}

			local result = DataManager:_migrate(data)

			expect(result.Version).to.equal(DataManager.CURRENT_VERSION)

		end)

	    it("[_migrate()]既に最新の状態である場合、データを変更しない：does not change data when already current", function()

		    local data = {
		    	Version = DataManager.CURRENT_VERSION
		    }

		    local result = DataManager:_migrate(data)

		    expect(result.Version).to.equal(DataManager.CURRENT_VERSION)

	    end)

	end)

end