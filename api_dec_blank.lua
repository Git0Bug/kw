local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
}
--------------------------------------
local function API_modify(red, args)
	if not args or not args.BlankColor then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.SetBlankColor(args.BlankColor)
		proxy:Destroy()
		if not r or not more then
			MSG.ERROR( "blankSetError" )
		else
			MSG.OK()
		end
		return true
	end
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["modify"] = API_modify
--------------------------------------
return dset

