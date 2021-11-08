local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {}
--------------------------------------
local function API_get(red, args)
	local proxy = CO.GetProxy( "/", "networkmanager" )
	local cfg_proxy = CO.GetProxy( "/config/nm", "networkmanager" )
	if not proxy or not cfg_proxy then
		MSG.ERROR( "networkError" )
		return true
	end

	local r
	local eth0
	r, eth0 = proxy.GetLinkDetail("eth0")
	if not r then
		MSG.ERROR( "Failure to get ethernet configuration" )
		return true
	end

	proxy:Destroy()

	local aliases = cfg_proxy._P("aliases")
	cfg_proxy:Destroy()

	local alias_eth0 = aliases and aliases.eth0 or {}

	local retData={
		{
			device = "eth0",
			state = eth0.status,
			ip = eth0.address,
			mask = eth0.netmask,
			mac = eth0.mac,
			gw = eth0.gw,
			dynamic = eth0.method == "dhcp" and "y" or "n",
			dns = eth0.dns and eth0.dns[1] or "",

			ip2 = alias_eth0.address or "0.0.0.0",
			mask2 = alias_eth0.netmask or "255.255.255.0",
			gw2 = alias_eth0.gw or "",

			ip3 = alias_eth0.address2 or "0.0.0.0",
			mask3 = alias_eth0.netmask2 or "255.255.255.0",
			gw3 = alias_eth0.gw2 or ""
		}
	}

	if type(eth0.dns) == "table" then
		local x = ""
		local i
		for i=1, #eth0.dns do
			if i == 1 then
				x = eth0.dns[i]
			else
				x = x .. "; " .. eth0.dns[i]
			end
		end
		retData[1].dns = x
	end

	MSG.OK( "", { data = retData, data_size = #retData } )
	return true
end

--------------------------------------

local function API_modify(red, args)
	-- args:e.g. device=eth0
	if args and args.device then
		local proxy = CO.GetProxy( "/config/nm", "networkmanager" )
		if not proxy then
			MSG.ERROR( "networkError" )
			return true
		end

		local is_dhcp = args.dynamic and args.dynamic == "y"
		local sets = {
			["ethernets." .. args.device .. ".method"] = args.dynamic and (args.dynamic == "y" and "dhcp" or "static") or nil,
			["aliases." .. args.device .. ".address" ] = args.ip2,
			["aliases." .. args.device .. ".netmask" ] = args.mask2,
			["aliases." .. args.device .. ".gw" ] = args.gw2,
		}
		if args.ip3 then
			sets["aliases." .. args.device .. ".address2" ] = args.ip3
		end
		if args.mask3 then
			sets["aliases." .. args.device .. ".netmask2" ] = args.mask3
		end
		if args.gw3 then
			sets["aliases." .. args.device .. ".gw2" ] = args.gw3
		end

		if not is_dhcp then
			sets["ethernets." .. args.device .. ".address"] = args.ip
			sets["ethernets." .. args.device .. ".netmask"] = args.mask
			if args.mac and args.mac ~= "" then
				sets["ethernets." .. args.device .. ".mac"] = args.mac
			end
			sets["ethernets." .. args.device .. ".gw"] = args.gw
			if args.dns then
				local dns = args.dns
				dns = dns .. ";"
				local dns_list = {}
				local it
				for it in dns:gmatch("(.-)[; \t]+") do
					if it ~= "" then
						table.insert( dns_list, it )
					end
				end
				--[[
				if #dns_list > 0 then
				for it=1, #dns_list do
				sets["ethernets." .. args.device .. ".dns[" .. it .. "]" ] = dns_list[it]
				end
				end
				]]
				sets["ethernets." .. args.device .. ".dns" ] = dns_list
			end
		end

		local r,rr = proxy:P_SET(sets)
		proxy:Destroy()
		if not r or not rr then
			MSG.ERROR( "Failure to change network settings" )
		else
			MSG.OK("")
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

local function API_detect_addr2(red, args)
	local cfg_proxy = CO.GetProxy( "/config/nm", "networkmanager" )
	if not cfg_proxy then
		MSG.ERROR( "networkError" )
		return true
	end

	local aliases = cfg_proxy._P("aliases")
	cfg_proxy:Destroy()

	MSG.OK("", {
		data = {
			enable = (aliases and aliases.eth0 and aliases.eth0.enable and aliases.eth0.address ~= "" and aliases.eth0.address ~= "0.0.0.0" ) and 1 or 0
		}
	})

	return true
end


local function API_disable_addr2(red, args)
	if args and args.disable and tonumber(args.disable) == 1 then
		local proxy = CO.GetProxy( "/config/nm", "networkmanager" )
		if not proxy then
			MSG.ERROR( "networkError" )
			return true
		end

		local sets = {
			["aliases.eth0.enable" ] = false
		}

		local r,rr = proxy:P_SET(sets)
		proxy:Destroy()
		if not r or not rr then
			MSG.ERROR( "Failure to change network settings" )
		else
			MSG.OK("")
		end

		--Reset the NDI discovery tasks (any case)
		proxy = CO.GetProxy( "/discovery", "codec" )
		if proxy then
			proxy.Reset()
			proxy:Destroy()
		end
	else
		MSG.OK("")
	end
	return true
end

local function API_ping(red, args)
	if not args.ip then
		MSG.ERROR("invalidArgError")
		return true
	end

	--TODO:
	MSG.OK( "Address reachable" )
	return true
end

local function API_ipList(red, args)
	local data={"192.168.0.1","8.8.8.8","www.google.com"}
	MSG.OK( "",{data=data} )
	return true
end

local function API_set_protocol(_, args)
	local http, httpPort, https, httpsPort = args.http, tonumber(args.httpPort), args.https, tonumber(args.httpsPort)
	if not http and not https then
		MSG.ERROR("You must choose something in checkbox")
		return true
	end

	local proxy = CO.GetProxy("/", "systemctrl")
	if not proxy then
		MSG.ERROR( "systemError" )
		return true
	end
	proxy.SetWebPort(httpPort, httpsPort, http or false, https or false)
	proxy:Destroy()
	MSG.OK("")
	return true
end

local function API_get_protocol()
	local proxy = CO.GetProxy("/", "systemctrl")
	if not proxy then
		MSG.ERROR( "systemError" )
		return true
	end
	local is_ok, result = proxy.GetWebPort()
	if not is_ok then
		MSG.ERROR( "getWebPortError" )
		return true
	end
	MSG.OK("", {data = {
		http = result.http_enable,
		httpPort = result.http_port,
		https = result.https_enable,
		httpsPort = result.https_port,
	}})
	return true
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["ipList"] = API_ipList
dset.APIS["ping"] = API_ping
dset.APIS["modify"] = API_modify
dset.APIS["detect_addr2"] = API_detect_addr2
dset.APIS["disable_addr2"] = API_disable_addr2
dset.APIS["set"] = API_modify
dset.APIS["setProtocol"] = API_set_protocol
dset.APIS["getProtocol"] = API_get_protocol

--------------------------------------
return dset

