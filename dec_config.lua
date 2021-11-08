local DC = require "supertable.declare"
local CONF = require "supertable.core"

local _M = {
	config_file = "/data/configs/dec.conf"
}

--------------------------------------------

local dec_template = DC.OBJ({
	group_name = DC.STR(""),
	channel_name = DC.STR("Decoding Channel"),

	video = DC.OBJ({
		enable = DC.BOOL(true),
		mode = DC.STR("hdmi"),
		format = DC.STR("auto"),
		frame_rate = DC.NUM(0)
	}),

	audio = DC.OBJ({
		enable = DC.BOOL(true),
		sample_rate = DC.INT(48000),
		no_channels = DC.INT(0),
		output = DC.STR("hdmi"),
		gain = DC.NUM(100),
		audio_mapping = DC.SET(DC.INT(0)),
		audio_level = DC.INT(20)
	}),

	manuals = DC.ARR( DC.STR("") ),
	groups = DC.ARR( DC.STR("") ),

	current = DC.OBJ({
		name = DC.STR(""),
		url = DC.STR(""),
		content = DC.STR("full"),
		group = DC.STR(""),
		preset_id = DC.STR(""),
		smooth = DC.INT(200),
		tally_pgm = DC.BOOL(false),
		tally_pvw = DC.BOOL(false),
		online = DC.BOOL(false) : __nosave(true),
		warning = DC.STR("") : __nosave(true)
	}),

	presets = DC.SET(
		DC.OBJ{
			name = DC.STR(""),
			url = DC.STR(""),
			group = DC.STR(""),
			content = DC.STR("full"),
			online = DC.BOOL(false) : __nosave(true),
			warning = DC.STR("") : __nosave(true)
		}
	),

	blank = DC.OBJ({
		color = DC.STR("#000000"),
		r = DC.INT(0) : __nosave(true) : __get( function(cfg,key,refVal)
			local rr
			--#rgb or #rgba
			rr = cfg.color:match("^#(%x)%x%x%x?$")
			if rr then
				return tonumber("0x" .. rr .. rr )
			end
			--#rrggbb(aa)
			rr = cfg.color:match("^#(%x%x)%x%x%x%x" )
			if rr then
				return tonumber( "0x" .. rr )
			end
			return 0
		end),

		g = DC.INT(0) : __nosave(true) : __get( function(cfg,key,refVal)
			local gg 
			--#rgb or #rgba
			gg = cfg.color:match("^#%x(%x)%x%x?$")
			if gg then
				return tonumber( "0x" .. gg .. gg )
			end
			--#rrggbb(aa)
			gg = cfg.color:match("^#%x%x(%x%x)%x%x" )
			if gg then
				return tonumber( "0x" .. gg )
			end
			return 0
		end),

		b = DC.INT(0) : __nosave(true) : __get( function(cfg,key,refVal)
			local bb 
			--#rgb or #rgba
			bb = cfg.color:match("^#%x%x(%x)%x?$")
			if bb then
				return tonumber( "0x" .. bb .. bb )
			end
			--#rrggbb(aa)
			bb = cfg.color:match("^#%x%x%x%x(%x%x)" )
			if bb then
				return tonumber( "0x" .. bb )
			end
			return 0
		end)
	})
}) : __changed( function(conf)
	conf:TAB_SAVE()
end)

--------------------------------------------

function _M.Load()
	local conf = CONF.Create({}, dec_template)
	conf:TAB_STORAGE( "file", { file = _M.config_file } )
	conf:TAB_LOAD()
	conf:TAB_RESET_CHANGE()
	return conf
end

--------------------------------------------

return _M


