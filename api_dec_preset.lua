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
		local r,more = proxy.GetPresets()
		if not r or not more then
			proxy:Destroy()
			MSG.ERROR( "getPresetError" )
		else
			local current
			r, current = proxy.GetCurrentSettings()
			if not r or type(current) ~= "table" then
				current = nil
			end
			local blank_color
			r,blank_color = proxy.GetBlankColor()
			proxy:Destroy()
			if not r or not blank_color then
				blank_color = "#000000"
			end

			local rslt={}
			local id
			for id=1,9 do
				local k,fnd
				for k=1,#more do
					if more[k].id == id or more[k].id == tostring(id) then
						fnd = more[k]
						break
					end
				end
				if not fnd then
					fnd = {
						id = tostring(id),
						name = "",
						group = "",
						group_name = "",
						device_name = "",
						channel_name = "",
						ip = "",
						url = "",
						online = "",
						enable = 0
					}
				else
					fnd.id = tostring(id)
					fnd.group_name = fnd.group
					if fnd.name and fnd.name ~= "" then
						fnd.enable = 1
					else
						fnd.enable = 0
					end
					fnd.online = fnd.online and "on" or "off"
				end
				if current and current.preset_id == tostring(id) then
					fnd.current = true
				end
				table.insert(rslt,fnd)
			end

			if skip then
				table.insert(rslt, {
					id = "0",
					current = current and current.preset_id == "0",
					color = blank_color,
				})
			else
				table.insert(rslt, {
					id = "10",
					current = current and current.preset_id == "0",
					BlankColor = blank_color,
				})
			end

			MSG.OK("",{
				data = rslt, data_size = #rslt
			})
		end
		return true
	end
end

local function API_get_ext()
	return get(true)
end

local function API_get()
	return get()
end

--------------------------------------
local function API_remove(red, args)
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
		local r,done = proxy.RemovePreset(id)
		proxy:Destroy()
		if not r or not done then
			MSG.ERROR("Failure to remove preset " .. id )
		else
			MSG.OK()
		end
		return true
	end
end
--------------------------------------
local function API_add(red, args)
	local id, name, url, group
	if not args or not args.position or not args.name or not args.url then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	id = tostring(args.position)
	name = args.name
	url = args.url
	group = args.group or ""

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,done = proxy.AddPreset(id, name, url, group)
		proxy:Destroy()
		if not r or not done then
			MSG.ERROR("Failure to add preset " .. id )
		else
			MSG.OK()
		end
		return true
	end
end

--------------------------------------

local function API_set_blank(_, args)
	if not args.color then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local blank_mod = require "api_dec_blank"
	local func = blank_mod.APIS["modify"]

	return func(nil, {BlankColor = args.color})
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["remove"] = API_remove
dset.APIS["add"] = API_add
dset.APIS["status"] = API_get_ext
dset.APIS["set_blank"] = API_set_blank
--------------------------------------
return dset

