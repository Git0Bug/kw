local CO = require "api_coservice"
local MSG = require "api_msg"
local cjson = require "cjson"

local dset = {}
--------------------------------------
local function API_get(red, args)
	--TODO: Note, no used.
	MSG.OK()
	return true
end

local function API_list(red, args)
	local proxy = CO.GetProxy( "/auth", "systemctrl" )
	if not proxy then
		MSG.ERROR( "systemError" )
	else
		local r,users,err = proxy.GetUsers("web")
		proxy:Destroy()
		if not r or not users then
			-- MSG.ERROR( "Fail to get user! Error:" .. (err or "SYSTEM ERROR") )
			MSG.ERROR( "getUsersError" )
		else
			local rTable = {}
			local k,v
			for k,v in pairs(users) do
				table.insert( rTable, {
					id = k,
					alias = v.name or k,
					web = v.enable_web,
					api = v.enable_api,
					create_time = v.createTime or "1970-01-01 00:00:00"
				})
			end
			table.sort( rTable, function(a,b)
				return a.create_time <= b.create_time
			end)

			MSG.OK("", {
				data = rTable
			})
		end
	end
	return true
end

math.randomseed(string.reverse(tostring(os.time())))
local function get_random_key()
	local rmnumber = os.time() .. math.random(1, 100)
	return ngx.md5(rmnumber .. "XVBKBLL7C9")                                                        
end

local session_dict = {}

local function API_login(red, args, skip)
	if args and args.username and not args.user then
		args.user = args.username
	end

	local proxy = CO.GetProxy( "/auth", "systemctrl" )
	if not proxy then
		MSG.ERROR( "systemError" )
	elseif tostring(args.user) ~= "" and tostring(args.password) ~= "" then
		local r,done,err = proxy.Auth("web", args.user, args.password, skip and "enable_api" or "enable_web")
		if not r or not done then
			-- MSG.ERROR( "Login fail! Error:" .. (err or "SYSTEM ERROR") )
			MSG.ERROR( "loginError" )
		else
			local accept_eula = err and 1 or 0
			r, done, err = proxy.GetUserInfo( "web", args.user )
			local session = skip and (get_random_key() .. args.user) or ""
			MSG.OK( "", {
				data = {
					token = ngx.md5( "NewTekSanAntonio:" .. args.user .. ":" .. (args.password or "") .. session),
					alias = done and done.name or args.user,
					software = accept_eula,
					session = skip and session or nil,
				}
			})

			if skip then
				for k, v in pairs(session_dict) do
					if v.user == args.user then
						session_dict[k] = nil
						break
					end
				end

				session_dict[session] = {
					time = os.time(),
					user = args.user,
					password = args.password,
				}
			end

		end
		proxy:Destroy()
	else
		proxy:Destroy()
		MSG.ERROR( "authCheckError" )
	end
	return true
end

local HTTPAPIAuthorization

--TODO: 定时清除 session_dict中的无效数据
local function check_session(args)
	if args.head and args.head.platform and args.head.platform == "this-is-made-by-kiloview-for-platform-login" then
		MSG.OK()
		return true
	end

	if HTTPAPIAuthorization ~= nil and HTTPAPIAuthorization == false then
		return true
	end

	local proxy = CO.GetProxy("/", "systemctrl")
	if proxy then
		local _, skip = proxy.GetHTTPAPIAuthorization()
		HTTPAPIAuthorization = skip
		if not skip then
			return true
		end
	end

	local token = args["api-token"] or ngx.var["cookie_token"] or (args.head and args.head["api-token"])
	local session = args["api-session"] or ngx.var["cookie_session"] or (args.head and args.head["api-session"])

	if not session or not token or token == "" or session == "" then
		ngx.say('{"result":"auth-failed","msg":"Invalid session or token"}')
		return nil
	end

	if not session_dict[session] then
		ngx.say('{"result":"auth-failed","msg":"Not exists session infomation"}')
		return nil
	end

	local time = session_dict[session].time
	if not time or (os.time() - time) >= 60 * 10 then
		session_dict[session] = nil
		ngx.say('{"result":"auth-failed","msg":"Session is timeout"}')
		return nil
	end

	local user = session_dict[session].user
	local password = session_dict[session].password

	if ngx.md5("NewTekSanAntonio:" .. user .. ":" .. (password or "") .. session) ~= token then
		ngx.say('{"result":"auth-failed","msg":"Session is not matching with token"}')
		return nil
	end

	session_dict[session].time = os.time()

	return true
end

local function API_session(red, args)
	if args.head and args.head.platform and args.head.platform == "this-is-made-by-kiloview-for-platform-login" then
		MSG.OK()
		return true
	end

	local cookie_user = ngx.var["cookie_user"]
	local cookie_token = ngx.var["cookie_token"]
	if not cookie_user or not cookie_token or cookie_user == "" or cookie_token == "" then
		MSG.ERROR( "Verfication error: 1" )
	else
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r, done, err = proxy.GetUserInfo( "web", cookie_user )
			if not r or not done then
				MSG.ERROR( "Verification error: 2" )
			else
				if ngx.md5( "NewTekSanAntonio:" .. cookie_user .. ":" .. (done.password or "") ) == cookie_token then
					MSG.OK()
				else
					MSG.ERROR( "Verification error: 3" )
				end
			end
			proxy:Destroy()
		end
	end
	return true
end
--------------------------------------

local function API_modify(red, args)
	if args and (args.id or args.username) then
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r,done,err = proxy.ChangeUser( "web", args.id or args.username, {
				enable_api = (args.api and args.api == "true") ,
				enable_web = (args.web and args.web == "true"),
				password = args.password,
				name = args.alias
			})
			proxy:Destroy()
			if r and done then
				MSG.OK()
			else
				-- MSG.ERROR( "Fail to modify user, with error: " .. (err or "SYSTEM ERROR") )
				MSG.ERROR( "modifyUserError" )
			end
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

local function API_add(red, args)
	if args and args.id then
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r,done,err = proxy.CreateUser( "web", args.id, {
				enable_api = args.api == "true",
				enable_web = args.web == "true",
				password = args.password,
				name = args.alias
			})
			proxy:Destroy()
			if r and done then
				MSG.OK()
			else
				-- MSG.ERROR( "Fail to create user with error: " .. (err or "SYSTEM ERROR") )
				MSG.ERROR( "createUserError")
			end
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

local function API_remove(red, args)
	if args and args.ids then
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r,done,err
			if type(args.ids) == "string" then
				r,done,err = proxy.RemoveUser("web", args.ids )
			elseif type(args.ids) == "table" then
				local i,v
				for i,v in pairs(args.ids) do
					r,done,err = proxy.RemoveUser("web", v )
				end
			else
				r = false
				done = false
				err = "Invalid user ID"
			end

			proxy:Destroy()
			if r and done then
				MSG.OK()
			else
				-- MSG.ERROR( "Fail to remove user with error: " .. (err or "SYSTEM ERROR") )
				MSG.ERROR( "delUserError" )
			end
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

local function API_software(red, args)
	if args and (args.id or args.user) then
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r,done,err = proxy.ChangeUser( "web", args.id or args.user, {
				accept_eula = args.software and tonumber(args.software) ~= 0
			})
			proxy:Destroy()
			MSG.OK("")
		end
	else
		MSG.ERROR( "invalidArgError" )
	end
	return true
end

local function API_software_status(red, args)
	local cookie_user = ngx.var["cookie_user"]
	if args.head and args.head.platform and args.head.platform == "this-is-made-by-kiloview-for-platform-login" then
		cookie_user = "admin"
	end

	if not cookie_user and args and args.user then
		cookie_user = args.user
	end

	if not cookie_user or cookie_user == "" then
		MSG.OK( "", {
			data = {
				err_flag = "no-user",
				software = 1 --Don't bother UI.
			}
		})
	else
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.OK( "", {
				data = {
					err_flag = "system",
					user = cookie_user,
					software = 1 --Don't bother UI.
				}
			})
		else
			local r, done, err = proxy.GetUserInfo( "web", cookie_user, true ) --Request EULA status.
			if not r or not done then
				MSG.OK( "", {
					data = {
						err_flag = "verify-user",
						user = cookie_user,
						software = 1 --Don't bother UI.
					}
				})
			else
				MSG.OK( "", {
					data = {
						user = cookie_user,
						software = err and 1 or 0
					}
				})
			end
			proxy:Destroy()
		end
	end
	return true
end

local function API_accept_eula(red, args)
	local user_id
	local token
	if args then
		user_id = args["session-id"] or args["user"]
		token = args["auth-token"] or args["token"]
	end
	if not user_id or not token then
		-- MSG.ERROR( "Verfication error: Invalid arguments" )
		MSG.ERROR("invalidArgError")
	else
		local proxy = CO.GetProxy( "/auth", "systemctrl" )
		if not proxy then
			MSG.ERROR( "systemError" )
		else
			local r, done, err = proxy.GetUserInfo( "web", user_id )
			if not r or not done then
				MSG.ERROR( "Verification error: Invalid session/user ID" )
			else
				if ngx.md5( "NewTekSanAntonio:" .. user_id .. ":" .. (done.password or "") ) == token then
					proxy.GlobalAcceptEULA()
					MSG.OK()
				else
					MSG.ERROR( "Verification error: Authenticate failed" )
				end
			end
			proxy:Destroy()
		end
	end
	return true
end

local function API_setVerification(_, args)
	local skip = tostring(args.verification)
	if not skip or skip == "" then
		MSG.ERR("Invalid arguments!")
		return true
	end

	local proxy = CO.GetProxy("/", "systemctrl")
	if not proxy then
		MSG.ERROR("systemError")
		return true
	end

	skip = skip == "true"

	proxy.SetHTTPAPIAuthorization(skip)
	HTTPAPIAuthorization = skip
	MSG.OK("")
	return true
end

local function API_getVerification()
	local proxy = CO.GetProxy("/", "systemctrl")
	if not proxy then
		MSG.ERROR("systemError")
		return true
	end
	local is_ok, skip = proxy.GetHTTPAPIAuthorization()
	if not is_ok then
		MSG.ERROR("Fail to get Authorization infomation ")
		return true
	end
	HTTPAPIAuthorization = skip
	MSG.OK("", {data = {verification = skip}})
	return true
end

--------------------------------------
dset.APIS = dset.APIS or {}

dset.APIS["get"] = API_get
dset.APIS["modify"] = API_modify
dset.APIS["login"] = API_login
dset.APIS["session"] = API_session
dset.APIS["list"] = API_list
dset.APIS["add"] = API_add
dset.APIS["remove"] = API_remove
dset.APIS["software"] = API_software
dset.APIS["software_status"] = API_software_status
dset.APIS["accept_eula"] = API_accept_eula
dset.APIS["setVerification"] = API_setVerification
dset.APIS["getVerification"] = API_getVerification
dset.APIS["authorize"] = function(_, args)
	return API_login(_, args, true)
end
dset.check_session = check_session
--------------------------------------
return dset

