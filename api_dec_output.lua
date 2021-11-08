local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local _feat, features = pcall(require,"features")
if not _feat then
	features = {}
end

local dset = {
}
--------------------------------------
local function API_getSettings(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r_video,more_video = proxy.GetVideoFormatSetting()
		local r_audio,more_audio = proxy.GetAudioFormatSetting()
		local r_level,audio_level = proxy.GetAudioLevel()

		proxy:Destroy()
		local rslt = {}
		if not r_level or not audio_level then
			rslt.level = "smpte"
		else
			rslt.level = audio_level or "smpte"
		end

		if not r_video or not more_video then
			rslt.resolution = "auto"
			rslt.frameRate = 0
			rslt.hdmi_mode = "hdmi"
			rslt.colorspace = "auto"
			rslt.enable = 0
		else
			rslt.resolution = more_video.format or "auto"
			rslt.frameRate = more_video.frame_rate or 0
			rslt.hdmi_mode = more_video.mode or "hdmi"
			rslt.colorspace = "auto" --TODO
			rslt.enable = more_video.enable and 1 or 0
		end

		if not r_audio or not more_audio then
			rslt.audio_format = 0
			rslt.channels = 0
			rslt.mapping = {
			}
		else
			rslt.audio_format = more_audio.sample_rate or 0
			if type(more_audio.enable) == "boolean" and not more_audio.enable then
				rslt.audio_format = -1
			end

			rslt.channels = more_audio.no_channels
			local audio_map={}
			if type(more_audio.audio_mapping) == "table" then
				for i=1,8 do
					if more_audio.audio_mapping[i] then
						table.insert(audio_map, {output_channel=i, source_channel=more_audio.audio_mapping[i]})
					else
						table.insert(audio_map, {output_channel=i, source_channel=i})
					end
				end
			end
			rslt.mapping = audio_map
		end

		rslt.frame_rate = rslt.frameRate
		rslt.sample_rate = more_audio.sample_rate or 0
		MSG.OK("", {data=rslt})
		return true
	end
end

--------------------------------------
local function API_modifySettings(red, args)
	if not args then
		MSG.ERROR( "invalidArgError" )
		return true
	end

	local audio_set = {}
	local video_set = {}

	if args.resolution then
		video_set.format = args.resolution
	end
	if args.frameRate or args.frame_rate then
		video_set.frame_rate = tonumber(args.frameRate or args.frame_rate) or 0
	end
	if args.hdmi_mode then
		video_set.mode = args.hdmi_mode
	end
	

	if args.audio_format or args.sample_rate then
		audio_set.sample_rate = tonumber(args.audio_format or args.sample_rate) or 0
		if audio_set.sample_rate < 0 then
			audio_set.sample_rate = nil
			audio_set.enable = false
		else
			audio_set.enable = true
		end
	end

	if args.channels then
		audio_set.no_channels = tonumber(args.channels)
	end

	if type(args.mapping) == "table" then
		local converted_map = {}
		local idx
		for _x, v in pairs(args.mapping) do
			if type(v) == "table" and tonumber(v.output_channel) then
				idx = tonumber(v.output_channel)
				converted_map[idx] = tonumber(v.source_channel) or 0
			end
		end
		audio_set.audio_mapping = converted_map
	end

	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,done = proxy.SetVideoFormat(video_set)
		local r,done = proxy.SetAudioLevel(args.level or "smpte")
		local r,done = proxy.SetAudioFormat(audio_set)
		proxy:Destroy()
		MSG.OK()
		return true
	end
end
--------------------------------------
local function API_frameRate(red, args)
	if not features or not features.DISABLE_NTSC_FREQ then
		MSG.OK("",{
			data = {
				{ value=0, name="Auto" },
				{ value=60, name="60 Hz" },
				{ value=59.94, name="59.94 Hz" },
				{ value=50, name="50 Hz" },
				{ value=30, name="30 Hz" },
				{ value=29.97, name="29.97 Hz" },
				{ value=25, name="25 Hz" },
				{ value=24, name="24 Hz" },
				{ value=23.98, name="23.98 Hz" },
			}
		})
	else
		MSG.OK("",{
			data = {
				{ value=0, name="Auto" },
				{ value=60, name="60 Hz" },
				{ value=50, name="50 Hz" },
				{ value=30, name="30 Hz" },
				{ value=25, name="25 Hz" },
				{ value=24, name="24 Hz" }
			}
		})
	end
	return true
end
--------------------------------------
local function API_resolutions(red, args)
	MSG.OK("",{
		data = {
			{ value="auto", name="Auto" },
			{ value="deint", name="Auto Deinterlace" }
		}
	})
	return true
end
--------------------------------------
local function API_set_smoothness(_, args)
	local switch_mod = require "api_dec_switch"
	local func = switch_mod.APIS["modifySettings"]
	args.smooth = args.timeout

	return func(_, args)
end
--------------------------------------
local function API_get_smoothness()
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r,more = proxy.GetCurrentSettings()
		proxy:Destroy()
		if not r or not more then
			MSG.ERROR( "getSettingError" )
		else
			MSG.OK("",{data={
				timeout = more.smooth or 0
			}})
		end
		return true
	end
end

--------------------------------------
local function API_channelNumOptions(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, names = proxy.GetAudioChannelNames()
		proxy:Destroy()
		if not r or type(names) ~= "table" then
			names = {{value=1, name="Left"}, {value=2, name="Right"}}
		end
		MSG.OK("", {data=names})
		return true
	end
end

local function API_numOptions(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, opts = proxy.GetAudioChannelSupports()
		proxy:Destroy()
		if not r or type(opts) ~= "table" then
			opts = {{value=0, name="AUTO"}, {value=2, name="2"}}
		end
		MSG.OK("", {data=opts})
		return true
	end
end
--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_getSettings
dset.APIS["modify"] = API_modifySettings
dset.APIS["frameRate"] = API_frameRate
dset.APIS["resolutions"] = API_resolutions
dset.APIS["set_smoothness"] = API_set_smoothness
dset.APIS["get_smoothness"] = API_get_smoothness
dset.APIS["set"] = API_modifySettings
dset.APIS["outputChannelOptions"] = API_channelNumOptions
dset.APIS["numOptions"] = API_numOptions

--------------------------------------
return dset

