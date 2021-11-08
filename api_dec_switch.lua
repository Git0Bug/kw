local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
}
--------------------------------------
local function API_getSettings(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.GetCurrentSettings()
		proxy:Destroy()
		if not r or not more then
			MSG.ERROR( "getSettingError" )
		else
			MSG.OK("",{data={
				smooth = more.smooth or 0
			}})
		end
		return true
	end
end

--------------------------------------
local function API_modifySettings(red, args)
	if not args or not args.smooth then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,done = proxy.SetCurrentSettings({smooth=tonumber(args.smooth)})
		proxy:Destroy()
		if not r or not done then
			MSG.ERROR("Failure to configure switch settings")
		else
			MSG.OK()
		end
		return true
	end
end
--------------------------------------
local function API_smoothOptions(red, args)
	MSG.OK("",{
		data = {
			{ value=0, name="Hard switch" },
			{ value=50, name="50 ms" },
			{ value=100, name="100 ms" },
			{ value=200, name="200 ms" },
			{ value=300, name="300 ms" },
			{ value=500, name="500 ms" },
			{ value=1000, name="1 s" },
			{ value=2000, name="2 s" },
			{ value=3000, name="3 s" }
		}
	})
	return true
end
--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["getSettings"] = API_getSettings
dset.APIS["modifySettings"] = API_modifySettings
dset.APIS["smoothOptions"] = API_smoothOptions
--------------------------------------
return dset

