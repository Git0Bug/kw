local coaf=require "coaf.core"
local _dbg = require "coaf.debug"
local thread = require "coaf.thread"
local avio_chips = require "chips.avio"
local ndi_config = require "dec_config"
local posix_time = require "posix.time"
local io_leds = require "io_leds"
local client = require "coaf.client"

local keypad = require "keyboard.mod_keyboard"
local keysym = keypad.symbols

require "ndi_decoding"
local discovery = require "discovery"

local DEBUG_LEVEL = 4
local CONFIG_LOCATION = "/data/configs"

local eReg_Audio = 0x220
local eReg_Version = 0x300

local _M = {
	cfg = nil,
	last_scan_time = nil,

	delay_group_name = nil,
	delay_device_name = nil,
	delay_channel_name = nil,
	delay_name_time = nil,

	current_ip = nil,
	last_ipcheck_time = nil,

	web_protocol = "http://",
	web_port = "",

	--TODO: false
	EULA_accepted = true,
	tag = nil
}

-------------------------------------------------
local function delayed_init_discovery()
	_dbg.Info("CODEC", "(delayed) Initialize discovery ...")
	discovery.Init()
	_M.UpdateWorkDiscovery()

	--NOTE: set_SPLASH is deprecated.
	--NDI.DECODING.set_SPLASH( {main_width=1920, main_height=1080, main_fourCC="SHQ7", preview_width=640, preview_height=360, preview_fourCC="shq7"} )

	if _G.glb_cfg and _G.glb_cfg.use_discovery_server then
		NDI.DECODING.enable_discovery( _M.cfg.group_name, _M.cfg.channel_name, "tcp,discovery_server=" .. (_G.glb_cfg.discovery_server or "") )
	else
		NDI.DECODING.enable_discovery( _M.cfg.group_name, _M.cfg.channel_name, "tcp" )
	end

	keypad.Init()
	keypad.RegisterCallback(_M.__onKey)

	_dbg.Info("CODEC", "(delayed) Initialize discovery done.")
end

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

-------------------------------------------------

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

	avio_chips.Init("decoding")
	io_leds.Init()

	_M.SetTally()

	NDI.DECODING.config({
		coevent = "ndi_decoding",
		decoder_topic = "decoder",
		debug = DEBUG_LEVEL,
		audio_output = _M.cfg.audio.output,
		audio_gain = math.floor(_M.cfg.audio.gain/100*256),
		audio_level = _M.cfg.audio.audio_level or 20,
		audio_sampling = _M.cfg.audio.sample_rate or 48000,
		audio_channels = _M.cfg.audio.no_channels or 0,
		audio_max_channels = avio_chips.max_audio_channels or 2,
		audio_mapping = _M.cfg.audio.audio_mapping,

		blank_color = { r = _M.cfg.blank.r, g = _M.cfg.blank.g, b = _M.cfg.blank.b },
		video_disable = not _M.cfg.video.enable,
		audio_disable = not _M.cfg.audio.enable,
		ndi_connection = "discovery_server=" .. (_G.glb_cfg.use_discovery_server and _G.glb_cfg.discovery_server or "")
	})

	avio_chips.SetVideoOutputFormat( _M.cfg.video )
	avio_chips.SetAudioOutputFormat( _M.cfg.audio )

	NDI.DECODING.select_ndi_source( _M.cfg.current )

	--After call 'Step()', it will configure then NDI encoding then start it.
	local dna_l = NDI.DECODING.read_reg( eReg_Version, 0xfd )
	local dna_h = NDI.DECODING.read_reg( eReg_Version, 0xfc )
	if dna_h and dna_l then
		_M.DNA = string.format( "%08x%08x", dna_h, dna_l )
		_dbg.Info( "CODEC", "FPGA DNA number is:", _M.DNA )
	else
		_dbg.Warn( "CODEC", "Fail to get FPGA DNA number!" )
	end

	_M.CreateDynamicUser()

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
	coaf.ScheduleDelayedTask( delayed_init_discovery, 3 ) --Delay 3 second to start discovery.

	NDI.DECODING.start()
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

--local eula_step_check_count = 0

--Period checking.
function _M.Step()
	--[[
	if not _M.EULA_accepted then
		if eula_step_check_count == 0 then
			local f = io.open( CONFIG_LOCATION .. "/EULA/global_accepted", "r" )
			if f then
				_M.EULA_accepted = true
				NDI.DECODING.show_EULA( false )
				f:close()
			end
		end
		eula_step_check_count = eula_step_check_count + 1
		if eula_step_check_count >= 10 then
			eula_step_check_count = 0
		end
	end
	--]]

	checkDelaySetNames()

	--Check discovery list and the url is changed or not.
	if _M.cfg.current.name ~= "" then
		local info = discovery.GetWorkSources(_M.cfg.current.name)
		if not info then
			_M.cfg.current.online = false
			_M.cfg.current.warning = "offline"
		else
			_M.cfg.current.online = true
			_M.cfg.current.warning = ""
			if info.original_url ~= _M.cfg.current.url then
				_M.SetCurrent( _M.cfg.current.name, info.original_url, _M.cfg.current.content, _M.cfg.current.group, _M.cfg.current.preset_id )
			end
		end
	end

	local k,preset
	for k,preset in pairs(_M.cfg.presets) do
		if preset.name ~= "" then
			local info = discovery.GetWorkSources(preset.name)
			--local name_changed
			--if not info and preset.url ~= "" then
			--	info = discovery.GetWorkSources(nil, nil, preset.url:match("%d+%.%d+%.%d+%.%d+"))
			--	name_changed = true
			--end

			if info then
				preset.online = true
				if preset.url ~= info.original_url then
					--Change the URL.
					preset.url = info.original_url
					preset.warning = "url-changed"
				--elseif name_changed then
				--	preset.warning = "name-changed"
				else
					preset.warning = ""
				end
			else
				preset.online = false
				preset.warning = "offline"
			end
		else
			preset.online = false
			preset.warning = "offline"
		end
	end

	_M.cfg:__TRIGGER(true)

	local now = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )
	if not _M.last_ipcheck_time then
		_M.current_ip = check_default_ip()
		_M.last_ipcheck_time = now
		if _M.current_ip then
			NDI.DECODING.set_web_control( _M.web_protocol .. _M.current_ip .. _M.web_port .. "/", _M.NtkUrl and (_M.web_protocol .. _M.current_ip  .. _M.web_port .. _M.NtkUrl) or "", _M.NtkAcceptEULA and (_M.web_protocol .. _M.current_ip .. _M.web_port .. _M.NtkAcceptEULA) or ""  )
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
				NDI.DECODING.set_web_control( _M.web_protocol .. ip .. _M.web_port .. "/", _M.NtkUrl and (_M.web_protocol .. ip .. _M.web_port .. _M.NtkUrl) or "", _M.NtkAcceptEULA and (_M.web_protocol .. ip .. _M.web_port .. _M.NtkAcceptEULA) or "" )
			end
		end
	end
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

function _M.GetDiscoveryManuals()
	return _M.cfg.manuals, _M.cfg.groups
end

function _M.SetDiscoveryManuals(ips, groups)
	if type(ips) ~= "table" then
		ips = { ips }
	end
	if type(groups) ~= "table" then
		groups = { groups }
	end
	_M.cfg.manuals = ips
	_M.cfg.groups = groups
	_M.cfg:__TRIGGER(true)
	_M.UpdateWorkDiscovery()
	return true
end

function _M.UpdateWorkDiscovery()
	local groups = {["public"] = true, "public"}
	local manual_ips = {}

	--Get from manual groups.
	for i=1, #_M.cfg.groups do
		if not groups[_M.cfg.groups[i]] then
			groups[_M.cfg.groups[i]] = true
			table.insert(groups, _M.cfg.groups[i])
		end
	end

	--Get from manual list.
	for i=1, #_M.cfg.manuals do
		if not manual_ips[_M.cfg.manuals[i]] then
			manual_ips[_M.cfg.manuals[i]] = true
			table.insert(manual_ips, _M.cfg.manuals[i])
		end
	end

	local ip
	if _M.cfg.current.name ~= "" and _M.cfg.current.url ~= "" then
		if _M.cfg.current.group == "*manual*" then
			ip = _M.cfg.current.url:match("%d+%.%d+%.%d+%.%d+")
			if ip and not manual_ips[ip] then
				manual_ips[ip] = true
				table.insert(manual_ips, ip)
			end
		elseif _M.cfg.current.group ~= "" and _M.cfg.current.group ~= "*" and _M.cfg.current.group ~= "public" then
			if not groups[_M.cfg.current.group] then
				table.insert( groups, _M.cfg.current.group )
				groups[ _M.cfg.current.group ] = true
			end
		end
	end

	local k, v
	for k, v in pairs(_M.cfg.presets) do
		if v.name ~= "" and v.url ~= "" then
			if v.group == "*manual*" then
				ip = v.url:match("%d+%.%d+%.%d+%.%d+")
				if ip and not manual_ips[ip] then
					manual_ips[ip] = true
					table.insert(manual_ips, ip)
				end
			elseif v.group ~= "" and v.group ~= "*" and v.group ~= "public" then
				if not groups[v.group] then
					table.insert( groups, v.group )
					groups[ v.group ] = true
				end
			end
		end
	end

	discovery.SetWorkGroups( groups )
	discovery.SetWorkManuals( manual_ips )
	if _G.glb_cfg and _G.glb_cfg.use_discovery_server then
		discovery.SetDiscoveryServer(_G.glb_cfg.discovery_server)
	else
		discovery.SetDiscoveryServer("")
	end
end

function _M.SetTally(pgm,pvw)
	local changed
	if type(pgm) == "boolean" and pgm ~= _M.cfg.current.tally_pgm then
		_M.cfg.current.tally_pgm = pgm
		changed = true
	end

	if type(pvw) == "boolean" and pvw ~= _M.cfg.current.tally_pvw then
		_M.cfg.current.tally_pvw = pvw
		changed = true
	end

	if changed then
		_M.cfg:__TRIGGER(true)
	end

	if _M.cfg.current.tally_pgm then
		io_leds.TallyLightControl( nil, "red", "on" )
	else
		io_leds.TallyLightControl( nil, "red", "off" )
	end

	if _M.cfg.current.tally_pvw then
		io_leds.TallyLightControl( nil, "green", "on" )
	else
		io_leds.TallyLightControl( nil, "green", "off" )
	end

	NDI.DECODING.set_tally({pgm=_M.cfg.current.tally_pgm, pvw=_M.cfg.current.tally_pvw})

	return true
end

function _M.GetTally()
	return _M.cfg.current.tally_pgm, _M.cfg.current.tally_pvw
end

function _M.SelectAudioOutput(out)
	if out and out ~= _M.cfg.audio.output then
		_M.cfg.audio.output = out
		_M.cfg:__TRIGGER(true)

		NDI.DECODING.select_audio_output( _M.cfg.audio.output )
	end
	return true
end

function _M.GetAudioOutput()
	return _M.cfg.audio.output
end

function _M.SetAudioGain(gain)
	gain = tonumber(gain)
	if gain and gain >= 0 and gain <= 200 and gain ~= _M.cfg.audio.gain then
		_M.cfg.audio.gain = gain
		_M.cfg:__TRIGGER(true)
		NDI.DECODING.set_audio_gain( math.floor((gain/100)*256) )
	end
	return true
end

function _M.GetAudioGain()
	return _M.cfg.audio.gain
end

function _M.AddPreset(id,name,url,group)
	if not id then
		return nil
	end
	id = tostring(id)
	local item = _M.cfg.presets[id]
	if not item then
		_M.cfg.presets[id] = {name = name}
		item = _M.cfg.presets[id]
	end

	if not name or name == "" then
		item.name = ""
		item.url = ""
		item.content = "full"
		item.group = ""
	else
		item.name = name
		item.url = url
		item.group = group
		--TODO:
		item.content = "full"
	end

	_M.UpdateWorkDiscovery()
	return item
end

function _M.GetPresets(id)
	if not id then
		local rslt = {}
		local k,item
		for k,item in pairs(_M.cfg.presets) do
			--Don't use '0' if something wrong.
			if k ~= "0" and k ~= 0 then
				local r={
					id = k,
					name = item.name,
					url = item.url,
					group = item.group,
					content = item.content,
					online = item.online,
					warning = item.warning
				}
				if item.name == "" then
					r.device_name = ""
					r.channel_name = ""
				else
					local dname, cname = item.name:match("(.-)%s+%((.+)%)")
					if not dname then
						dname = item.name
						cname = "unknown"
					end
					r.device_name = dname
					r.channel_name = cname
				end
				if item.url == "" then
					r.ip = ""
					r.port = 0
				else
					local ip, prt = item.url:match("(%d+%.%d+%.%d+%.%d+)%:?(%d*)")
					if ip then
						r.ip = ip
						r.port = tonumber(prt) or 5960
					else
						r.ip = item.url
						r.port = 0
					end
				end
				table.insert( rslt,r )
			end
		end

		table.sort( rslt, function(a,b)
			if not a or not b or a == b then
				return false
			end
			return tonumber(a.id) < tonumber(b.id)
		end)

		return rslt
	else
		id = tostring(id)
		local item = _M.cfg.presets[id]
		if not item then
			return {
				id = id,
				name = "",
				url = "",
				group = "",
				content = "full",
				online = false,
				warning = "",
				device_name = "",
				channel_name = "",
				ip = "",
				port = 0
			}
		end

		local r={
			id = k,
			name = item.name,
			url = item.url,
			group = item.group,
			content = item.content,
			online = item.online,
			warning = item.warning
		}

		if item.name == "" then
			r.device_name = ""
			r.channel_name = ""
		else
			local dname, cname = item.name:match("(.-)%s+%((.+)%)")
			if not dname then
				dname = item.name
				cname = "unknown"
			end
			r.device_name = dname
			r.channel_name = cname
		end
		if item.url == "" then
			r.ip = ""
			r.port = 0
		else
			local ip, prt = item.url:match("(%d+%.%d+%.%d+%.%d+)%:?(%d*)")
			if ip then
				r.ip = ip
				r.port = tonumber(prt) or 5960
			else
				r.ip = item.url
				r.port = 0
			end
		end
		return r
	end
end

function _M.RemovePreset(id)
	if not id then
		return false
	end
	id = tostring(id)
	local item = _M.cfg.presets[id]
	if item then
		item.name = ""
		item.url = ""
		item.group = ""
		item.content = "full"
	end
	_M.UpdateWorkDiscovery()
	return true
end

function _M.SelectPreset(id)
	if not id then
		return nil
	end
	id = tostring(id)
	if id == "0" then
		return _M.SelectBlank()
	end

	local item = _M.cfg.presets[id]
	if not item or item.name == "" then
		return nil
	end
	return _M.SetCurrent( item.name, item.url, item.content, item.group, id )
end

function _M.SelectBlank()
	return _M.SetCurrent( "", "", nil, nil, "0" )
end

function _M.SetBlankColor(color)
	if color and color ~= _M.cfg.blank.color then
		_M.cfg.blank.color = color
		_M.cfg:__TRIGGER(true)
		NDI.DECODING.set_blank_color({r=_M.cfg.blank.r, g=_M.cfg.blank.g, b=_M.cfg.blank.b})
	end
	return true
end

function _M.GetBlankColor()
	return _M.cfg.blank.color
end

function _M.SetCurrent(name,url,content,group,preset_id)
	content = content or "full"
	group = group or ""
	preset_id = preset_id or ""

	if name ~= _M.cfg.current.name or
	   url ~= _M.cfg.current.url or
	   content ~= _M.cfg.current.content or
	   group ~= _M.cfg.current.group or
	   preset_id ~= _M.cfg.current.preset_id then

	   _M.cfg.current.name = name
	   _M.cfg.current.url = url
	   _M.cfg.current.content = content
	   _M.cfg.current.group = group
	   _M.cfg.current.preset_id = preset_id
	   _M.cfg:__TRIGGER(true)

	   _M.UpdateWorkDiscovery()
	   return NDI.DECODING.select_ndi_source( _M.cfg.current )
	end
	return true
end

function _M.GetCurrentSettings()
	return _M.cfg.current
end

function _M.SetCurrentSettings(opts)
	if type(opts) == "table" then
		local k,v
		for k,v in pairs(opts) do
			_M.cfg.current[k] = v
		end
		_M.cfg:__TRIGGER(true)
	end
	return true
end

function _M.GetDNANumber()
	return _M.DNA
end

function _M.SetVideoFormat(fmtInfo)
	if fmtInfo then
		if type(fmtInfo.enable) ~= "nil" then
			_M.cfg.video.enable = fmtInfo.enable
		end
		if fmtInfo.mode then
			_M.cfg.video.mode = fmtInfo.mode
		end

		if fmtInfo.format then
			_M.cfg.video.format = fmtInfo.format
		end

		if fmtInfo.frame_rate then
			_M.cfg.video.frame_rate = fmtInfo.frame_rate
		end

		_M.cfg:__TRIGGER(true)
		avio_chips.SetVideoOutputFormat( _M.cfg.video )
	end
	return true
end

function _M.GetVideoFormatSetting()
	return _M.cfg.video
end

function _M.GetAudioChannelNames()
	local names = avio_chips.audio_out_channel_names or { "Left", "Right" }
	local rslt = {}
	for i,v in ipairs(names) do
		table.insert(rslt, {value=i, name=v})
	end
	return rslt
end

function _M.GetAudioChannelSupports()
	local maxCh = avio_chips.max_audio_channels or 2
	local rslt = { {value=0, name="AUTO"} }
	for i=2,maxCh,2 do
		table.insert(rslt, {value=i, name="" .. i})
	end
	return rslt
end

function _M.SetAudioFormat(fmtInfo)
	if fmtInfo then
		if type(fmtInfo.enable) ~= "nil" then
			_M.cfg.audio.enable = fmtInfo.enable
		end
		if fmtInfo.sample_rate then
			_M.cfg.audio.sample_rate = fmtInfo.sample_rate
		end

		if fmtInfo.output then
			_M.cfg.audio.output = fmtInfo.output
		end

		if tonumber(fmtInfo.no_channels) then
			_M.cfg.audio.no_channels = tonumber(fmtInfo.no_channels)
			if _M.cfg.audio.no_channels > 16 then
				_M.cfg.audio.no_channels = 16
			elseif _M.cfg.audio.no_channels < 0 then
				_M.cfg.audio.no_channels = 0
			end
		end

		if type(fmtInfo.audio_mapping) == "table" then
			for k, v in pairs(fmtInfo.audio_mapping) do
				k = tonumber(k)
				v = tonumber(v)
				if k and v and k >= 1 and k <= 16 then
					_M.cfg.audio.audio_mapping[k] = v
				end
			end
		end

		_M.cfg:__TRIGGER(true)

		NDI.DECODING.config({
			audio_disable = not _M.cfg.audio.enable,
			audio_sampling = _M.cfg.audio.sample_rate or 48000,
			audio_channels = _M.cfg.audio.no_channels or 0,
			audio_mapping = _M.cfg.audio.audio_mapping
		})

		NDI.DECODING.start()
		avio_chips.SetAudioOutputFormat( _M.cfg.audio )
	end
	return true
end

function _M.GetAudioFormatSetting()
	return _M.cfg.audio
end

function _M.GetStatus()
	local name = _M.cfg.current.name
	if name == "" then
		name = "(Blank)"
	end
	local vfmt = avio_chips.GetVideoOutputFormat()
	local warning
	if not vfmt then
		warning = "ERR:no-video-output"
	elseif vfmt.error_tag then
		warning = "WARN:" .. vfmt.error_tag
	end

	local afmt = avio_chips.GetAudioOutputFormat()
	local adetail
	if not afmt then
		warning = "ERR:no-audio-output"
		adetail = "(Invalid)"
	else
		adetail = (afmt.sample_rate/1000) .. "KHz / " .. afmt.no_channels .. "CH"
	end

	if not warning and _M.cfg.current.warning ~= "" then
		warning = "WARN:" .. _M.cfg.current.warning
	end

	local vbr, abr, vfr = NDI.DECODING.get_bitrate()
	if vfr then
		vfr = math.floor( vfr*100 )/100
	end

	return {
		name = name,
		ip = _M.cfg.current.url:match("%d+%.%d+%.%d+%.%d+") or "0.0.0.0",
		online = _M.cfg.current.online,
		resolution = vfmt and vfmt.format_name or "(Invalid)",
		video_mode = vfmt and vfmt.mode or "hdmi",
		codec = vfmt and vfmt.codec or "UNKNOWN",
		deInterlace = vfmt and vfmt.deInterlace or false,
		interlaced = vfmt and vfmt.interlaced,
		--TODO: count the audio bitrate?
		bitrate = vbr,
		frame_rate = vfr,
		audio = adetail,
		url = _M.cfg.current.url,
		warning = warning or "",
		--TODO:
		web = "",
		xRes = vfmt.width,
		yRes = vfmt.height,
		audio_sampling = afmt.sample_rate,
		audio_channels = afmt.no_channels,
		ptz = 1
	}
end

function _M.Reset()
	NDI.DECODING.cleanup()
	NDI.DECODING.config({})
	NDI.DECODING.start()
	return true
end

function _M.GetFPGAVersion()
	local hwver = NDI.DECODING.read_reg( eReg_Version, 0xff )
	if hwver then
		return string.format( "%x", hwver & 0xffff )
	else
		return "00000"
	end
end

function _M.IsBlocked()
	--TODO: Check something be blocked?
	return false
end

function _M.SetNameImmediately(group_name, device_name, channel_name)
	local cur_host_name = getHostname()

	device_name = device_name ~= "" and device_name or cur_host_name
	channel_name = channel_name ~= "" and channel_name or _M.cfg.channel_name
	group_name = group_name or _M.cfg.group_name

	local changed = false
	if device_name ~= cur_host_name then
		_dbg.Info( "CODEC", "Changed the NDI device name to:", device_name )
		os.execute( "/bin/hostname '" .. device_name .. "'" )
		local f = io.open( "/etc/hostname", "w" )
		if f then
			f:write( device_name .. "\n" )
			f:close()
		end

		--NDI.DECODING.disable_discovery()
		changed = true

		_M.StopMDNSService()
		_M.StartMDNSService()

		coaf.ScheduleDelayedTask(function()
			discovery.Reset()
		end, 3) -- Delayed 3 seconds
	end

	if group_name ~= _M.cfg.group_name or channel_name ~= _M.cfg.channel_name then
		_dbg.Info( "CODEC", "Changed the NDI channel name to: group=", group_name, ", channel=", channel_name )
		changed = true
		_M.cfg.group_name = group_name
		_M.cfg.channel_name = channel_name
		_M.cfg:__TRIGGER(true)
		--NDI.DECODING.disable_discovery()
	end

	if changed then
		coaf.ScheduleDelayedTask(function()
			NDI.DECODING.disable_discovery()

			--NOTE: 'set_SPLASH' is deprecated.
			--NDI.DECODING.set_SPLASH( {main_width=1920, main_height=1080, main_fourCC="SHQ7", preview_width=640, preview_height=360, preview_fourCC="shq7"} )

			if _G.glb_cfg and _G.glb_cfg.use_discovery_server then
				NDI.DECODING.enable_discovery( group_name, channel_name, "tcp,discovery_server=" .. (_G.glb_cfg.discovery_server or "") )
			else
				NDI.DECODING.enable_discovery(group_name, channel_name, "tcp")
			end
		end, 3)
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
	group_name = group_name or _M.cfg.group_name

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

function _M.SetDiscoveryServer(enable,addr)
	if _G.glb_cfg then
		if _G.glb_cfg.use_discovery_server ~= enable or (addr and _G.glb_cfg.discovery_server ~= addr) then
			_dbg.Info("CODEC", "Update/changed the discovery server by: using=", enable, ", address=", addr)
			_G.glb_cfg.use_discovery_server = enable
			if addr then
				_G.glb_cfg.discovery_server = addr
			end
			_G.glb_cfg:__TRIGGER(true)

			if _G.glb_cfg.use_discovery_server then
				discovery.SetDiscoveryServer(_G.glb_cfg.discovery_server)
			else
				discovery.SetDiscoveryServer("")
			end

			coaf.ScheduleDelayedTask( function()
				NDI.DECODING.disable_discovery()

				--NOTE: set_SPLASH is deprecated.
				--NDI.DECODING.set_SPLASH( {main_width=1920, main_height=1080, main_fourCC="SHQ7", preview_width=640, preview_height=360, preview_fourCC="shq7"} )

				if _G.glb_cfg.use_discovery_server then
					NDI.DECODING.enable_discovery( _M.cfg.group_name, _M.cfg.channel_name, "tcp,discovery_server=" .. (_G.glb_cfg.discovery_server or "") )
				else
					NDI.DECODING.enable_discovery( _M.cfg.group_name, _M.cfg.channel_name, "tcp" )
				end

				NDI.DECODING.cleanup({net = true})
				NDI.DECODING.config({ ndi_connection ="discovery_server=" ..( _G.glb_cfg.use_discovery_server and _G.glb_cfg.discovery_server or "") })
				NDI.DECODING.start()
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
------------------------------------------------------
--Keypad processing
------------------------------------------------------
-- Keypad input handler.

local preset_key_map = {
	[keysym.KEY_KP0] = {id = 0, NUML=1 },
	[keysym.KEY_KP1] = {id = 1, NUML=1 },
	[keysym.KEY_KP2] = {id = 2, NUML=1 },
	[keysym.KEY_KP3] = {id = 3, NUML=1 },
	[keysym.KEY_KP4] = {id = 4, NUML=1 },
	[keysym.KEY_KP5] = {id = 5, NUML=1 },
	[keysym.KEY_KP6] = {id = 6, NUML=1 },
	[keysym.KEY_KP7] = {id = 7, NUML=1 },
	[keysym.KEY_KP8] = {id = 8, NUML=1 },
	[keysym.KEY_KP9] = {id = 9, NUML=1 },
	[keysym.KEY_0] = { id = 0 },
	[keysym.KEY_1] = { id = 1 },
	[keysym.KEY_2] = { id = 2 },
	[keysym.KEY_3] = { id = 3 },
	[keysym.KEY_4] = { id = 4 },
	[keysym.KEY_5] = { id = 5 },
	[keysym.KEY_6] = { id = 6 },
	[keysym.KEY_7] = { id = 7 },
	[keysym.KEY_8] = { id = 8 },
	[keysym.KEY_9] = { id = 9 }
}

local key_ptz = {
	[79] = "left-down",    -- 1
	[80] = "down",         -- 2
	[81] = "right-down",  -- 3
	[75] = "left",         -- 4
	[76] = "home",         -- 5
	[77] = "right",       -- 6
	[71] = "left-up",      -- 7
	[72] = "up",           -- 8
	[73] = "right-up",    -- 9
	[78] = "zoom-in",      -- +
	[74] = "zoom-out",     -- +
	[9878] = "focus-near",     -- /+
	[9874] = "focus-far",     -- /-
	[5578] = " iris-up",     -- *+
	[5574] = "iris-down",     -- *-

}

local key_v = {}

function _M.__onKey( kbd, key, val, timestamp )
	local preset_item = preset_key_map[key]
	if kbd.NUML == 1 and preset_item then
		if val == 0 then --Switch when release key.
			if preset_item.NUML and kbd.NUML == preset_item.NUML then
				_M.SelectPreset(preset_item.id)
			elseif not preset_item.NUML then
				_M.SelectPreset(preset_item.id)
			end
		end
	elseif kbd.NUML == 0 then  -- 不亮
		if val == 2 and key == 96 and _M.tag and (tonumber(timestamp)-_M.tag)>=1 then
			-- if ledOffSum >=9 then
			if not io_leds.tally_led.id and io_leds.tally_led.color == "green" and io_leds.tally_led.status == "blink" then
				io_leds.TallyLightControl( nil, "green", "off" )
			else
				io_leds.TallyLightControl( nil, "green", "blink" )
			end
			_M.tag = nil
		elseif val == 1 then
			if #key_v < 3 then
				key_v[#key_v+1] = key
			end
			if #key_v == 2 then
				local key_str = ""
				for i = 1, 2 do
					key_str = key_str .. key_v[i]
				end
				key = tonumber(key_str)
			end

			if not io_leds.tally_led.id and io_leds.tally_led.color == "green" and io_leds.tally_led.status == "blink" then
				if key_ptz[key] then
					_M.Control(key_ptz[key],{})
				end
			end
			if key == 96 then
				_M.tag = tonumber(timestamp)
			end
		elseif val ==0 then
			for i = 1, #key_v do
				if key_v[i] == key then
					key_v[i] = nil
				end
			end

			if key ~= 76 then
				_M.Control("stop-all",{})
			end
			_M.tag = nil
		end
	elseif kbd.NUML == 1 then -- 亮
		if val == 0 and key == 69 and not io_leds.tally_led.id and io_leds.tally_led.color == "green" and io_leds.tally_led.status == "blink" then
			io_leds.TallyLightControl( nil, "green", "off" )
		end
	end
end


function _M.Control(action,params)
	if action == "up" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(0,speed)
	elseif action == "down" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(0,-speed)
	elseif action == "left" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(speed,0)
	elseif action == "right" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(-speed,0)
	elseif action == "left-up" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(speed,speed)
	elseif action == "left-down" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(speed,-speed)
	elseif action == "right-up" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(-speed,speed)
	elseif action =="right-down" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_pan_tilt_speed(-speed,-speed)
	elseif action == "zoom-in" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_zoom_speed(speed)
	elseif action == "zoom-out" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_zoom_speed(-speed)
	elseif action == "focus-near" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_focus_speed(speed)
	elseif action == "focus-far" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_focus_speed(-speed)
	elseif action == "focus-auto" then
		NDI.DECODING.ptz_auto_focus()
	elseif action == "save-preset" then
		local id = tonumber(params.id)
		NDI.DECODING.ptz_store_preset(id)
	elseif action == "load-preset" then
		local id = tonumber(params.id)
		NDI.DECODING.ptz_recall_preset(id,1)
	elseif action == "home" then
		NDI.DECODING.ptz_recall_preset(99,1)
	elseif action == "stop-all" then
		NDI.DECODING.ptz_pan_tilt_speed(0,0)
	elseif action == "stop-zoom" then
		NDI.DECODING.ptz_zoom_speed(0)
	elseif action == "stop-focus" then
		NDI.DECODING.ptz_focus_speed(0)
	elseif action == "focus" then
		local speed = tonumber(params.speed or 50)/100
		NDI.DECODING.ptz_focus(speed)
	end
	return true,{}
end

function _M.SetAudioLevel(level)
	level = level == "ebu" and 14 or 20
	NDI.DECODING.set_audio_level(level)
	_M.cfg.audio.audio_level = level
	_M.cfg:__TRIGGER(true)
	return true
end

function _M.GetAudioLevel()
	local data = "smpte"
	if _M.cfg.audio.audio_level == 14 then
		data = "ebu"
	end
	return data
end

return _M

