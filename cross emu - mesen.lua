-- Emus that use an old version of lua choke on parsing these bitwise operators, but Mesen doesn't have a bit operator library,
-- so I've had to move this code out into a separate file that's conditionally included

local xemu = {}
xemu.rshift = function(x, y) return x >> y end
xemu.lshift = function(x, y) return x << y end
xemu.not_ = function(x) return ~x end
xemu.and_ = function(x, y) return x & y end
xemu.or_ = function(x, y) return x | y end
xemu.xor = function(x, y) return x ~ y end

return xemu
