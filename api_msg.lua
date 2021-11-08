local cjson = require "cjson"
local _M = {
}

local function QuoteString(s)
	local x,n = string.gsub( s, '(%")', '\\%1' )
	if x then
		return x
	else
		return s
	end
end

local function sayFields(preCount, fields)
	local k,v
	for k,v in pairs(fields) do
		if preCount > 0 then
			ngx.say( ",")
		end
		if type(k) == "string" then
			ngx.say( '"', QuoteString(k), '":' )
		end

		if type(v) == "string" then
			ngx.say( '"', QuoteString(v), '"' )
		elseif type(v) == "boolean" then
			ngx.say( v and 'true' or 'false' )
		elseif type(v) == "table" then
			ngx.say( cjson.encode(v) )
--[[
			if #v > 0 then
				ngx.say( '[' )
				sayFields( 0, v )
				ngx.say( ']' )
			else
				ngx.say( '{' )
				sayFields( 0, v )
				ngx.say( '}' )
			end
]]
		else
			ngx.say(v)
		end
		preCount = preCount + 1
	end
end


function _M.OK(msg,fields)
	ngx.say( '{"result":"ok"' )
	if msg and msg ~= "" then
		ngx.say( ',"msg":"', QuoteString(msg), '"' )
	end

	if type(fields) == "table" then
		sayFields( 1, fields )
	end
	ngx.say( '}' )
end

function _M.ERROR(msg,fields)
	ngx.say( '{"result":"error"' )
	if msg then
		ngx.say( ',"msg":"', QuoteString(msg), '"' )
	else
		ngx.say( ',"msg":"Unknown error"' )
	end

	if type(fields) == "table" then
		sayFields( 1, fields )
	end
	ngx.say( '}' )
end

function _M.OK_FILE( msg, file )
	ngx.say( '{"result":"ok"' )
	if msg and msg ~= "" then
		ngx.say( ',"msg":"', QuoteString(msg), '"' )
	end

	local f = io.open( file, "r" )
	if f then
		local lines = f:read("*a")
		f:close()
		if lines then
			ngx.say(',"data":', lines, " " )
		end
	end

	ngx.say( '}' )
end

function _M.ERROR_FILE( msg, fields )
	ngx.say( '{"result":"error"' )
	if msg then
		ngx.say( ',"msg":"', QuoteString(msg), '"' )
	else
		ngx.say( ',"msg":"Unknown error"' )
	end

	local f = io.open( file, "r" )
	if f then
		local lines = f:read("*a")
		f:close()
		if lines then
			ngx.say(',"data":', lines, " " )
		end
	end

	ngx.say( '}' )
end

return _M

