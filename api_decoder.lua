
local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {}


local function API_get(red, args)

	local data=[[
	{
		"name": "Spanel Plus",
		"ip": "192.168.255.15",
		"resolution":"1920x1080P@59.94HZ",
		"mode":"Multicaset",
		"bitrate":90,
		"url":"192.168.0.7/index.html"
	}
	]]
	data=cjson.decode(data)
	MSG.OK("", {data = data})
	return true
end



local function API_add(red, args)
	if not args.id then
		MSG.ERROR( "invalidArgError" )
		return true
	end


	MSG.OK("")
	return true
end

local function API_scan(red, args)

	local data=[[
	[{
		"id": "1",
		"group": "kiloview",
		"children": [{
			"id": "11",
			"device_name": "Encoder",
			"channel_name": "2",
			"ip": "192.168.2.233",
			"series": "NDI",
			"enable": 0,
			"url": "http:192.168.0.1/index.html"
		},
		{
			"id": "12",
			"device_name": "PLUS",
			"channel_name": "2",
			"ip": "192.168.2.23",
			"series": "NDI",
			"enable": 0,
			"url": "http:192.168.0.1/index.html"
		}, {
			"id": "13",
			"device_name": "Encoder1",
			"channel_name": "2",
			"ip": "192.168.1.33",
			"series": "NDI",
			"enable": 1,
			"url": "http:192.168.0.1/index.html"
		}
		]
	}, {
		"id": "2",
		"group": "kiloview1",
		"children": [{
			"id": "21",
			"device_name": "Decoder",
			"channel_name": "2",
			"ip": "192.168.2.123",
			"series": "NDI-HX",
			"enable": 0,
			"url": "http:192.168.0.1/index.html"
		},
		{
			"id": "22",
			"device_name": "PLUS",
			"channel_name": "2",
			"ip": "192.168.2.23",
			"series": "NDI",
			"enable": 0,
			"url": "http:192.168.0.1/index.html"
		}, {
			"id": "23",
			"device_name": "Encoder1",
			"channel_name": "2",
			"ip": "192.168.1.33",
			"series": "NDI",
			"enable": 1,
			"url": "http:192.168.0.1/index.html"
		}
		]
	}]
	]]
	data=cjson.decode(data)
	MSG.OK("", {data = data})
	return true
end



local function API_output_get(red, args)

	local data=[[
	{
		"resolution": "1080P60",
		"hdmi_mode": "AUTO",
		"colorspace": "AUTO"
	}
	]]
	data=cjson.decode(data)
	MSG.OK("", {data = data})
	return true
end



local function API_output_modify(red, args)
	if not args.resolution or not args.hdmi_mode or not colorspace then
		MSG.ERROR("invalidArgError")
	else
		MSG.OK("")
	end
	return true
end

local function API_resolutions(red, args)

	local data=[[
	[{
		"value":"AUTO",
		"name":"自动"
	},{
		"value":"1080P60",
		"name":"1920x1080P 60Hz"
	},{
		"value":"1080P50",
		"name":"1920x1080P 50Hz"
	},{
		"value":"1080P30",
		"name":"1920x1080P 30Hz"
	},{
		"value":"1080P25",
		"name":"1920x1080P 25Hz"
	},{
		"value":"1080I60",
		"name":"1920x1080I 60Hz"
	},{
		"value":"1080I50",
		"name":"1920x1080I 50Hz"
	},{
		"value":"720P60",
		"name":"1280x720P 60Hz"
	},{
		"value":"720P50",
		"name":"1280x720P 50Hz"
	}]
	]]
	data=cjson.decode(data)
	MSG.OK("", {data = data})
	return true
end

local function API_preset(red, args)
	if not args then
		MSG.ERROR("invalidArgError")
	else
		MSG.OK("")
	end
	return true
end


local function API_preset_get(red, args)

	local data=[[
	[{
		"id": "1",
		"group_name": "kiloview",
		"device_name": "kiloview",
		"channel_name": "Channel-1",
		"ip": "192.168.2.15",
		"mode": "tcp",
		"url": "192.168.0.7/index.html",
		"enable": 1,
		"bitrate": 50,
		"online":"on"
	}, {
		"id": "2",
		"group_name": "kiloview",
		"device_name": "video-recorder-for-programsdsdasdasd",
		"channel_name": "Channel-1",
		"ip": "192.168.124.240",
		"mode": "udp",
		"url": "192.168.0.7/index.html",
		"enable": 1,
		"bitrate": 50,
		"online":"off"
	}, {
		"id": "3",
		"group_name": "kiloview",
		"device_name": "kiloview",
		"channel_name": "Channel-1",
		"ip": "192.168.31.35",
		"mode": "tcp",
		"url": "192.168.0.7/index.html",
		"enable": 1,
		"bitrate": 50,
		"online":"on"
	}]
	]]
	data=cjson.decode(data)
	MSG.OK("", {data = data})
	return true
end


local function API_preset_remove(red, args)
	if not args.id then
		MSG.ERROR("invalidArgError")
	else
		MSG.OK("")
	end
	return true
end


local function API_ptz_get(red, args)

	local data=[[
	{
		"presets":5,
		"pan_speed": 10,
		"tilt_speed": 20,
		"zoom_speed": 30,
		"focus_speed": 100,
		"iris_speed": 50
	}
	]]
	data=cjson.decode(data)
	MSG.OK("", {data = data})
	return true
end


local function API_ptz_modify(red, args)
	if not args.presets  or not args.pan_speed or not args.tilt_speed or not args.zoom_speed or not args.focus_speed or not args.iris_speed then
		MSG.ERROR("invalidArgError")
	else
		MSG.OK("")
	end
	return true
end


local function API_ptz_control(red, args)

	if not args then
		MSG.ERROR("invalidArgError")
	else
		MSG.OK("")
	end
	return true
end




dset.APIS = dset.APIS or {}

dset.APIS["current"] = API_current
dset.APIS["add"] = API_add
dset.APIS["scan"] = API_scan
dset.APIS["output_get"] = API_output_get
dset.APIS["output_modify"] = API_output_modify
dset.APIS["resolutions"] = API_resolutions
dset.APIS["preset_set"] = API_preset
dset.APIS["preset_get"] = API_preset_get
dset.APIS["preset_remove"] = API_preset_remove
dset.APIS["ptz_get"] = API_ptz_get
dset.APIS["ptz_modify"] = API_ptz_modify
dset.APIS["ptz_control"] = API_ptz_control


return dset

