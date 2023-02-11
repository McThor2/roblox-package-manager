
local Cache = {}
Cache.__index = Cache

function Cache.new(timeToLive: number?)
	local self = {}
	self.TTL = timeToLive or 0
	self._data = {}
	
	
	
	setmetatable(self, Cache)
	return self
end

function Cache:get(key)
	return self._data[key] and self._data[key].value or nil
end

function Cache:set(key, value)
	self._data[key] = {
		value = value, 
		timestamp = os.clock()
	}
end

return Cache
