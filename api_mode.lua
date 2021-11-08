local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
	REBOOTING = false
}

--------------------------------------
local function API_get(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, mode = proxy.GetMode()
		if r and mode then
			if mode == "decoding" or mode == "decoder" then
				mode = "decoder"
			else
				mode = "encoder"
			end
			MSG.OK("", {
				data = {
					mode = mode
				}
			})
		else
			MSG.ERROR( "getDeviceModeError" )
		end
		proxy:Destroy()
		return true
	end
end
--------------------------------------

local function API_status(red, args)
	if dset.REBOOTING then
		MSG.ERROR( "waitChangeModeError" )
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "waitChangeModeError" )
		return true
	else
		local r, mode = proxy.GetMode()
		if r and mode then
			MSG.OK("", {
				data = {
					mode = ((mode == "decoding" or mode == "decoder") and "decoder") or "encoder",
					status = "ready"
				}
			})
		else
			MSG.ERROR( "waitChangeModeError" )
		end
		proxy:Destroy()
		return true
	end
end

--------------------------------------

local function API_switch(red, args)
	if args and args.mode then
		local proxy = CO.GetProxy( "/", "codec" )
		if not proxy then
			MSG.ERROR( "codecError" )
			return true
		else
			local mode
			if args.mode == "decoder" or args.mode == "decoding" then
				mode = "decoding"
			else
				mode = "encoding"
			end
			local r,done = proxy.SwitchMode( mode )
			proxy:Destroy()
			if not r or not done then
				MSG.ERROR("Failure to switch codec mode" )
			else
				proxy = CO.GetProxy( "/", "systemctrl" )
				if not proxy then
					MSG.ERROR( "Switched work mode but failure to control device reset" )
					return true
				else
					proxy.Reset()
					proxy:Destroy()
					MSG.OK("")
				end
			end
			return true
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["status"] = API_status
dset.APIS["switch"] = API_switch

--------------------------------------
return dset

