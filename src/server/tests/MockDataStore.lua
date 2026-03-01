local MockStore = {}
MockStore.__index = MockStore

function MockStore.new()
	return setmetatable({
		storage = {}
	}, MockStore)
end

function MockStore:GetAsync(key)
	return self.storage[key]
end

function MockStore:UpdateAsync(key, callback)
	local old = self.storage[key]
	local newData = callback(old)
	self.storage[key] = newData
	return newData
end

return MockStore