local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"

local dset = {}



local function API_ptzControl(red, args)
	local proxy = CO.GetProxy( "/ptz", "codec" )
	if not proxy then
		MSG.ERROR( "codecError" )
		return true
    else
        local action = nil
        if args and args.Action and args.Action ~= "" then
            action = args.Action:lower()
        end
        if not action then
            MSG.ERROR( "invalidArgError" )
            proxy:Destroy()
		    return true
        end
        local controlArgs = {
        }
        
        if action:match("preset") then
            local id = tonumber(args.id)
            if not id then
                MSG.ERROR( "invalidArgError" )
                proxy:Destroy()
		        return true
            end
            controlArgs.id = id
        else
            controlArgs.speed = args.speed and tonumber(args.speed)/100 
                
        end
        if action == "left" or action == "right" or action == "up" or action == "down" or  action == "left-up" or action == "left-down" or action == "right-up" or action == "right-down" then
            if not controlArgs.speed or controlArgs.speed == 0 then
                action = "stop-all"
            end
        end


		local r, data,err = proxy.Control(action,controlArgs)
		if r and data then
			MSG.OK("")
		else
			MSG.ERROR( "querySerError" )
		end
		proxy:Destroy()
		return true
	end
end 
--------------
--
dset.APIS = dset.APIS or {}
--
dset.APIS["ptzControl"] = API_ptzControl
--
return dset
--
