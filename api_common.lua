local modules = require "api_modules"
local MSG = require "api_msg"

local module_name = ngx.var.module_name
local method_name = ngx.var.method_name

if not module_name or module_name == "" or not method_name or method_name == "" then
	MSG.ERROR( "ERROR: Invalid request module", { reason = "api:check", module = module_name, method = method_name } )
	return
end

local module = modules[ module_name ]
if not module or not module.APIS or not module.APIS[method_name] then
	MSG.ERROR( "ERROR: Invalid request method", { reason = "api:method", module = module_name, method = method_name } )
	return
end

local method = module.APIS[ method_name ]

local red = {"TODO"}

local args = {}
local args_get = ngx.req.get_uri_args()

if module_name == "firmware" and (method_name == "upgrade" or method_name == "fpgaUp") then
	ngx.log( ngx.INFO, "For upload file(s) processing" )
else
	ngx.req.read_body()
	local args_post = ngx.req.get_post_args()

	local req_headers = ngx.req.get_headers()
	args.head = { platform = req_headers and req_headers.platform or "" }
	for k, v in pairs(req_headers or {}) do
		args.head[k] = tostring(v):lower()
	end
	local content_type = req_headers and (req_headers["Content-Type"] or req_headers["content-type"]) or nil
	if content_type and content_type:match("application/json") then
		--Is JSON
		local cjson = require "cjson"
		local parsed_data={}
		for k,v in pairs(args_post) do
			local item=cjson.decode(k)
			if item then
				table.insert(parsed_data, item)
			end
		end

		if #parsed_data == 1 then
		--Just one json. (likely)
			args_post = parsed_data[1]
		else 
		--Unlikely
			args_post = parsed_data
		end
	end

	local k,v
	
	local arrIdx
	for k,v in pairs(args_post) do
		if type(k) == "number" then
			arrIdx = nil
		else
			arrIdx = k:match("(.*)%[%]")
		end
		if arrIdx then
			args[arrIdx] = v
		else
			args[k] = v
		end
	end
end

--Merge get arguments to post arguments.
for k,v in pairs(args_get) do
	if type(k) == "number" then
		arrIdx = nil
	else
		arrIdx = k:match("(.*)%[%]")
	end
	if arrIdx then
		args[arrIdx] = v
	else
		args[k] = v
	end
end

if not (module_name == "user" and method_name == "authorize" ) and (ngx.var.check_session == "true") then
	local check_session = modules.users.check_session
	local is_ok, err = check_session(args)
	if not is_ok then
		return
	end
end

local r,msg = method( red, args )
if not r then
	MSG.ERROR( msg or "UNKNOWN ERROR", { reason = "api:execute", module = module_name, method = method_name } )
	return
end

