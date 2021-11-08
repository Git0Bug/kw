local coaf=require "coaf.core"
local _dbg = require "coaf.debug"
local thread = require "coaf.thread"
local avio_chips = require "chips.avio"
local ndi_config = require "ndi_config"
local posix_time = require "posix.time"
local io_leds = require "io_leds"
local client = require "coaf.client"
require "ndi_encoding"
local _x, features = pcall(require, "features")
if not _x or type(features) ~= "table" then
	features = {}
end

local DEBUG_LEVEL = 4
local CONFIG_LOCATION = "/data/configs"

local eReg_NDI_Encode = 0x000
local eReg_Video = 0x200
local eReg_Preview = 0x210
local eReg_Audio = 0x220
local eReg_Version = 0x300

local vidCap_eControl = 0
local vidCap_eReserved1 = 1

local vidCap_eClkFreq = 1 --Same as eReserved1
local CLK_MUL = 100

local vidCap_eAddress = 2
local vidCap_eReserved2 = 3
local vidCap_eIRQControl = 3 --Same as eReserved2

local vidCap_eControl_Byte_Enable		= 0
local vidCap_eControl_Byte_Format		= 1
local vidCap_eControl_Byte_IRQ_Enable	= 2
local vidCap_eControl_Byte_IRQ_Status	= 3

local _M = {
	cfg = nil,
	ndi_started = nil,

	video_fmt_ver = nil,
	audio_fmt_ver = nil,

	video_exact_detail = {},
	audio_exact_detail = {},

	delay_group_name = nil,
	delay_device_name = nil,
	delay_channel_name = nil,
	delay_name_time = nil,

	current_ip = nil,
	last_ipcheck_time = nil,

	web_protocol = "http://",
	web_port = "",

	EULA_accepted = false
}

-------------------------------------------------
local function check_default_ip()
	local rslt
	local f = io.popen( "/sbin/ifconfig eth0", "r" )
	if f then
		local l = f:read("*l")
		while l do
			local ip = l:match("inet addr:(%d+%.%d+%.%d+%.%d+)")
			if ip then
				rslt = ip
				break
			end
			l = f:read("*l")
		end
		f:close()
	end

	return rslt
end
-------------------------------------------------

local function getHostname()
	local f = io.popen( "/bin/hostname", "r" )
	if f then
		local l = f:read("*l")
		f:close()
		return l
	else
		return nil
	end
end


local function get_mediaserver_proxy()
	local proxy
	local cli
	cli = client.New( "mediaserver", "local", nil, 5 ) --5 seconds timeout.
	if not cli then
		_dbg.Error( "SYS-AUTH", "Fail to create connection to service 'local/mediaserver'" )
		return nil
	end
	proxy = cli:CreateProxy("/streamer", true) --Exclusive
	if not proxy then
		_dbg.Error( "SYS-AUTH", "Fail to create object proxy for '/streamer@local/mediaserver'" )
		cli:Destroy()
		return nil
	end
	return proxy
end

-------------------------------------------------
local function get_sysauth_proxy()
	local proxy
	local cli
	cli = client.New( "systemctrl", "local", nil, 5 ) --5 seconds timeout.
	if not cli then
		_dbg.Error( "SYS-AUTH", "Fail to create connection to service 'local/systemctrl'" )
		return nil
	end
	proxy = cli:CreateProxy("/auth", true) --Exclusive
	if not proxy then
		_dbg.Error( "SYS-AUTH", "Fail to create object proxy for '/auth@local/systemctrl'" )
		cli:Destroy()
		return nil
	end
	return proxy
end

-------------------------------------------------

function _M.CreateDynamicUser()
	local rand_f = io.popen( "/usr/bin/uuidgen | /usr/bin/md5sum", "r" )
	if not rand_f then
		_dbg.Error( "SYS-AUTH", "Fail to generate a random user ID for dynamic authentication!" )
		return
	end
	local id = rand_f:read("*l")
	rand_f:close()
	if id then
		id = id:match("%x+")
	end
	if not id then
		_dbg.Error( "SYS-AUTH", "Fail to get a valid random user ID for dynamic authentication!" )
		return
	end

	local proxy = get_sysauth_proxy()
	if not proxy then
		return
	end

	local done, user = proxy.CreateDynamicUser( "web", id, { role="user", name="NewTek", password = "IsTheNDIInventor" } )
	if not done or not user then
		_dbg.Error( "SYS-AUTH", "Fail to create a random user ID for dynamic authentication!" )
		proxy:Destroy()
		return
	end
	proxy:Destroy()

	rand_f = io.popen( "/bin/echo -n NewTekSanAntonio:" .. id .. ":IsTheNDIInventor | /usr/bin/md5sum", "r" )
	if not rand_f then
		_dbg.Error( "SYS-AUTH", "Fail to create a dynamic authentication token!" )
		return
	end

	id = rand_f:read("*l")
	rand_f:close()
	if id then
		id = id:match("%x+")
	end

	if not id then
		_dbg.Error( "SYS-AUTH", "Fail to get a valid dynamic authentication token!" )
		return
	end
	
	_M.NtkUrl = "/newtek?session-id=" .. user .. "&amp;auth-token=" .. id
	_M.NtkAcceptEULA = "/api/users/accept_eula.json?session-id=" .. user .. "&amp;auth-token=" .. id

	_dbg.Info( "SYS-AUTH", "Dynamic authentication is enabled. (", _M.NtkUrl, _M.NtkAcceptEULA, ")" )
end


function _M.Init()
	_M.cfg = ndi_config.Load()
	--NOTE: For purpose, if serial number is 'xx16xxxxxx', enable 4Kp60.
	local f = io.open( "/boot/SERIAL_NO", "r" )
	if f then
		local l = f:read("*l")
		if l and l:match("^..16") then
			_G.DISABLE_4Kp60 = false
		end
		f:close()
	end

	--First step, start mDNS service.
	_M.StartMDNSService()

	--After call 'Step()', it will configure then NDI encoding then start it.
	
	local dna_l = NDI.read_reg( eReg_Version, 1 )
	local dna_h = NDI.read_reg( eReg_Version, 2 )
	if dna_h and dna_l then
		_M.DNA = string.format( "%08x%08x", dna_h, dna_l )
		_dbg.Info( "CODEC", "FPGA DNA number is:", _M.DNA )
	else
		_dbg.Warn( "CODEC", "Fail to get FPGA DNA number!" )
	end

	local f = io.open( CONFIG_LOCATION .. "/EULA/global_accepted", "r" )
	if f then
		_M.EULA_accepted = true
		NDI.show_EULA( false )
		f:close()
	else
		NDI.show_EULA( true )
	end

	--First get the web server configurations.
	local try_files = { "/var/run/webport.conf", CONFIG_LOCATION .. "/webport.conf" }
	for _i, file in ipairs(try_files) do
		f = io.open( file, "r")
		if f then
			local args={}
			for line in f:lines() do
				local key, val = line:match("([^=]*)=(.*)$")
				if key then
					args[key]=val
				end
			end
			f:close()

			if (not args.DISABLE_HTTP) or args.DISABLE_HTTP == "" then
				_M.web_protocol = "http://"
				local x = tonumber(args.HTTP_PORT)
				if x and x ~= 80 then
					_M.web_port = ":" .. x
				end
			elseif (not args.DISABLE_HTTPS) or args.DISABLE_HTTPS == "" then
				_M.web_protocol = "https://"
				local x = tonumber(args.HTTPS_PORT)
				if x and x ~= 443 then
					_M.web_port = ":" .. x
				end
			end

			break
		end
	end

	avio_chips.Init("encoding")
	io_leds.Init()
	io_leds.SetDisableSignalTallyId(_M.cfg.disable_signal_tally_id)
	local ptz_cfg = require("PtzManager.configs.ptz_configs").Load()
	if ptz_cfg.enable == 1 then
		NDI.set_enable_ptz(true)
	end

	_M.CreateDynamicUser()
end

--Switch encoding/decoding mode.
function _M.SwitchMode(mode)
	if _G.glb_cfg and mode then
		if _G.glb_cfg.working ~= mode then
			_G.glb_cfg.working = mode
			_G.glb_cfg:__TRIGGER(true)
			return true, "changed"
		else
			return true
		end
	else
		return false
	end
end

function _M.GetMode()
	if _G.glb_cfg then
		return _G.glb_cfg.working
	else
		return "encoding"
	end
end

local function checkDelaySetNames()
	if _M.delay_name_time then
		local now = os.time()
		if (now-_M.delay_name_time) < 0 or (now-_M.delay_name_time >=3) then
			_M.delay_name_time = nil
			_M.SetNameImmediately( _M.delay_group_name, _M.delay_device_name, _M.delay_channel_name )
		end
	end
end

local eula_step_check_count = 0

--Period checking.
function _M.Step()
	--EULA accept check.
	if not _M.EULA_accepted then
		if eula_step_check_count == 0 then
			local f = io.open( CONFIG_LOCATION .. "/EULA/global_accepted", "r" )
			if f then
				_M.EULA_accepted = true
				NDI.show_EULA( false )
				f:close()
			end
		end
		eula_step_check_count = eula_step_check_count + 1
		if eula_step_check_count >= 10 then
			eula_step_check_count = 0
		end
	end

	local vid_ver, vid_details = avio_chips.GetVideoSignalStatus()
	local aud_ver, aud_details = avio_chips.GetAudioSignalStatus()

	if not vid_details and not aud_details then
		checkDelaySetNames()
		--Not detect video and audio
		return
	end

	if not _M.video_fmt_ver or vid_ver ~= _M.video_fmt_ver then
		local tm = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )
		_M.video_fmt_ver = vid_ver
		_M.video_exact_detail.changed = true
		if avio_chips.disable_fpga_freq_check then
			_M.video_exact_detail.stable = true
			_M.video_exact_detail.last_clk_freq = math.floor((vid_details.hTotal or 0) * (vid_details.vTotal or 0) * (vid_details.frame_rate or 0))
			_M.video_exact_detail.last_stable_freq = nil
		else
			_M.video_exact_detail.stable = false --not vid_details.signal
			_M.video_exact_detail.last_clk_freq = nil
			_M.video_exact_detail.last_stable_freq = nil
		end
		_M.video_exact_detail.change_time = tm
		_M.video_exact_detail.signal = vid_details.signal

		if vid_details.signal then
			_M.video_exact_detail.format_name = vid_details.format_name or "1920x1080@60 Hz"
			_M.video_exact_detail.mode = vid_details.mode or "hd"
			_M.video_exact_detail.width = vid_details.width or 1920
			_M.video_exact_detail.height = vid_details.height or 1080
			_M.video_exact_detail.hTotal = vid_details.hTotal or 2200
			_M.video_exact_detail.vTotal = vid_details.vTotal or 1125
			_M.video_exact_detail.frame_rate = vid_details.frame_rate or 60
			_M.video_exact_detail.interlaced = vid_details.interlaced
			_M.video_exact_detail.rate_n = vid_details.rate_n or 60000
			_M.video_exact_detail.rate_d = vid_details.rate_d or 1000
		else
			_M.video_exact_detail.format_name = _M.video_exact_detail.format_name or vid_details.format_name or "1920x1080@60 Hz"
			_M.video_exact_detail.mode = _M.video_exact_detail.mode or vid_details.mode or "hd"
			_M.video_exact_detail.width = _M.video_exact_detail.width or vid_details.width or 1920
			_M.video_exact_detail.height = _M.video_exact_detail.height or vid_details.height or 1080
			_M.video_exact_detail.hTotal = _M.video_exact_detail.hTotal or vid_details.hTotal or 2200
			_M.video_exact_detail.vTotal = _M.video_exact_detail.vTotal or vid_details.vTotal or 1125
			_M.video_exact_detail.frame_rate = _M.video_exact_detail.frame_rate or vid_details.frame_rate or 60
			_M.video_exact_detail.interlaced = vid_details.interlaced
			_M.video_exact_detail.rate_n = _M.video_exact_detail.rate_n or vid_details.rate_n or 60000
			_M.video_exact_detail.rate_d = _M.video_exact_detail.rate_d or vid_details.rate_d or 1000
		end
	end

	--NOTE: XXX - If avio.lua declared 'disable_fpga_freq_check', then the FPGA exactly frequence detection
	--      is disabled.
	if not avio_chips.disable_fpga_freq_check then
	--{ FPGA exactly video frequence detection
		local exact_freq = NDI.read_reg( eReg_Video, vidCap_eClkFreq )
		if exact_freq then
			exact_freq = exact_freq * CLK_MUL
		end

		local calc_fr
		local calc_rate_n
		local calc_rate_d

		if exact_freq and _M.video_exact_detail.signal then
			if _M.video_exact_detail.mode == "4k" then
				exact_freq = exact_freq * 2
			elseif _M.video_exact_detail.mode == "4k60" then
				exact_freq = exact_freq * 4
			elseif _M.video_exact_detail.mode == "sd" then
				exact_freq = math.floor(exact_freq / 2)
			end

			local stable_wait = 800

			local tm = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )

			if not _M.video_exact_detail.last_clk_freq or math.abs(exact_freq - _M.video_exact_detail.last_clk_freq) > 10000 then
				_M.video_exact_detail.last_clk_freq = exact_freq
				_M.video_exact_detail.change_time = tm
				_M.video_exact_detail.stable = false

				--Case: Fall-back to previous stable freq.
				if _M.video_exact_detail.last_stable_freq and math.abs(exact_freq - _M.video_exact_detail.last_stable_freq) <= 10000 then
					_M.video_exact_detail.changed = false
				else
					_M.video_exact_detail.changed = true
				end
			else
				local dlta = tm.tv_sec - _M.video_exact_detail.change_time.tv_sec
				dlta = dlta * 1000
				dlta = dlta + math.floor((tm.tv_nsec - _M.video_exact_detail.change_time.tv_nsec)/1000000)
				if dlta >= stable_wait then
					_M.video_exact_detail.stable = true
					_M.video_exact_detail.change_time = tm
				end
			end

			local frameSize = _M.video_exact_detail.hTotal * _M.video_exact_detail.vTotal
			if frameSize >= (320*240) then
				if _M.video_exact_detail.interlaced then
					frameSize = frameSize * 2
				end

				calc_fr = math.floor((exact_freq/frameSize)*100)/100

				if (exact_freq >= 74100000 and exact_freq <= 74200000) or
					(exact_freq >= 148300000 and exact_freq <= 148400000) or
					(exact_freq >= 296600000 and exact_freq <= 296800000) or
					(exact_freq >= 593200000 and exact_freq <= 593600000) then
					calc_rate_d = 1001
					if calc_fr >= 59 and calc_fr < 61 then
						calc_fr = 59.94
						calc_rate_n = 60000
					elseif calc_fr >= 29 and calc_fr < 31 then
						calc_fr = 29.97
						calc_rate_n = 30000
					elseif calc_fr >= 23 and calc_fr < 24.5 then
						calc_fr = 23.98
						calc_rate_n = 24000
					else
						calc_rate_n = math.floor(calc_fr + 0.5)*1000
						calc_fr = math.floor((calc_fr/1.001) * 100)/100
					end
				elseif calc_fr < 23 then
					calc_fr = 30 --Fall safe
					calc_rate_n = 30000
					calc_rate_d = 1000
				else
					calc_fr = math.floor(calc_fr + 0.5)
					calc_rate_n = calc_fr*1000
					calc_rate_d = 1000
				end
			end
		else --No signal and hold more than 0.5s.
			local tm = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )
			local dlta = tm.tv_sec - _M.video_exact_detail.change_time.tv_sec
			dlta = dlta * 1000
			dlta = dlta + math.floor((tm.tv_nsec - _M.video_exact_detail.change_time.tv_nsec)/1000000)
			if dlta >= 500 then
				_M.video_exact_detail.stable = true
				_M.video_exact_detail.last_clk_freq = nil
			end
		end

		if calc_fr then
			if _M.video_exact_detail.interlaced then
				calc_fr = calc_fr * 2
			end
	
			if --_M.video_exact_detail.changed or
			   calc_fr ~= _M.video_exact_detail.frame_rate or
			   calc_rate_n ~= _M.video_exact_detail.rate_n or
			   calc_rate_d ~= _M.video_exact_detail.rate_d then
	
			   _M.video_exact_detail.frame_rate = calc_fr
			   _M.video_exact_detail.rate_n = calc_rate_n
			   _M.video_exact_detail.rate_d = calc_rate_d
	
			   if _M.video_exact_detail.interlaced then
				   _M.video_exact_detail.format_name = _M.video_exact_detail.width .. "x" .. (_M.video_exact_detail.height*2) .. "@" .. calc_fr .. "i"
			   else
				   _M.video_exact_detail.format_name = _M.video_exact_detail.width .. "x" .. _M.video_exact_detail.height .. "@" .. calc_fr .. " Hz"
			   end
			end
		end	
	--} FPGA exactly video frequence detection
	end

	if  (_M.video_exact_detail.changed and _M.video_exact_detail.stable) or 
		(not _M.audio_fmt_ver and not _M.video_exact_detail.changed) or 
		((_M.cfg.audio_source == "hdmi" or _M.cfg.audio_source == "embedded") and aud_ver ~= _M.audio_fmt_ver and not _M.video_exact_detail.changed) then

		if _M.video_exact_detail.signal then
			io_leds.SetSignalStatus( _M.video_exact_detail.mode or "hd" )
		else
			io_leds.SetSignalStatus( "off" )
		end

		_dbg.Info( "CODEC", "Video/audio format changed! Re-configure the NDI encoding." )

		--Save the last stable freq.
		_M.video_exact_detail.last_stable_freq = _M.video_exact_detail.last_clk_freq

		NDI.cleanup()
		_M.ndi_started = false

		if _M.delay_name_time then
			_M.delay_name_time = nil
			_M.SetNameImmediately( _M.delay_group_name, _M.delay_device_name, _M.delay_channel_name, true ) --Only set names
		end

		_dbg.Info( "CODEC", "*** Exact resolution info: CLK=", _M.video_exact_detail.last_clk_freq, "W=", _M.video_exact_detail.width, "H=", _M.video_exact_detail.height, "FR=", _M.video_exact_detail.frame_rate, "RateN=", _M.video_exact_detail.rate_n, "RateD=", _M.video_exact_detail.rate_d, "MODE=", _M.video_exact_detail.mode )

		if not aud_details or (_M.cfg.audio_source ~= "hdmi" and _M.cfg.audio_source ~= "embedded") then
			--Fixed 48KHz/stero
			aud_details = {
				sampling = 48000,
				channels = 2
			}
		end
		
		_M.video_exact_detail.changed = false
		--_M.video_fmt_ver = vid_ver
		_M.audio_fmt_ver = aud_ver

		local conn_type = _M.cfg.connection or "tcp"
		if conn_type == "multicast" then
			conn_type = "multicast:netprefix=" .. _M.cfg.mcast_prefix .. ", netmask=" .. _M.cfg.mcast_mask
		end

		conn_type = conn_type .. ", ttl=" .. _M.cfg.ttl

		if _G.glb_cfg and _G.glb_cfg.use_discovery_server then
			conn_type = conn_type .. ", discovery_server=" .. (_G.glb_cfg.discovery_server or "")
		end

		local cfg_opts = {
			debug= DEBUG_LEVEL,
			group_name = _M.cfg.group_name,
			channel_name = _M.cfg.channel_name,
			audio_source = _M.cfg.audio_source,
			audio_gain = math.floor((_M.cfg.audio_gain or 100)/100 * 256),
			audio_level = _M.cfg.audio_level,
			ndi_connection = conn_type,
			audio_sampling = aud_details.sampling or 48000,
			best_quality = _M.cfg.enc_quality
		}

		--if vid_details then
			cfg_opts.video_mode = _M.video_exact_detail.mode
			--NOTE: dropped. This is a special patch.
			--if cfg_opts.video_mode == "sd" then
			--	cfg_opts.video_mode = "hd"
			--end

			cfg_opts.video_width = _M.video_exact_detail.width
			cfg_opts.video_height = _M.video_exact_detail.height
			cfg_opts.video_interlaced = _M.video_exact_detail.interlaced
			cfg_opts.video_rate_n = _M.video_exact_detail.rate_n
			cfg_opts.video_rate_d = _M.video_exact_detail.rate_d
			if cfg_opts.video_rate_n < 1000 then
				cfg_opts.video_rate_n = 30000
			end

			if cfg_opts.video_rate_d < 1000 then
				cfg_opts.video_rate_d = 1000
			end
		--end

		if _M.video_exact_detail.mode == "4k60" and (_G.DISABLE_4Kp60 or _G.DISABLE_4K) then
			_dbg.Error( "CODEC", "Unsupported 4Kp60 format")
		elseif _M.video_exact_detail.mode == "4k" and _G.DISABLE_4K then
			_dbg.Error( "CODEC", "Unsupported 4K format")
		else
			local done, msg = NDI.config(cfg_opts)

			if not done then
				_dbg.Error( "CODEC", "Fail to configure NDI encoding! with error:", msg )
			else
				NDI.set_audio_mapping(_M.cfg.audio_channels, _M.cfg.audio_mapping)
				NDI.start()
				_M.ndi_started = true
			end
		end
	end

	checkDelaySetNames()

	local now = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )
	if not _M.last_ipcheck_time then
		_M.current_ip = check_default_ip()
		_M.last_ipcheck_time = now
		if _M.current_ip then
			NDI.set_web_control( _M.web_protocol .. _M.current_ip .. _M.web_port .. "/", _M.NtkUrl and ( _M.web_protocol .. _M.current_ip .. _M.web_port  .. _M.NtkUrl) or "", _M.NtkAcceptEULA and (_M.web_protocol .. _M.current_ip .. _M.web_port .. _M.NtkAcceptEULA) or ""  )
		end
	else
		local delta = (now.tv_sec - _M.last_ipcheck_time.tv_sec)*1000
		delta = delta + (now.tv_nsec - _M.last_ipcheck_time.tv_nsec)/1000000
		if delta >= 5000 then
			_M.last_ipcheck_time = now
			local ip = check_default_ip()
			if ip ~= _M.current_ip then
				_M.current_ip = ip
			end
			if ip then
				NDI.set_web_control( _M.web_protocol .. ip .. _M.web_port .. "/", _M.NtkUrl and (_M.web_protocol .. ip .. _M.web_port .. _M.NtkUrl) or "", _M.NtkAcceptEULA and (_M.web_protocol .. ip .. _M.web_port .. _M.NtkAcceptEULA) or "" )
			end
		end
	end
end

function _M.GetNdiUrl()
	if _M.web_protocol and _M.current_ip and _M.web_port then
		return _M.web_protocol .. _M.current_ip .. _M.web_port .. "/"
	end
	return nil
end

local function get_nm_proxy()
	local proxy
	local cli
	cli = client.New( "networkmanager", "local", nil, 5 ) --5 seconds timeout.
	if not cli then
		_dbg.Error( "MDNS", "Fail to create connection to service 'local/networkmanager'" )
		return nil
	end
	proxy = cli:CreateProxy("/", true) --Exclusive
	if not proxy then
		_dbg.Error( "MDNS", "Fail to create object proxy for '/@local/networkmanager'" )
		cli:Destroy()
		return nil
	end
	return proxy
end

function _M.MDNSServiceStarted()
	--TODO:
	return true
end

function _M.StopMDNSService()
	local proxy = get_nm_proxy()
	if not proxy then
		_dbg.Error( "MDNS", "Fail to stop MDNS service!" )
		return
	end
	proxy.StopMDNS()
	proxy:Destroy()
	_dbg.Info( "MDNS", "mDNS service is terminated." )
end

function _M.StartMDNSService()
	local proxy = get_nm_proxy()
	if not proxy then
		_dbg.Error( "MDNS", "Fail to start MDNS service!" )
		return
	end
	proxy.StartMDNS()
	proxy:Destroy()
	_dbg.Info( "MDNS", "mDNS service is running." )
end

function _M.SetNameImmediately(group_name, device_name, channel_name, onlySet)
	local cur_host_name = getHostname()

	device_name = device_name ~= "" and device_name or cur_host_name
	channel_name = channel_name ~= "" and channel_name or _M.cfg.channel_name
	group_name = group_name or _M.cfg.group_name

	local stop_ndi_encoding = false

	local task = false

	if device_name ~= cur_host_name then
		task = true
		_dbg.Info( "CODEC", "Changed the NDI device name to:", device_name )
		NDI.cleanup({net=true})
		stop_ndi_encoding = not onlySet

		os.execute( "/bin/hostname '" .. device_name .. "'" )
		local f = io.open( "/etc/hostname", "w" )
		if f then
			f:write( device_name .. "\n" )
			f:close()
		end
		_M.StopMDNSService()
		_M.StartMDNSService()
	end

	if group_name ~= _M.cfg.group_name or channel_name ~= _M.cfg.channel_name then
		if group_name ~= _M.cfg.group_name then
			task = true
		end
		_dbg.Info( "CODEC", "Changed the NDI channel name to: group=", group_name, ", channel=", channel_name )
		_M.cfg.group_name = group_name
		_M.cfg.channel_name = channel_name
		_M.cfg:__TRIGGER(true)
		NDI.cleanup({net=true})
		stop_ndi_encoding = not onlySet
	end

	if stop_ndi_encoding and _M.ndi_started then
		NDI.config( {group_name = group_name, channel_name = channel_name} )
		NDI.start()
	end
	if task and features.FEATURE_NDIHX then
		local args = {}
		args["device_group"] = group_name
		args["device_name"] = device_name
		_M.SendNameGroupToMediaserver(args)
	end

	return true
end

function _M.SetName(device_name, channel_name)
	local cur_host_name = getHostname()

	device_name = device_name ~= "" and device_name or cur_host_name
	channel_name = channel_name ~= "" and channel_name or _M.cfg.channel_name

	if device_name ~= cur_host_name or channel_name ~= _M.cfg.channel_name then
		_M.delay_device_name = device_name
		_M.delay_channel_name = channel_name
		_M.delay_name_time = os.time()
	else
		_M.delay_name_time = nil
	end

	return true
end

function _M.SetNameWithGroup(group_name, device_name, channel_name)
	local cur_host_name = getHostname()

	device_name = device_name ~= "" and device_name or cur_host_name
	channel_name = channel_name ~= "" and channel_name or _M.cfg.channel_name
	group_name = group_name

	if group_name ~= _M.cfg.group_name or device_name ~= cur_host_name or channel_name ~= _M.cfg.channel_name then
		_M.delay_group_name = group_name
		_M.delay_device_name = device_name
		_M.delay_channel_name = channel_name
		_M.delay_name_time = os.time()
	else
		_M.delay_name_time = nil
	end

	return true
end


function _M.SendNameGroupToMediaserver(args)
	local proxy = get_mediaserver_proxy()
	if not proxy then
		return false
	end
	proxy.UpdateNdiGroupName(args)
	proxy:Destroy()
	return true
end

function _M.GetName()
	if _M.delay_name_time then
		return _M.delay_device_name or getHostname() or "?", _M.delay_channel_name or _M.cfg.channel_name
	else
		return getHostname() or "?", _M.cfg.channel_name
	end
end

function _M.GetNameWithGroup()
	if _M.delay_name_time then
		return _M.delay_group_name or _M.cfg.group_name, _M.delay_device_name or getHostname() or "?", _M.delay_channel_name or _M.cfg.channel_name
	else
		return _M.cfg.group_name, getHostname() or "?", _M.cfg.channel_name
	end
end

function _M.SetNDIConnection(conn_type, mcast_prefix, mcast_mask, ttl)
	if conn_type then
		local changed = false
		if conn_type ~= _M.cfg.connection then
			_dbg.Info( "CODEC", "Changed the NDI connection type to:", conn_type )
			_M.cfg.connection = conn_type
			changed = true
		end

		ttl = tonumber(ttl) or _M.cfg.ttl
		if conn_type == "multicast" and (mcast_prefix ~= _M.cfg.mcast_prefix or mcast_mask ~= _M.cfg.mcast_mask) then
			_dbg.Info( "CODEC", "Changed the NDI mutlicast settings to:", mcast_prefix, mcast_mask )
			_M.cfg.mcast_prefix = mcast_prefix
			_M.cfg.mcast_mask = mcast_mask
			changed = true
		end

		if (conn_type == "multicast" or conn_type == "udp") and (ttl ~= _M.cfg.ttl) then
			_M.cfg.ttl = ttl
			changed = true
		end

		if changed then
			_M.cfg:__TRIGGER(true)
			coaf.ScheduleDelayedTask( function()
				NDI.cleanup({net=true})
				if _M.ndi_started then
					if conn_type == "multicast" then
						conn_type = "multicast:netprefix=" .. _M.cfg.mcast_prefix .. ", netmask=" .. _M.cfg.mcast_mask 
					end
					conn_type = conn_type .. ", ttl=" .. ttl
					if _G.glb_cfg and _G.glb_cfg.use_discovery_server then
						conn_type = conn_type .. ", discovery_server=" .. (_G.glb_cfg.discovery_server or "")
					end
					NDI.config( { ndi_connection = conn_type } )
					NDI.start()
				end
			end)
		end
	end

	return true
end

function _M.GetNDIConnection()
	return _M.cfg.connection, _M.cfg.mcast_prefix, _M.cfg.mcast_mask, _M.cfg.ttl
end

function _M.SetDiscoveryServer(enable,addr)
	if _G.glb_cfg then
		if _G.glb_cfg.use_discovery_server ~= enable or (addr and _G.glb_cfg.discovery_server ~= addr) then
			_dbg.Info("CODEC", "Update/changed the discovery server by: using=", enable, ", address=", addr)
			_G.glb_cfg.use_discovery_server = enable
			if addr then
				_G.glb_cfg.discovery_server = addr
			end
			_G.glb_cfg:__TRIGGER(true)

			coaf.ScheduleDelayedTask( function()
				NDI.cleanup({net=true})
				if _M.ndi_started then
					local conn_type = _M.cfg.connection or ""
					if conn_type == "multicast" then
						conn_type = "multicast:netprefix=" .. _M.cfg.mcast_prefix .. ", netmask=" .. _M.cfg.mcast_mask
					end
					conn_type = conn_type .. ", ttl=" .. _M.cfg.ttl
					if _G.glb_cfg.use_discovery_server then
						conn_type = conn_type .. ", discovery_server=" .. (_G.glb_cfg.discovery_server or "")
					end
					NDI.config( { ndi_connection = conn_type } )
					NDI.start()
				end
				if features.FEATURE_NDIHX then
					if _G.glb_cfg.use_discovery_server then
						_M.SendNameGroupToMediaserver({server_addr=_G.glb_cfg.discovery_server})
					else
						_M.SendNameGroupToMediaserver({server_addr=""})
					end
				end
			end)
		end
	end
	return true
end

function _M.GetDiscoveryServer()
	if _G.glb_cfg then
		return _G.glb_cfg.use_discovery_server, _G.glb_cfg.discovery_server or ""
	else
		return false, ""
	end
end

function _M.SelectAudioSource(src)
	if src and src ~= _M.cfg.audio_source then
		_M.cfg.audio_source = src
		_M.cfg:__TRIGGER(true)
		_M.audio_fmt_ver = nil --Clear to update in next checking step.
	end
	return true
end

function _M.GetAudioChannelNames()
	local names = avio_chips.audio_in_channel_names or { "Left/Right" }
	local rslt = {}
	for i,v in ipairs(names) do
		table.insert(rslt, {value=i, name=v})
	end
	return rslt
end

function _M.GetAudioChannelSupports()
	--TODO: Dynamic returns audio channel supports for encoder?
	return {
		{ value=0, name="AUTO" },
		{ value=2, name="2" },
		{ value=4, name="4" },
		{ value=6, name="6" },
		{ value=8, name="8" },
		{ value=10, name="10" },
		{ value=12, name="12" },
		{ value=14, name="14" },
		{ value=16, name="16" }
	}
end

function _M.GetAudioChannel()
	return _M.cfg.audio_channels, _M.cfg.audio_mapping
end

function _M.SetAudioChannel(n_channel, mapping)
	n_channel = tonumber(n_channel)
	if n_channel and n_channel >= 0 and n_channel <= 16 then
		_M.cfg.audio_channels = n_channel
	end

	if type(mapping) == "table" then
		for k, v in pairs(mapping) do
			k = tonumber(k)
			v = tonumber(v)
			if k and v and k >= 1 and k <= 16 then
				_M.cfg.audio_mapping[k] = v
			end
		end
	end
	
	_M.cfg:__TRIGGER(true)
	NDI.set_audio_mapping(_M.cfg.audio_channels, _M.cfg.audio_mapping)
	return true
end

function _M.GetAudioSource()
	return _M.cfg.audio_source
end

function _M.SetAudioGain(gain)
	gain = tonumber(gain)
	if gain and gain >= 0 and gain <= 200 and gain ~= _M.cfg.audio_gain then
		_M.cfg.audio_gain = gain
		_M.cfg:__TRIGGER(true)
		NDI.set_audio_gain( math.floor( gain/100 * 256 ) )
	end
	return true
end

function _M.GetAudioGain()
	return _M.cfg.audio_gain
end


function _M.SetAudioLevel(level)
	level = level == "ebu" and 14 or 20
	NDI.set_audio_level( level )
	_M.cfg.audio_level = level
	_M.cfg:__TRIGGER(true)
	return true
end

function _M.GetAudioLevel()
	local data = "smpte"
	if _M.cfg.audio_level == 14 then
		data = "ebu"
	end
	return data
end

function _M.GetEncQuality()
	return _M.cfg.enc_quality
end

function _M.SetEncQuality(q)
	q = tonumber(q)
	if q and q ~= _M.cfg.enc_quality then
		_M.cfg.enc_quality = q
		_M.cfg:__TRIGGER(true)
		NDI.set_enc_quality(q)
	end
	return true
end

function _M.GetDNANumber()
	return _M.DNA
end

function _M.GetDisableSignalTallyId()
	return _M.cfg.disable_signal_tally_id
end

function _M.SetDisableSignalTallyId(dis)
	if type(dis) ~= "nil" then
		if type(dis) == "string" then
			if dis:lower() == "false" or dis:lower() == "no" then
				dis = false
			elseif tonumber(dis) == 0 then
				dis = false
			else
				dis = true
			end
		elseif type(dis) == "number" then
			if dis == 0 then
				dis = false
			else
				dis = true
			end
		elseif type(dis) ~= "boolean" then
			dis = true
		end

		_M.cfg.disable_signal_tally_id = dis
		_M.cfg:__TRIGGER(true)
		io_leds.SetDisableSignalTallyId(dis)
	end
end

function _M.GetStatus()
	--local vid_ver, vid_details = avio_chips.GetVideoSignalStatus()
	local aud_ver, aud_details = avio_chips.GetAudioSignalStatus()

	--[[
	if not vid_details then
		vid_details = {
			signal = false,
			format_name = "No signal",
			width = 0,
			height = 0,
			frame_rate = 0
		}
	end
	]]

	local vid_details = _M.video_exact_detail

	if not aud_details then
		aud_details = {
			sampling = 48000,
			channels = 0,
			signal = false
		}
	end

	if _M.cfg.audio_channels and _M.cfg.audio_channels > 0 then
		aud_details.channels = _M.cfg.audio_channels
	end

	local m_br, p_br, a_br = NDI.get_bitrate()
	--TODO:
	m_br = (m_br or 0) + (a_br or 0)
	
	local resolution = vid_details.signal and vid_details.format_name or "No signal"
	local frame_rate = vid_details.signal and vid_details.frame_rate or 0

	if vid_details.mode == "4k60" and vid_details.signal and (_G.DISABLE_4Kp60 or _G.DISABLE_4K) then
		resolution = "Unsupported UHD"
	elseif vid_details.mode == "4k" and vid_details.signal and _G.DISABLE_4K then
		resolution = "Unsupported UHD"
	end

	return {
		bitrate = m_br,
		connections = 0, --TODO
		resolution = resolution,
		frame_rate = frame_rate,
		sampling = aud_details.sampling,
		channels = aud_details.channels,
		audo_signal = (_M.cfg.audio_source ~= "hdmi" and _M.cfg.audio_source ~= "embedded") and true or aud_details.signal,
		video_signal = vid_details.signal,
		audio_signal = _M.cfg.audio_source,
		interlaced = vid_details.signal and vid_details.interlaced and true or false,
		xRes = vid_details.signal and vid_details.width or 1920,
		yRes = vid_details.signal and vid_details.height or 1080,
	}
end

function _M.Reset()
	NDI.cleanup()
	NDI.config({})
	NDI.set_audio_mapping(_M.cfg.audio_channels, _M.cfg.audio_mapping)
	if _M.ndi_started then
		NDI.start()
	end
	return true
end

function _M.GetFPGAVersion()
	local hwver = NDI.read_reg( eReg_Version, 0 )
	if hwver then
		return string.format( "%x", hwver )
	else
		return "00000"
	end
end

function _M.IsBlocked()
	local be_blocked = NDI.check_blocked()
	if be_blocked then
		_dbg.Error( "CODEC", "S.O.S! NDI sending is blocked! Codec mate will kill me soon!" )
	end
	return be_blocked
end

return _M

