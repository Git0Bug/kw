local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {}
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
local function API_get(red, args)
	local proxy = CO.GetProxy( "/", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
	else
		local r, src = proxy.GetAudioSource()
		local gain
		local channels, mapping
		r, channels, mapping = proxy.GetAudioChannel()
		if not r or not channels then
			channels = 0
		end
		
		local audio_map={}
		if type(mapping) == "table" then
			for i=1,8 do
				if mapping[i] then
					table.insert(audio_map, {encoding_channel=i, input_channel=mapping[i]})
				else
					table.insert(audio_map, {encoding_channel=i, input_channel=i})
				end
			end
		end

		r, gain = proxy.GetAudioGain()
		r,level = proxy.GetAudioLevel()
		proxy:Destroy()
		local data = {channels= channels, mapping=audio_map, signal= src or "hdmi", volume= gain or 100,level = level or "smpte" }
		MSG.OK("", {data = data})
		return true
	end
end

--------------------------------------
-- 修改音频选择
local function API_modify(red, args)
	if args then
		if args.signal or args.volume or args.channels or args.mapping or args.level then
			local proxy = CO.GetProxy( "/", "codec" )
			if not proxy then
				MSG.ERROR( "codecError" )
				return true
			else
				if args.signal then
					proxy.SelectAudioSource(args.signal)
				end
				if args.volume then
					proxy.SetAudioGain(tonumber(args.volume) or 100)
				end
				
				if args.channels or args.mapping then
					local converted_map = {}
					local idx
					if type(args.mapping) == "table" then
						for _x, v in pairs(args.mapping) do
							if type(v) == "table" and tonumber(v.encoding_channel) then
								idx = tonumber(v.encoding_channel)
								converted_map[idx] = tonumber(v.input_channel) or idx
							end
						end
					end

					--TODO: Need a CoAF bug fix here.
					proxy.SetAudioChannel(tonumber(args.channels) or -1, converted_map)
				end
				if args.level then
					proxy.SetAudioLevel(args.level or "smpte")
				end

				proxy:Destroy()
			end
		
			MSG.OK("")
			return true
		else
			MSG.OK("")
			return true
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["modify"] = API_modify
dset.APIS["channelNumOptions"] = API_channelNumOptions
dset.APIS["numOptions"] = API_numOptions

--------------------------------------
return dset
