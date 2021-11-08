local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
}
--------------------------------------
local function get(skip)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.GetStatus()
		proxy:Destroy()
		if not r or not more then
			MSG.ERROR("getCodecStatError")
		else
			if skip then
				more.de_interlace = more.deInterlace
				more.deInterlace = nil
				more.audio_format = more.audio
				more.audio = nil
				more.inst_frame_rate = more.frame_rate
				local h, d, rate = string.match(more.resolution, "p (.+)Hz")
				more.frame_rate = h and d and rate or 0
			end
			MSG.OK("",{data=more})
		end
		return true
	end
end

local function API_get()
	return get()
end

local function API_get_ext()
	return get(true)
end

--------------------------------------
local function API_add(red, args)
	local id
	if not args or not args.id then
		MSG.ERROR( "invalidPresetIdError" )
		return true
	end

	id = tostring(args.id)

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,done 
		if id == "0" or id == "10" then
			r,done = proxy.SelectBlank()
		else
			r,done = proxy.SelectPreset(id)
		end
		proxy:Destroy()
		if not r or not done then
			MSG.ERROR("Failure to select preset " .. id )
		else
			MSG.OK()
		end
		return true
	end
end
--------------------------------------
local function API_addSpec(red, args)
	local name, url, group
	if not args or not args.name or not args.url then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	name = args.name
	url = args.url
	group = args.group or ""

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,done = proxy.SetCurrent(name, url, "full", group)
		proxy:Destroy()
		if not r or not done then
			MSG.ERROR("setCurrentError")
		else
			MSG.OK()
		end
		return true
	end
end
--------------------------------------

local function API_set(_, args)
	local id = tonumber(args.id)
	if id then
		if id < 0 or id > 9 or id ~= math.ceil(id) then
			MSG.ERROR("invalidArgError")
			return true
		end
		return API_add(_, args)
	end

	return API_addSpec(_, args)
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["addSpec"] = API_addSpec
dset.APIS["add"] = API_add
dset.APIS["status"] = API_get_ext
dset.APIS["set"] = API_set
--------------------------------------
return dset

