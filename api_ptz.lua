local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {}




local function API_get(red, args)
	local proxy = CO.GetProxy( "/ptz", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, data,err = proxy.GetPtzInfo()
		if r and data then
			if data.serial.device then
				data.serial.device = data.serial.device:match("/dev/(.*)")
			end
			if not data.serial.device then
					data.serial.device = "none"
			end

			MSG.OK("",{data=data})
		else
			MSG.ERROR("queryPTZError")
		end
		proxy:Destroy()
		return true
	end
end


local function API_modify(red, args)
	if not args or not args.enable or not args.typ  then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local proxy = CO.GetProxy( "/ptz", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local main_tabs = {}
		main_tabs.enable=tonumber(args.enable)
		main_tabs.typ=args.typ
		local tabs = {}
		tabs.addr=args.addr
		tabs.ptz_addr=args.ptz_addr
		tabs.protocol=args.protocol
		tabs.ptz_protocol=args.ptz_protocol
		tabs.port=tonumber(args.port)

		tabs.rtscts=tonumber(args.rtscts)
		tabs.startBits=tonumber(args.startBits)
		tabs.parity=args.parity
		tabs.xonxoff=tonumber(args.xonxoff)
		if args.device and args.device ~="none" then
			tabs.device="/dev/" .. args.device
		else
			tabs.device = "none"
		end
		tabs.endBits=tonumber(args.endBits)
		tabs.baudrate=tonumber(args.baudrate)
		main_tabs[args.typ] = tabs
		local r, data,err = proxy.Modify(main_tabs)
		if r and data then
			MSG.OK("")
		else
			MSG.ERROR("setPTZError")
		end
		proxy:Destroy()
		return true
	end
end

local function API_ptzList(red, args)
	local proxy = CO.GetProxy( "/ptz", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, data,err = proxy.GetPtzProtocol()
		if r and data then
			MSG.OK("",{data=data})
		else
			MSG.ERROR( "queryPTZproError" )
		end
		proxy:Destroy()
		return true
	end
end

local function API_serialList(red, args)
	local proxy = CO.GetProxy( "/ptz", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, data,err = proxy.Getdevices()
		if r and data then
			MSG.OK("",{data=data})
		else
			MSG.ERROR( "querySerError" )
		end
		proxy:Destroy()
		return true
	end
end 
--------------
--
dset.APIS = dset.APIS or {}
--
dset.APIS["get"] = API_get
dset.APIS["ptzList"] = API_ptzList
dset.APIS["serialList"] = API_serialList
dset.APIS["modify"] = API_modify
--
return dset
--
