#!/usr/bin/env lua

--It will check and set DISABLE_4Kp60 later.
--According to NewTek requirement, now open all products 4Kp60 support
_G.DISABLE_4Kp60 = false
_G.DISABLE_4K = false

local coaf=require "coaf.core"
local _dbg = require "coaf.debug"
local thread = require "coaf.thread"

coaf.ChDir(coaf.GetAppDir(arg))

local socket = require "cosocket.core"
local service = require "coaf.service"
local client = require "coaf.client"
local adapter = require "coaf.cli_adapter.simple"

--NOTE: FIXME: avio.lua is copied from avio_xxx/avio.lua to chips/avio.lua, which 'xxx' is product specified.
local avio_chips = require "chips.avio"

local io_leds = require "io_leds"
local event = require "coaf.event"

local work_mode = "encoding"
local glb_cfg_module = require "global_config"
_G.glb_cfg = glb_cfg_module.Load()
if _G.glb_cfg and _G.glb_cfg.working then
	work_mode = _G.glb_cfg.working
end

local encoding
local decoding
local discovery

if work_mode == "decoding" then
	decoding = require "decoding"
	discovery = require "discovery"
else
	encoding = require "encoding"
end

local _x, features = pcall(require, "features")
if not _x or type(features) ~= "table" then
	features = nil
else
	if features.DISABLE_4K then
		_G.DISABLE_4K = true
	end
end

local withLog = false
local _x
for _x=1, #arg do
	if arg[_x] == "--log" then
		withLog = true
		break
	end
end

if withLog then
	-- ** initialize the log file **
	local roll = require "coaf.log.rollfile"
	os.execute( "/bin/mkdir -p /var/log/" )
	local logF = roll.Create("/var/log/codec.log")
	if not logF or not logF:init() then
		_dbg.Error("CODEC", "Fail to open log file: /var/log/codec.log, so the log messages should be output to console.")
		withLog = false
	else
		_dbg.AddLogger("logfile", logF, nil, nil)
	end
	-- ** log **
end

coaf.Init( "codec_service" )

if withLog then
	local stdio = require "coaf.log.stdio"
	stdio.SetDefaultFilterName( "CODEC" )
	stdio.Start()
end

service.InitSocket()
client.InitSocket( socket, adapter )

if work_mode == "decoding" then
_G.g_event = event.createNew( "ndi_decoding" )
else
_G.g_event = event.createNew( "ndi_encoding" )
end

_G.cfg_ptz = require("PtzManager.configs.ptz_configs").Load()
local mod_PtzManager = require "PtzManager.mod_PtzManager"

-- ** CoService **
local cosvc_Codec
------------------



local function for3000ms_PeriodCheck()
	local r,msg = pcall( function()
		mod_PtzManager.Check()
	end )
	if not r then
		_dbg.Error("CODEC", "Period checking error:", msg)
	end
end



-- **200ms period checker [normal check]**

--local for200ms_checking_flag
--NOTE: Since something update require long time and make thread yield, I **MUST**
--      flag it is working or not, to avoid re-entry.
local function for200ms_PeriodCheck()
	--if not for200ms_checking_flag then
		--for200ms_checking_flag = true
	local r,msg = pcall( function()
		avio_chips.Check()
		if encoding then
			encoding.Step()
		elseif decoding then
			decoding.Step()
		end
		io_leds.Step()
	end )
	if not r then
		_dbg.Error("CODEC", "Period checking error:", msg)
	end
		--for200ms_checking_flag = false
	--end
end

-- **50ms period checker [fast check]**
-- To check: [???]
local function for50ms_PeriodCheck()
end

-- ** Timers **
local for200msTimer
local for50msTimer

-- ** MATE (for avoid dead) **
local function get_mate_proxy()
	local proxy
	local cli
	cli = client.New( "codec_mate", "local", nil, 3 )
	if not cli then
		_dbg.Error( "CODEC", "Fail to create connection to service 'local/codec_mate'" )
		return nil
	end
	proxy = cli:CreateProxy("/", true) --Exclusive
	if not proxy then
		_dbg.Error( "CODEC", "Fail to create object proxy for 'local/codec_mate'" )
		cli:Destroy()
		return nil
	end
	return proxy
end

-- **Main entry**
local function Main(args)

	local bl = require "bitloader"
	bl.Load( work_mode )

	--NOTE: MUST first init encoding, to get correct hardware configurations.
	if encoding then
		encoding.Init()
	elseif decoding then
		decoding.Init()
	end

	mod_PtzManager.Init(coaf.CoAF_LOOP)

	cosvc_Codec = service.New( "codec", "unix:/var/run/codec.sock" )
	if cosvc_Codec then
		_dbg.Info( "CODEC", "CoService of 'codec' is created." )
		cosvc_Codec:CreateCoServerProxy()
		if encoding then
			cosvc_Codec:ExposeObject("/", encoding )
		elseif decoding then
			cosvc_Codec:ExposeObject("/", decoding )
			cosvc_Codec:ExposeObject("/discovery", discovery )
		end
		--For old compatible.
		cosvc_Codec:ExposeObject("/hdmi", avio_chips )

		--For old compatible.
		cosvc_Codec:ExposeObject("/sdi", avio_chips )

		--A new style for common usage.
		cosvc_Codec:ExposeObject("/avio", avio_chips )

		cosvc_Codec:ExposeObject("/io_leds", io_leds )

		cosvc_Codec:ExposeObject("/ptz", mod_PtzManager )
	else
		_dbg.Error( "CODEC", "Fail created CoService!" )
	end

	--for50msTimer = thread.NewTimer( for50ms_PeriodCheck, 0.01, 0.05 )
	--if for50msTimer then
	--	for50msTimer:start()
	--end

	for200msTimer = thread.NewTimer( for200ms_PeriodCheck, 0.01, 0.2 )
	for3000msTimer = thread.NewTimer( for3000ms_PeriodCheck, 0.01, 3 )

	if for200msTimer then
		for200msTimer:start()
	end

	if for3000msTimer then
		for3000msTimer:start()
	end

	local proxy = get_mate_proxy()
	if proxy then
		proxy.NotifyCodecReady()
		proxy:Destroy()
	end
end

coaf.Start(Main, arg)

if for200msTimer then
	for200msTimer:stop()
end

if for50msTimer then
	for50msTimer:stop()
end

if for3000msTimer then
	for3000msTimer:stop()
end


if work_mode == "decoding" then
event.free( "ndi_encoding" )
elseif decoding then
event.free( "ndi_decoding" )
end

--TODO: something cleanup.

_dbg.Print( "CODEC", "Service terminated." )

