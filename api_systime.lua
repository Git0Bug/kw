local CO = require "api_coservice"
local MSG = require "api_msg"
local cjson = require "cjson"

local dset = {}
--------------------------------------

local function GetLocalTime()
	local file = io.popen('/bin/date "+%Y-%m-%d %H:%M:%S"')
	if file then
			local output = file:read('*all')
			file:close()
			return output
	end
	return os.date("%Y-%m-%d %H:%M:%S")
end



local function API_get(red, args)
	local proxy = CO.GetProxy( "/datetime", "systemctrl" )
	if not proxy then
		MSG.ERROR( "systemError" )
	else
		local r,zone,ofs = proxy.GetLocation()
		local ntp,ntp_servers
		r,ntp,ntp_servers = proxy.GetNtp()
		proxy:Destroy()
		MSG.OK("", {
			data = {
				time = GetLocalTime(),
				timetype = ntp and "ntp" or "pc",
				Timezone = zone or "Asia/Shanghai",
				ntp = ntp_servers
			}
		})
	end
	return true
end

--------------------------------------

local function API_modify(red, args)
	if args then
		local proxy = CO.GetProxy( "/datetime", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r,done
			if args.timezone then
				r, done = proxy.SetLocation(args.timezone, args.offset)
				if not r or not done then
					MSG.ERROR( "setTimezoneError" )
					proxy:Destroy()
					return true
				end
			end

			if args.timetype then
				if args.time then
					r, done = proxy.SetNtp(false)
					r, done = proxy.SetDatetime( args.time )
				elseif args.ntp then
					r, done = proxy.SetNtp( true, args.ntp )
				end
				if not r or not done then
					MSG.ERROR( "setSystimeError" )
					proxy:Destroy()
					return true
				end
			end
			proxy:Destroy()
			MSG.OK()
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["modify"] = API_modify

--------------------------------------
return dset

