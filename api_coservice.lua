local _dbg = require "coaf.debug"
local client = require "coaf.client"
local adapter = require "coaf.cli_adapter.simple"

--For nginx using, the timeout unit is ms, so the timeoutUnit value is 1000
adapter.timeoutUnit = 1000
client.InitSocket(nil, adapter)

local _M = {}

--------------------------------

function _M.GetProxy(objPath, service, loc, timeout, socket_addr)
	local proxy
	local cli

	cli = client.New( service, loc, socket_addr, timeout or 5 ) --5 seconds timeout.
	if not cli then
		_dbg.Error( "CO", "Fail to create connection to service '" .. (loc or "local") .. "/" .. (service or "nil") )
		return nil
	end
	proxy = cli:CreateProxy(objPath, true) --Exclusive
	if not proxy then
		_dbg.Error( "CO", "Fail to create object proxy for '" .. (objPath or "unknown") .. "'" )
		return nil
	end
	return proxy
end

return _M

