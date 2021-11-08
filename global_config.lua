local DC = require "supertable.declare"
local CONF = require "supertable.core"

local _M = {
	config_file = "/data/configs/global.conf"
}

--------------------------------------------

local global_template = DC.OBJ({
	working = DC.STR("encoding"),
	use_discovery_server = DC.BOOL(false),
	discovery_server = DC.STR("")
}) : __changed( function(conf)
	conf:TAB_SAVE()
end)

--------------------------------------------

function _M.Load()
	local conf = CONF.Create({}, global_template)
	conf:TAB_STORAGE( "file", { file = _M.config_file } )
	conf:TAB_LOAD()
	conf:TAB_RESET_CHANGE()
	return conf
end

-------------------------------------------------------

return _M


