local coaf=require "coaf.core"
local _dbg = require "coaf.debug"

local _M = {
	bitfiles = {
		["encoding"] = "/boot/enc_bit.bin",
		["decoding"] = "/boot/dec_bit.bin"
	}
}

function _M.Load(mode)
	mode = mode or "encoding"
	local bf = _M.bitfiles[mode]
	if not bf then
		bf = _M.bitfiles["encoding"]
	end

	local already_loaded
	local exist_flag_f = io.open( "/tmp/xdevcfg", "r" )
	if exist_flag_f then
		already_loaded = exist_flag_f:read("*l")
		exist_flag_f:close()
		if already_loaded ~= bf then
			already_loaded = nil
		end
	end

	if already_loaded then
		return true
	end

	local b = io.open( bf, "rb" )
	if not b then
		_dbg.Error( "BIT-LOADER", "Fail to open bit file:", bf )
		return false, "fail to open bit file"
	end

	local d = io.open( "/dev/xdevcfg", "wb" )
	if not d then
		b:close()
		_dbg.Error( "BIT-LOADER", "Fail to open PL device file of /dev/xdevcfg" )
		return false, "fail to open PL device"
	end

	local blk = b:read(4096)
	while blk do
		d:write(blk)
		blk = b:read(4096)
	end
	b:close()
	d:close()
	exist_flag_f = io.open( "/tmp/xdevcfg", "w" )
	if exist_flag_f then
		exist_flag_f:write( bf .. "\n" )
		exist_flag_f:close()
	end
	coaf.Sleep(1)
	return true
end

return _M

