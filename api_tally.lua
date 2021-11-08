local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
}
--------------------------------------
local function API_get(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,pgm,pvw = proxy.GetTally()
		proxy:Destroy()
		if not r then
			MSG.ERROR( "getTallyError" )
		else
			MSG.OK("",{data={
				pgm = pgm and 1 or 0,
				pvw = pvw and 1 or 0
			}})
		end
		return true
	end
end

--------------------------------------
local function API_modify(red, args)
	if not args then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local pgm = tonumber(args.pgm)
	local pvw = tonumber(args.pvw)
	if pgm then
		pgm = (pgm==1)
	else
		pgm = "invalid"
	end
	if pvw then
		pvw = (pvw==1)
	else
		pvw = "invalid"
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,done = proxy.SetTally(pgm,pvw)
		proxy:Destroy()
		if not r or not done then
			MSG.ERROR("setTallyError")
		else
			MSG.OK("", {
				data = {
					pgm = args.pgm,
					pvw = args.pvw
				}
			})
		end
		return true
	end
end
--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["modify"] = API_modify
dset.APIS["status"] = API_get
dset.APIS["set"] = API_modify
--------------------------------------
return dset

