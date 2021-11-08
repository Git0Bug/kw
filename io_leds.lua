local coaf=require "coaf.core"
local _dbg = require "coaf.debug"
local thread = require "coaf.thread"
local client = require "coaf.client"

local periphery = require "periphery"
local GPIO = periphery.GPIO
local posix_time = require "posix.time"

local IO_STEP_TIME = 0.166 --second
local RESTORE_TIME = 3000 --ms.

local FLAG_RESTORE = false

local _M = require "chips.iocfg"

local ptz = require "PtzManager.mod_PtzManager"

--Set the default step interval.
if not _M.IO_STEP_TIME then
	_M.IO_STEP_TIME = IO_STEP_TIME
end

--Set the default restore factory settings hold time.
if not _M.RESTORE_TIME then
	_M.RESTORE_TIME = RESTORE_TIME
end

--Default blink steps.
if type(_M.DEFAULT_BLINK_STEPS) ~= "table" then
	_M.DEFAULT_BLINK_STEPS = {false, false, false, true, true, true}
end

--Initial tally states.
_M.tally_flags = {
	tally = false,
	main = false,
	preview = false
}

_M.tally_led = {
	id = nil,
	color = nil,
	status = nil,
}

_M.disable_signal_tally_id = false

local function onTallyAndPTZEvent( topic, msg, msgType )
	if msgType ~= "table" then
		_dbg.Warn( "IO-LEDS", "Got invalid tally-ptz event message of type:", msgType )
		return
	end

	if msg.control == "tally" then
		_dbg.Info( "TALLY-PTZ", "Control", msg.led, " to state:", msg.state )
		if msg.led == "TALLY" then
			_M.tally_flags.tally = (msg.state == "on")
		elseif msg.led == "MAIN" then
			_M.tally_flags.main = (msg.state == "on")
		elseif msg.led == "PREVIEW" then
			_M.tally_flags.preview = (msg.state == "on")
		end

		if _M.tally_flags.main then
			_M.TallyLightControl( nil, "red", "on" )
			_M.TallyLightControl( nil, "green", "off" )
		elseif _M.tally_flags.tally or _M.tally_flags.preview then
			_M.TallyLightControl( nil, "red", "off" )
			_M.TallyLightControl( nil, "green", "on" )
		else
			_M.TallyLightControl( nil, "red", "off" )
			_M.TallyLightControl( nil, "green", "off" )
		end
	elseif msg.control == "ptz" then
		local ptz_args = msg.ptz_args
		--local pt = require "pl.pretty"
		--pt.dump(ptz_args)

		--TODO: PTZ控制命令处理 [ ptz_args.<以下参数> ] :
		--action = "ntk_ptz_zoom", zoom = 0.0 .. 1.0
		--action = "ntk_ptz_zoom_speed", zoom_speed = -1.0 .. 1.0
		--action = "ntk_ptz_pan_tilt_speed", pan_speed = -1.0 .. 1.0, tilt_speed = -1.0 .. 1.0
		--action = "ntk_ptz_pan_tilt", pan = -1.0 .. 1.0, tilt = -1.0 .. 1.0
		--action = "ntk_ptz_store_preset", index = 0 .. 99
		--action = "ntk_ptz_recall_preset", index = 0 .. 99, speed = 0.0 .. 1.0
		--action = "ntk_ptz_flip", enabled = true | false
		--action = "ntk_ptz_focus", mode = "auto"
		--action = "ntk_ptz_focus", mode = "manual", distance = 0.0 .. 1.0
		--action = "ntk_ptz_focus_speed", focus_speed = -1.0 .. 1.0
		--action = "ntk_ptz_white_balance", mode = "auto"
		--action = "ntk_ptz_white_balance", mode = "indoor"
		--action = "ntk_ptz_white_balance", mode = "outdoor"
		--action = "ntk_ptz_white_balance", mode = "oneshot"
		--action = "ntk_ptz_white_balance", mode = "manual", red = 0.0 .. 1.0, blue = 0.0 .. 1.0
		--action = "ntk_ptz_exposure", mode = "auto"
		--action = "ntk_ptz_exposure", mode = "manual", value = 0.0 .. 1.0
		-- 判断收到的数据是否和上次一样
		if _M.action and ptz_args.action == _M.action.action then
			if ptz_args.action == "ntk_ptz_pan_tilt_speed" then
				if ptz_args.pan_speed ~= 0 and ptz_args.tilt_speed ~= 0 then
					if math.abs(ptz_args.pan_speed-_M.action.pan_speed ) <= 0.03 and math.abs(ptz_args.tilt_speed-_M.action.tilt_speed ) <= 0.03 then
						return
					end
				elseif ptz_args.pan_speed ~=0 or ptz_args.tilt_speed ~= 0 then
					if not (math.abs(ptz_args.pan_speed-_M.action.pan_speed ) > 0.03 or math.abs(ptz_args.tilt_speed-_M.action.tilt_speed ) > 0.03) then
						return
					end
				elseif ptz_args.pan_speed == 0 and ptz_args.tilt_speed == 0 then
					if ptz_args.pan_speed == _M.action.pan_speed and ptz_args.tilt_speed == _M.action.tilt_speed then
						return
					end
				end
			elseif ptz_args.action == "ntk_ptz_zoom_speed" then
				if (ptz_args.zoom_speed > 0 and _M.action.zoom_speed > 0) or  (ptz_args.zoom_speed < 0 and _M.action.zoom_speed < 0) then
					if math.abs(ptz_args.zoom_speed - _M.action.zoom_speed) <= 0.03 then
						return
					end
				end
			elseif  ptz_args.action == "ntk_ptz_focus" then
				if ptz_args.mode == "manual" and ptz_args.mode == _M.action.mode then
					if math.abs(ptz_args.distance - _M.action.distance) < 0.008 then
						return
					end
				end
			end
		end
		_M.action = ptz_args

		---------------------------------------------------------



		local state,params
		-- 放大缩小
		-- zoom_speed = -1.0 (zoom outwards) ... +1.0 (zoom inwards)
		if ptz_args.action == "ntk_ptz_zoom_speed" then
			if ptz_args.zoom_speed ~=  0 then
				if ptz_args.zoom_speed < 0 then
					state = "zoom-out"
					params = {
						speed = -ptz_args.zoom_speed,
					}
				elseif ptz_args.zoom_speed > 0 then
					state = "zoom-in"
					params = {
						speed = ptz_args.zoom_speed,
					}
				end
			else
				state = "stop-all"
			end
		elseif ptz_args and ptz_args.action == "ntk_ptz_pan_tilt_speed" then

		-- 方向
		-- pan_speed = -1.0 (moving right) ... 0.0 (stopped) ... +1.0 (moving left)
		-- tilt_speed = -1.0 (down) ... 0.0 (stopped) ... +1.0 (moving up)
			if ptz_args.pan_speed ~= 0 and ptz_args.tilt_speed ~= 0 then
				if ptz_args.pan_speed < 0 and ptz_args.tilt_speed < 0 then
					state = "right-down"
				elseif ptz_args.pan_speed > 0 and ptz_args.tilt_speed > 0 then
					state = "left-up"
				elseif ptz_args.pan_speed < 0 and ptz_args.tilt_speed > 0 then
					state = "right-up"
				elseif ptz_args.pan_speed > 0 and ptz_args.tilt_speed < 0 then
					state = "left-down"
				end
				params = {
					pan_speed = math.abs(ptz_args.pan_speed),
					tilt_speed = math.abs(ptz_args.tilt_speed),
				}
			elseif (ptz_args.pan_speed ~= 0 and ptz_args.tilt_speed == 0) or (ptz_args.tilt_speed ~= 0 and ptz_args.pan_speed == 0) then
				if  ptz_args.pan_speed < 0 then
					state = "right"
					params = {
						pan_speed = -ptz_args.pan_speed,
					}
				elseif ptz_args.pan_speed > 0 then
					state = "left"
					params = {
						pan_speed = ptz_args.pan_speed,
					}
				elseif ptz_args.tilt_speed < 0 then
					state = "down"
					params = {
						pan_speed = -ptz_args.tilt_speed,
					}
				elseif ptz_args.tilt_speed > 0 then
					state = "up"
					params = {
						pan_speed = ptz_args.tilt_speed,
					}
				end
			else
				state = "stop-all"
			end

		elseif ptz_args.action == "ntk_ptz_store_preset" then

		-- 储存预设
		-- index = 0 .. 99

			if ptz_args.index >= 0 and ptz_args.index <= 99 then
				state = "save-preset"
				params = {
					id = ptz_args.index,
				}
			end
		elseif ptz_args.action == "ntk_ptz_recall_preset" then
		-- 调用预设
		-- index = 0 .. 99
			if ptz_args.index >= 0 and ptz_args.index < 99 then
				state = "load-preset"
				params = {
					id = ptz_args.index,
					speed = ptz_args.speed
				}
			elseif ptz_args.index == 99 then
				state = "home"
			end
		elseif ptz_args.action == "ntk_ptz_focus" then
		-- 聚焦
			if ptz_args.mode == "auto" then
				state = "focus-auto"
			elseif ptz_args.mode == "manual" then
				state = "focus"
				params = {
					speed = ptz_args.distance
				}
			end
		elseif ptz_args.action == "ntk_ptz_focus_speed" then
			if ptz_args.focus_speed ~= 0 then
				if ptz_args.focus_speed < 0 then
					state = "focus-far"
					params = {
						speed = -ptz_args.focus_speed
					}
				elseif ptz_args.focus_speed > 0 then
					state = "focus-near"
					params = {
						speed = ptz_args.focus_speed
					}
				end
			else
				state = "stop-all"
			end
		end
		if state then
			ptz.Control(state,params)
		end
	end
end

local function io_leds_thread( thrObj )
	local last_button_hold = nil
	_dbg.Info( "IO-LED", "Control thread is started..." )
	while not thrObj.terminated do
		--Check button
		if type(_M.reset_button) == "table" and _M.reset_button.drv then
			local val = _M.reset_button.drv:read()
			if not val then
				local now = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )
				if not last_button_hold then
					last_button_hold = now

					_M.on_demo.on = "restore"
					_M.on_demo.stage_index = 1
					_M.on_demo.hold_count = nil

				else
					local holdtime = (now.tv_sec - last_button_hold.tv_sec) * 1000
					holdtime = holdtime + (now.tv_nsec - last_button_hold.tv_nsec)/1000000

					if holdtime >= _M.RESTORE_TIME then
						FLAG_RESTORE = true

						_M.on_demo.on = nil
						_M.on_demo.stage_index = nil
						_M.on_demo.hold_count = nil

						if type(_M.tally_leds) == "table" then
							for i=1, #_M.tally_leds do
								_M.tally_leds[i].red.state = "off"
								_M.tally_leds[i].green.state = "off"
								thrObj.terminated = true --Exit current loop after LED control.
							end
						end
					end
				end
			else
				last_button_hold = nil
				if _M.on_demo.on ~= "startup" then
					_M.on_demo.on = nil
					_M.on_demo.stage_index = nil
					_M.on_demo.hold_count = nil
				end
			end
		end

		--On board LED.
		if type(_M.board_led) == "table" and _M.board_led.drv then
			if _M.board_led.state == "blink" then
				if not _M.board_led.blink_id then
					_M.board_led.blink_id = 1
				end
				local level = _M.board_led.blink_steps[ _M.board_led.blink_id ]
				_M.board_led.drv:write(level)
				_M.board_led.blink_id = _M.board_led.blink_id + 1
				if _M.board_led.blink_id > #_M.board_led.blink_steps then
					_M.board_led.blink_id = 1
				end
			else
				_M.board_led.drv:write( _M.board_led.state == "on" )
			end
		end

		--Tally lights.
		if type(_M.on_demo) == "table" and _M.on_demo.on and _M.on_demo.stages[_M.on_demo.on] then
			local stage = _M.on_demo.stages[_M.on_demo.on]
			if not _M.on_demo.stage_index then _M.on_demo.stage_index = 1 end
			local idx = _M.on_demo.stage_index
			if idx > #stage then
				_M.on_demo.on = nil
				_M.on_demo.stage_index = nil
				_M.on_demo.hold_count = nil
			else
				for i=idx, #stage do
					if stage[i][1] == "HOLD" then
						if not _M.on_demo.hold_count then
							_M.on_demo.hold_count = stage[i][2] or 1
						else
							_M.on_demo.hold_count = _M.on_demo.hold_count - 1
						end
						if _M.on_demo.hold_count <= 1 then
							_M.on_demo.stage_index = _M.on_demo.stage_index + 1
							_M.on_demo.hold_count = nil
						end
						break
					else
						stage[i][1]:write( stage[i][2] )
						_M.on_demo.stage_index = _M.on_demo.stage_index + 1
					end
				end
			end
		else
			local i
			for i=1, #_M.tally_leds do
				if _M.tally_leds[i].red.drv then
					if  _M.tally_leds[i].red.state == "blink" then
						if not _M.tally_leds[i].red.blink_id then
							_M.tally_leds[i].red.blink_id = 1
						end

						local steps = _M.tally_leds[i].red.blink_steps or _M.tally_leds[i].blink_steps or _M.tally_leds.blink_steps
						_M.tally_leds[i].red.drv:write( steps[ _M.tally_leds[i].red.blink_id ] )

						_M.tally_leds[i].red.blink_id = _M.tally_leds[i].red.blink_id + 1
						if _M.tally_leds[i].red.blink_id > #steps then
							_M.tally_leds[i].red.blink_id = 1
						end
					else
						_M.tally_leds[i].red.drv:write( not (_M.tally_leds[i].red.state == "on") )
					end
				end

				if _M.tally_leds[i].green.drv then
					if _M.tally_leds[i].green.state == "blink" then
						if not _M.tally_leds[i].green.blink_id then
							_M.tally_leds[i].green.blink_id = 1
						end

						local steps = _M.tally_leds[i].green.blink_steps or _M.tally_leds[i].blink_steps or _M.tally_leds.blink_steps
						_M.tally_leds[i].green.drv:write( steps[ _M.tally_leds[i].green.blink_id ] )

						_M.tally_leds[i].green.blink_id = _M.tally_leds[i].green.blink_id + 1
						if _M.tally_leds[i].green.blink_id > #steps then
							_M.tally_leds[i].green.blink_id = 1
						end
					else
						_M.tally_leds[i].green.drv:write( not (_M.tally_leds[i].green.state == "on") )
					end
				end
			end
		end

		-- Signal LED control.
		if type(_M.signal) == "table" and type(_M.signal.drv) == "table" then
			if _M.signal.red == "blink" or _M.signal.green == "blink" then
				if not _M.signal.blink_id then
					_M.signal.blink_id = 1
				end
				local level = _M.signal.blink_steps[ _M.signal.blink_id ]

				if _M.signal.drv.red and _M.signal.red == "blink" then
					_M.signal.drv.red:write(level)
				end

				if _M.signal.drv.green and _M.signal.green == "blink" then
					_M.signal.drv.green:write(level)
				end

				--Any blink.
				if _M.signal.drv.any then
					--_M.signal.drv.any:write(level)
					_M.signal.drv.any:write(false) --Alway make it on.
				end

				_M.signal.blink_id = _M.signal.blink_id + 1
				if _M.signal.blink_id > #_M.signal.blink_steps then
					_M.signal.blink_id = 1
				end
			else
				if _M.signal.drv.red then
					_M.signal.drv.red:write(not (_M.signal.red == "on"))
				end
				if _M.signal.drv.green then
					_M.signal.drv.green:write(not (_M.signal.green == "on"))
				end
				if _M.signal.drv.any then
					_M.signal.drv.any:write(not (_M.signal.green == "on" or _M.signal.red == "on"))
				end
			end
		end

		coaf.Sleep( _M.IO_STEP_TIME )
	end
	_dbg.Info( "IO-LED", "Control thread is terminated!" )
end

function _M.Init()
	if type(_M.board_led) == "table" and type(_M.board_led.blink_steps) ~= "table" then
		_M.board_led.blink_steps = _M.DEFAULT_BLINK_STEPS
	end

	if type(_M.tally_leds) == "table" and type(_M.tally_leds.blink_steps) ~= "table" then
		_M.tally_leds.blink_steps = _M.DEFAULT_BLINK_STEPS
	end

	if type(_M.signal) == "table" and type(_M.signal.blink_steps) ~= "table" then
		_M.signal.blink_steps = _M.DEFAULT_BLINK_STEPS
	end

	if type(_M.fan) == "table" then
		if #_M.fan > 0 then
			for i=1,#_M.fan do
				if _M.fan[i].drv then
					_M.fan[i].drv:start(_M.fan[i].speed_table or _M.fan.speed_table)
				end
			end
		else
			if _M.fan.drv then
				_M.fan.drv:start(_M.fan.speed_table)
			end
		end
	end

	_G.g_event:Subscribe( "tally_ptz", onTallyAndPTZEvent )
	_M.ioThread = thread.New( io_leds_thread )
	_M.ioThread:Start()
end

--Period check.
function _M.Step()
	if FLAG_RESTORE then
		FLAG_RESTORE = false
		local sys_client = client.New( "systemctrl", "local", nil, 3 )
		if not sys_client then
			_dbg.Error( "RESTORE", "Fail to connect systemctrl service!" )
		else
			local proxy = sys_client:CreateProxy( "/", true ) --Exclusive.
			if not proxy then
				_dbg.Error( "RESTORE", "Fail to create systemctrl:/ service proxy" )
				sys_client:Destroy()
			else
				_dbg.Info( "RESTORE", "Restored factory settings since pressed restore button!" )
				proxy.RestoreFactory()
				proxy:Destroy()
			end
		end
	end
end

function _M.SetDisableSignalTallyId(dis)
	_M.disable_signal_tally_id = dis
	_M.TallyLightControl() --Just update.
end

function _M.TallyLightControl(id, color, status)
	id = tonumber(id)
	if status then
		if not id or id < 1 or id > #_M.tally_leds then
			--_M.on_demo.on = nil
			local i
			for i=1, #_M.tally_leds do
				if color ~= "red" and color ~= "green" then
					_M.tally_leds[i].red.state = status
					_M.tally_leds[i].green.state = status
				else
					_M.tally_leds[i][color].state = status
				end
			end
		else
			--_M.on_demo.on = nil
			if color ~= "red" and color ~= "green" then
				_M.tally_leds[id].red.state = status
				_M.tally_leds[id].green.state = status
			else
				_M.tally_leds[id][color].state = status
			end
		end
		_M.tally_led.id = id
		_M.tally_led.color = color
		_M.tally_led.status = status
	end

	if type(_M.signal) == "table" then
		if _M.signal.tally_light_id and type(_M.tally_leds) == "table" then
			if not (_M.tally_flags.tally or _M.tally_flags.main or _M.tally_flags.preview) then
				local ids
				if type(_M.signal.tally_light_id) == "table" then
					ids = _M.signal.tally_light_id
				else
					ids = { _M.signal.tally_light_id }
				end

				for i = 1, #ids do
					_M.tally_leds[ ids[i] ].red.state = _M.disable_signal_tally_id and "off" or _M.signal.red
					_M.tally_leds[ ids[i] ].green.state = _M.disable_signal_tally_id and "off" or _M.signal.green
					_M.tally_leds[ ids[i] ].red.blink_id = 1
					_M.tally_leds[ ids[i] ].green.blink_id = 1
				end
			end
		end
	end
end

function _M.GetLed(id,color)
	id = tonumber(id)
	local led_tab = {}
	if not id or id < 1 or id > #_M.tally_leds then
		for i=1, #_M.tally_leds do
			led_tab[i] = _M.tally_leds[i][color].state
		end
	else
		led_tab[id] =_M.tally_leds[id][color].state
	end
	return led_tab
end

function _M.SetLightStatus( status )
	if status == "reset" then
		_M.on_demo.on = "reset"
		_M.on_demo.stage_index = 1
		_M.on_demo.hold_count = nil

	elseif status == "reboot" or status == "restore" or status == "off" then
		_M.on_demo.on = nil
		local i
		for i=1, #_M.tally_leds do
			_M.tally_leds[i].red.state = "off"
			_M.tally_leds[i].green.state = "off"
		end
	end
end

function _M.SetSignalStatus( status )
	if not _M.signal then
		return
	end

	if status == "sd" or status == "hd" then
		_M.signal.green = "blink"
		_M.signal.red = "off"
	elseif status == "4k" then
		_M.signal.green = "blink"
		_M.signal.red = "blink"
	elseif status == "4k60" then
		_M.signal.green = "off"
		_M.signal.red = "blink"
	else
		_M.signal.green = "off"
		_M.signal.red = "off"
	end

	_M.TallyLightControl() --Just update.
end

--TODO: Specify fan index but now only support one.
function _M.GetFanSpeed()
	if type(_M.fan) == "table" then
		if #_M.fan > 0 then
			if _M.fan[1].drv then
				return _M.fan[1].drv:read()
			else
				return nil
			end
		else
			if _M.fan.drv then
				return _M.fan.drv:read()
			else
				return nil
			end
		end
	else
		return nil
	end
end

--TODO: Specify fan index but now only support one.
function _M.SetFanSpeed(speed)
	if type(_M.fan) == "table" then
		if #_M.fan > 0 then
			if _M.fan[1].drv then
				_M.fan[1].drv:enable(speed)
			end
		else
			if _M.fan.drv then
				_M.fan.drv:enable(speed)
			end
		end
	end
end

--TODO: Specify temperature sensor index but now only support one.
function _M.GetTemperature()
	if type(_M.temperature) == "table" then
		if #_M.temperature > 0 then
			if _M.temperature[1].drv then
				return _M.temperature[1].drv:read()
			else
				return nil
			end
		else
			if _M.temperature.drv then
				return _M.temperature.drv:read()
			else
				return nil
			end
		end
	else
		return nil
	end
end

return _M

