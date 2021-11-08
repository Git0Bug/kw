local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {
	CACHED_SERIAL_NO = nil,
	REBOOTING = false
}
--------------------------------------
local function API_get(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, group_name, dev_name, chn_name = proxy.GetNameWithGroup()
		local r2, ndi_conn, mcast_pfx, mcast_mask, ttl = proxy.GetNDIConnection()
		local r3, enc_quality = proxy.GetEncQuality()
		local dis_signal_id = false
		r3, dis_signal_id = proxy.GetDisableSignalTallyId()
		if r and dev_name and chn_name then
			MSG.OK("", {
				data = {
					device_group = group_name,
					channel_name = chn_name,
					device_name = dev_name,
					quality = r3 and enc_quality or 100,
					ndi_connection = ndi_conn or "tcp",
					netprefix = mcast_pfx or "239.255.0.0",
					netmask = mcast_mask or "255.255.0.0",
					ttl = tonumber(ttl) or 127,
					disable_signal_id = dis_signal_id
				}
			})
		else
			MSG.ERROR( "Failure to get device configurations" )
		end
		proxy:Destroy()
		return true
	end
end

--------------------------------------
local audio_channel_names = {
	[0] = "Auto",
	[1] = "Mono",
	[2] = "Stereo"
}
--------------------------------------

local function API_status(red, args)
	if dset.REBOOTING then
		MSG.ERROR( "REBOOTING" )
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		if not dset.CACHED_SERIAL_NO then
			local f = io.open( "/boot/SERIAL_NO", "r" )
			if f then
				dset.CACHED_SERIAL_NO = f:read("*l")
				f:close()
			end
		end

		local r, status = proxy.GetStatus()
		if r and status then
			local audio_signal
			if not status.audio_signal then
				audio_signal = "none"
			elseif status.audio_signal == "hdmi" or status.audio_signal == "sdi" or status.audio_signal == "digital" or status.audio_signal == "embedded" then
				audio_signal = "embedded"
			elseif status.audio_signal == "line" or status.audio_signal == "linein" or status.audio_signal == "line-in" or status.audio_signal == "mic" or status.audio_signal == "micin" or status.audio_signal == "mic-in" or status.audio_signal == "analog" then
				audio_signal = "analog"
			else
				audio_signal = status.audio_signal
			end

			local audio_chn = tonumber(status.channels) or 2

			MSG.OK("", {
				data = {
					resolution = status.resolution,
					frame_rate = status.frame_rate,
					bitrate = status.bitrate,
					audio_format = (status.sampling or 48000) .. "Hz/" .. (audio_channel_names[audio_chn] or ("" .. audio_chn .. " CH")),
					serial_number = dset.CACHED_SERIAL_NO or "000000000",

					video_signal = status.video_signal,
					audio_channels = audio_chn,
					audio_sampling = status.sampling,
					audio_signal = audio_signal,
					interlaced = status.interlaced,
					xRes = status.xRes,
					yRes = status.yRes,
				}
			})
		else
			MSG.ERROR( "Failure to get device status" )
		end
		proxy:Destroy()
		return true
	end
end

--------------------------------------

local function API_get_audio()
	if dset.REBOOTING then
		MSG.ERROR( "REBOOTING" )
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	end
	
	local is_ok, audio_source = proxy.GetAudioSource()
	if not is_ok then
		MSG.ERROR("Failure to get status")
		return true
	end

	local is_ok, audio_gain = proxy.GetAudioGain()
	if not is_ok then
		MSG.ERROR("Failure to get status")
		return true
	end

	local audio_signal
	if not audio_source then
		audio_signal = "none"
	elseif audio_source == "hdmi" or audio_source == "sdi" or audio_source == "digital" or audio_source == "embedded" then
		audio_signal = "embedded"
	elseif audio_source == "line" or audio_source == "linein" or audio_source == "line-in" or audio_source == "mic" or audio_source == "micin" or audio_source == "mic-in" or audio_source == "analog" then
		audio_signal = "analog"
	else
		audio_signal = audio_source
	end
	MSG.OK("", {data = {
		signal = audio_signal,
		volume = audio_gain or 100,
	}})
	
	proxy:Destroy()
	return true
end

--------------------------------------

local function API_set_audio(_, args)
	if not args.signal and not args.volume then
		MSG.ERROR("invalidArgError")
		return true
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	end

	local is_ok, skip
	if args.signal then
		args.signal = args.signal == "embedded" and "hdmi" or "linein"
		is_ok, skip = proxy.SelectAudioSource(args.signal)
		if not is_ok or not skip then
			MSG.ERROR("Failure to set audio signal")
			return true
		end
	end

	if args.volume then
		local volume = tonumber(args.volume) or -1
		if volume < 0 or volume > 200 then
			MSG.ERROR("Invalid  volume arguments !")
			return true
		end

		is_ok, skip = proxy.SetAudioGain(volume)
		if not is_ok or not skip then
			MSG.ERROR("Failure to set audio volume")
			return true
		end
	end
	MSG.OK("")
	return true
end

--------------------------------------

local function API_modify(red, args)
	if args then
		local proxy = CO.GetProxy( "/", "codec" )
		if not proxy then
			MSG.ERROR( "codecError" )
			return true
			--[[		else
			if args.device_name or args.channel_name then
			local r, status = proxy.SetName( args.device_name, args.channel_name )
			if not r then
			proxy:Destroy()
			MSG.ERROR( "Failure to set NDI device/channel name" )
			return true
			end
			end

			if args.ndi_connection then
			local r, status = proxy.SetNDIConnection( args.ndi_connection, args.netprefix, args.netmask )
			if not r then
			proxy:Destroy()
			MSG.ERROR( "Failure to set NDI connection type" )
			return true
			end
			end
			proxy:Destroy()
			MSG.OK("")
			return true
			end
			]]
		else
			if args.device_group or args.device_name or args.channel_name then
				local r, status = proxy.SetNameWithGroup( args.device_group or "", args.device_name or "", args.channel_name )
				if not r then
					proxy:Destroy()
					MSG.ERROR( "Failure to set NDI group/device/channel name" )
					return true
				end
			end

			if args.quality then
				local r, status = proxy.SetEncQuality( tonumber(args.quality) )
				if not r then
					proxy:Destroy()
					MSG.ERROR( "Failure to set encoding quality" )
					return true
				end
			end

			if args.ndi_connection then
				local r, status = proxy.SetNDIConnection( args.ndi_connection, args.netprefix, args.netmask, args.ttl )
				if not r then
					proxy:Destroy()
					MSG.ERROR( "Failure to set NDI connection type" )
					return true
				end
			end

			if type(args.disable_signal_id) ~= "nil" then
				local r, status = proxy.SetDisableSignalTallyId( args.disable_signal_id )
				if not r then
					proxy:Destroy()
					MSG.ERROR( "Failure to set signal tally identifier" )
					return true
				end
			end

			proxy:Destroy()
			MSG.OK("")
			return true
		end

	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

--------------------------------------
local function API_serial(red, args)
	if args and args.serial_number and args.serial_number ~= "" then
		if not args.server or args.server == "" then
			MSG.ERROR( "serverArgsError" )
			return true
		end

		local r, DNA
		local proxy = CO.GetProxy( "/", "codec" )
		if not proxy then
			MSG.ERROR("codecError")
			return true
		else
			r, DNA = proxy.GetDNANumber()
			proxy:Destroy()
		end

		if not DNA then
			MSG.ERROR("getDNAError")
			return true
		end

		proxy = CO.GetProxy( "/", "auth_server", "local", 10, args.server )
		if not proxy then
			MSG.ERROR( "Unable to connect to the authorization server " .. args.server )
			return true
		end

		local SIGN
		r, SIGN = proxy.Auth( args.serial_number, DNA )
		proxy:Destroy()

		if not SIGN then
			MSG.ERROR( "signCheckError" )
			return true
		end

		proxy = CO.GetProxy( "/", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemSerError" )
			return true
		else
			dset.CACHED_SERIAL_NO = nil
			proxy.CreateSerialNo( args.serial_number, SIGN )
			proxy:Destroy()
			MSG.OK( "Create serial number DONE!" )
		end
	else
		MSG.ERROR("invalidArgError")
	end
	return true
end

-------------

local function API_set_discovery_server(red, args)
	if args and type(args.enable) ~= "nil" then
		local proxy = CO.GetProxy( "/", "codec" )
		if not proxy then
			MSG.ERROR( "codecError" )
			return true
		else
			local en = tonumber(args.enable)
			if en then
				en = (en ~= 0)
			else
				if args.enable == "true" then
					en = true
				else
					en = false
				end
			end

			local r, status = proxy.SetDiscoveryServer( en, args.address or "" )
			if not r then
				proxy:Destroy()
				MSG.ERROR( "setDiscoveryError" )
				return true
			end

			proxy:Destroy()
			MSG.OK("")
			return true
		end

	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

local function API_get_discovery_server(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, en, addr = proxy.GetDiscoveryServer()
		if not r then
			proxy:Destroy()
			MSG.ERROR("getDiscoveryError")
			return true
		end
		proxy:Destroy()

		MSG.OK("",{
			data = {
				enable = en or false,
				address = addr or ""
			}
		})
		return true
	end
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["status"] = API_status
dset.APIS["modify"] = API_modify
dset.APIS["serial"] = API_serial
dset.APIS["get_config"] = API_get
dset.APIS["set_config"] = API_modify
dset.APIS["get_audio"] = API_get_audio
dset.APIS["set_audio"] = API_set_audio
dset.APIS["get_discovery_server"] = API_get_discovery_server
dset.APIS["set_discovery_server"] = API_set_discovery_server

--------------------------------------
return dset
