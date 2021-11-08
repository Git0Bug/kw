local sysinfo = require "api_sysinfo"
local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {}

local function API_server_info(red, args)
	local cpu_c = sysinfo.GetCpuCores()
	local cpu_p, cpu_i = sysinfo.GetCpuLoad()
	local mem_f, mem_t = sysinfo.GetMemUse()
	local pers_m, pers_t = sysinfo.GetPersisTime()

	local info = {
		addr = ngx.var.server_addr,
		name = ngx.var.scheme .. "://" .. ngx.var.host,
		port = ngx.var.server_port,
		persis = "" .. math.floor(pers_m/3600) .. "H " .. math.floor((pers_m%3600)/60) .. "M " .. math.floor(pers_m%60) .. "S",
		start_time = string.format( "%04d-%02d-%02d %02d:%02d:%02d", pers_t.year, pers_t.month, pers_t.day, pers_t.hour, pers_t.min,  pers_t.sec ),
		cpu_cores = cpu_c,
		cpu_payload = math.floor(cpu_p*100)/100,
		mem_used = math.floor( ((mem_t - mem_f)/1024)*100 )/100,
		mem_total = math.floor( (mem_t/1024)*100 ) / 100
	}

	MSG.OK( "", { data = info } )
	return true
end

local function API_reset(red,args)
	local proxy = CO.GetProxy( "/", "systemctrl" )
	if not proxy then
		MSG.ERROR( "systemError" )
		return true
	else
		proxy.Reset()
		proxy:Destroy()
		MSG.OK()
		return true
	end
end

local function API_reboot(red,args)
	local proxy = CO.GetProxy( "/", "systemctrl" )
	if not proxy then
		MSG.ERROR( "systemError" )
	else
		local dev = require "api_device"
		dev.REBOOTING = true
		proxy.Reboot(2)
		proxy:Destroy()
		MSG.OK()
		return true
	end
	return true
end

local function API_restore(red,args)
	local proxy = CO.GetProxy( "/", "systemctrl" )
	if not proxy then
		MSG.ERROR( "systemError" )
	else
		local dev = require "api_device"
		dev.REBOOTING = true
		proxy.RestoreFactory()
		proxy:Destroy()
		MSG.OK()
	end
	return true
end

local function API_reconnect()
	local proxy = CO.GetProxy("/", "codec")
	if not proxy then
		MSG.ERROR("codecError")
		return true
	end

	local is_ok = proxy.Reset()
	proxy:Destroy()
	if not is_ok then
		MSG.ERROR("connectNdiError")
		return true
	end
	
	MSG.OK("")
	return true
end

-----------------------------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["server_info"] = API_server_info
dset.APIS["reset"] = API_reset
dset.APIS["reboot"] = API_reboot
dset.APIS["restore"] = API_restore
dset.APIS["reconnect"] = API_reconnect

return dset

