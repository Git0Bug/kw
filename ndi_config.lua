local DC = require "supertable.declare"
local CONF = require "supertable.core"

local _M = {
	config_file = "/data/configs/ndi.conf"
}

--------------------------------------------

local ndi_template = DC.OBJ({
	group_name = DC.STR(""),
	channel_name = DC.STR("Channel-1"),
	connection = DC.STR("tcp"),
	mcast_prefix = DC.STR("239.255.0.0"),
	mcast_mask = DC.STR("255.255.0.0"),
	ttl = DC.INT(127),
	audio_source = DC.STR("hdmi"),
	audio_gain = DC.NUM(100),
	enc_quality = DC.INT(100),
	audio_channels = DC.INT(0),
	audio_mapping = DC.SET(DC.INT(0)),
	audio_level =  DC.INT(20),
	disable_signal_tally_id = DC.BOOL(false)
}) : __changed( function(conf)
	conf:TAB_SAVE()
end)

--------------------------------------------

function _M.Load()
	local conf = CONF.Create({}, ndi_template)
	conf:TAB_STORAGE( "file", { file = _M.config_file } )
	conf:TAB_LOAD()
	conf:TAB_RESET_CHANGE()
	return conf
end

-------------------------------------------------------

return _M


