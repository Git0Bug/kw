local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"
local upload = require "resty.upload"

local VERINFO = require "version"

local STORE_PATH = "/tmp"

local dset = {}

local cached_versions


local function API_get(red, args)

	if not cached_versions or not cached_sn then
		local proxy = CO.GetProxy( "/", "systemctrl" )
		if proxy then
			local r
			r, cached_versions = proxy.GetVersion()
			proxy:Destroy()
		end
	end


	local f = io.popen( "/usr/bin/readlink -f /usr/lib/libndi.so", "r" )
	local ndi_ver = "v3"
	if f then
		local l = f:read("*l")
		f:close()
		ndi_ver = l:match(".+libndi%.so%.(.*)$")
		if not ndi_ver then
			ndi_ver = "v3"
		end
	end

	MSG.OK( "", {
		data = {
			firmwareVersion = VERINFO.FIRMWARE_VERSION or "0.0.0",
			hardwareVersion = cached_versions and cached_versions.HARDWARE_VERSION or VERINFO.HARDWARE_VERSION or "1.0",
			softwareVersion = VERINFO.SOFTWARE_VERSION or "0.0.0",
			ndiVersion = ndi_ver
		}
	})
	return true
end


local function checkPartType(res)
	if type(res) == "table" then
		local idr = res[1]:lower()
		if idr == "content-disposition" then
			local fieldname, filename = res[2]:match('name=%"(.*)%".*filename=%"(.*)%"')
			if not fieldname then
				fieldname = res[2]:match('name=%"(.*)%"')
			end
			if not fieldname then
				return nil
			end
			if not filename then
				return "field", fieldname
			else
				return "file", fieldname, filename
			end
		elseif idr == "content-type" then
			return idr, res[2] or ""
		else
			return nil
		end
	else
		return nil
	end
end

local function getUploadFile(args)
	args = args or {}
	local form,err = upload:new(8192)
	if not form then
		return nil, "Fail to upload file:" .. (err or "")
	end
	form:set_timeout(5*1000)        --5secs timeout

	local fieldType, fieldName
	local srcFileName
	local curFile

	while true do
		local typ, res, err = form:read()
		if not typ then
			if curFile then
				curFile:close()
			end
			return nil, "Fail read uploaded content"
		end

		if typ == "header" then
			local ftype,fname,filename = checkPartType(res)
			if ftype == "field" then
				fieldType = ftype
				fieldName = fname
				args[fieldName] = ""
			elseif ftype == "file" then
				fieldType = ftype
				fieldName = fname
				srcFileName = filename
				if srcFileName == "" then
					return nil, "Invalid firmware file (please check the file name)"
				end
				if not srcFileName:match("%.[Bb][Ii][Nn]$") then
					srcFileName = srcFileName .. ".bin"
				end

			elseif ftype == "content-type" then
				if fieldType ~= "file" then
					if curFile then
						curFile:close()
					end
					return nil, "Invalid uploaded content: Wrong 'Content-Type' location"

				--elseif fname ~= "application/octet-stream" then
				--	if curFile then
				--		curFile:close()
				--	end
				--	return nil, "Uploaded file must be '.bin' file"

				else
					local openerrormsg
					curFile, openerrormsg = io.open( STORE_PATH .. "/" .. srcFileName, "wb" )
					if not curFile then
						return nil, "Fail to create file"
					end
				end
			else
				filedType = nil
				fieldName = nil
				if curFile then
					curFile:close()
					curFile = nil
				end
			end
		elseif typ == "body" then
			if fieldType == "field" then
				args[fieldName] = args[fieldName] .. res
			elseif fieldType == "file" then
				if not curFile then
					return nil, "Upload fail"
				end
				curFile:write( res )
			end
		elseif typ == "part_end" then
			filedType = nil
			fieldName = nil
			if curFile then
				curFile:close()
				curFile = nil
			end
		elseif typ == "eof" then
			break
		end
	end

	if curFile then
		curFile:close()
	end

	if not srcFileName then
		return nil, "No uploaded file"
	end

	return srcFileName
end

local function API_upgrade(red, args)
	local srcFileName, err = getUploadFile(args)
	if not srcFileName then
		return false, err or "Upload error"
	end

	local proxy = CO.GetProxy( "/", "systemctrl", "local", 30 ) --This need 30seconds timeout, for purpose.
	if not proxy then
		os.execute( "/bin/rm -f " .. STORE_PATH .. "/" .. srcFileName )
		MSG.ERROR( "systemError" )
		return true
	end

	local r, done, reason, msg = proxy.ProcessFirmware( STORE_PATH .. "/" .. srcFileName )
	if not r or not done then
		proxy:Destroy()
		os.execute( "/bin/rm -f " .. STORE_PATH .. "/" .. srcFileName )
		MSG.ERROR( "Fail to process firmware upgrading! Error code: " .. (reason or "UNKNOWN") .. ", Error Message:" .. (msg or "NONE") )
		return true
	end
	
	proxy.Reboot(2)
	proxy:Destroy()
	MSG.OK()
	return true
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["upgrade"] = API_upgrade

--------------------------------------
return dset

