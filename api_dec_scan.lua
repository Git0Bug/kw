local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
}
--------------------------------------
local function API_scan(red, args)
	local proxy = CO.GetProxy( "/discovery", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		if args and args.force then
			proxy.ForceRefresh()
		end

		local r,more = proxy.GetNDISources()
		proxy:Destroy()
		if not r or type(more) ~= "table" then
			MSG.ERROR( "Failure to get discovery list" )
		else
			local rslt = {}
			local k,v
			for k,v in pairs(more) do
				v.group_name = v.group
				local dname, cname = v.name:match("(.-)%s+%((.+)%)")
				if not dname then
					v.device_name = v.name
					v.channel_name = "unknown"
				else
					v.device_name = dname
					v.channel_name = cname
				end
				v.series = "NDI" --TODO
				v.enable = 1
				v.url = v.original_url
				table.insert(rslt,v)
			end
			table.sort( rslt, function(a,b)
				if not a or not b or a == b then
					return false
				end
				if a.device_name and b.device_name and a.device_name ~= b.device_name then
					return a.device_name < b.device_name
				else
					return a.channel_name < b.channel_name
				end
			end)

			local group_rslt={}
			local prev_group = nil
			local prev_groupname = nil

			for k=1, #rslt do
				rslt[k].id = tostring(k)

				if not prev_group or prev_groupname ~= rslt[k].device_name then
					prev_group = rslt[k]
					prev_groupname = rslt[k].device_name
					table.insert(group_rslt, prev_group)
				else
					if not prev_group.children then
						prev_group.children = {}
						prev_group.children_num = 1
					end
					prev_group.children_num = prev_group.children_num + 1
					rslt[k].device_name = nil --Remove the device name.
					table.insert( prev_group.children, rslt[k] )
				end
			end

			MSG.OK("", {
				data = group_rslt, data_size = #group_rslt
			})
		end
		return true
	end
end

--------------------------------------
local function API_addManualIp(red, args)
	if type(args) ~= "table" then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.SetDiscoveryManuals(args.ip, args.group_name)
		proxy:Destroy()
		if not r or not more then
			MSG.ERROR( "Failure to set discovery manual IP list" )
		else
			MSG.OK()
		end
		return true
	end
end

--------------------------------------
local function API_getManualIps(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,ips = proxy.GetDiscoveryManuals()
		proxy:Destroy()
		if not r or type(ips) ~= "table" then
			MSG.ERROR( "Failure to get discovery manual IP list" )
		else
			MSG.OK("", {
				data = ips
			})
		end
		return true
	end
end

--------------------------------------
local function API_getManualIpsGroups()
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, ips, groups = proxy.GetDiscoveryManuals()
		proxy:Destroy()
		if not r or type(ips) ~= "table" or not groups or type(groups) ~= "table" then
			MSG.ERROR( "Failure to get discovery manual IP list" )
		else
			MSG.OK("", {
				data = {ip = ips, group_name = groups}
			})
		end
		return true
	end
end

--------------------------------------
local function API_setGroup(red, args)
	local group
	if not args or not args.group_name or args.group_name == "" then
		group = "public"
	else
		group = args.group_name
	end

	local proxy = CO.GetProxy( "/discovery", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.SetGroup(group)
		proxy:Destroy()
		if not r then
			MSG.ERROR( "Failure to set discovery group" )
		else
			MSG.OK()
		end
		return true
	end
end

--------------------------------------
local function API_getGroups(red, args)
	local proxy = CO.GetProxy( "/discovery", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.GetNDIGroups()
		proxy:Destroy()
		if not r or type(more) ~= "table" then
			MSG.ERROR( "Failure to get discovery groups" )
		else
			local rslt = {}
			local k,v
			for k,v in ipairs(more) do
				table.insert(rslt,v)
			end
			MSG.OK("", {
				data = rslt
			})
		end
		return true
	end
end

--------------------------------------
local function API_groupChecked(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,_ips,more = proxy.GetDiscoveryManuals()
		proxy:Destroy()
		if not r or type(more) ~= "table" then
			MSG.ERROR( "Failure to get discovery manual groups" )
		else
			MSG.OK("", {
				data = more
			})
		end
		return true
	end
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["scan"] = API_scan
dset.APIS["addManualIp"] = API_addManualIp
dset.APIS["getManualIps"] = API_getManualIps
dset.APIS["getGroups"] = API_getGroups
dset.APIS["groupChecked"] = API_groupChecked
dset.APIS["setGroup"] = API_setGroup
dset.APIS["get"] = API_scan
dset.APIS["set_manual_targets"] = API_addManualIp
dset.APIS["get_manual_targets"] = API_getManualIpsGroups

--------------------------------------
return dset

