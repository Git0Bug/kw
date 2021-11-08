local coaf=require "coaf.core"
local _dbg = require "coaf.debug"
local thread = require "coaf.thread"
local posix_time = require "posix.time"
--local avahi = require "coserver.discovery_tools.avahi"

--avahi.REFRESH_PERIOD = 60

require "ndi_discovery"

local _M = {
	work_discovery = {
	},
	--NOTE: Since it wastes too many time for large amount of sources, now disabled the group discovery functions.
	found_groups = {["public"] = true, [1] = "public"},
	last_refresh_time = nil
}

local function disc_callback( service_type, action, service_item )
	if action == "cleanup" then
		--TODO: Should me clear all groups?
		return
	elseif not service_item or not service_item.name or not service_item.protocol or not service_item.interface then
		_dbg.Error( "DISCOVERY", "Invalid service content for event:", action, "[", service_type, "]" )
		return
	end

	if action == "new" or action == "update" or action == "resolve" then
		if not service_item.resolve_info then -- or service_item.resolve_info.untrust then
			return
		end

		local txts = service_item.resolve_info.txt
		local fnd_group
		if txts then
			local i, v
			local key,val
			for i,v in ipairs(txts) do
				key,val = v:match("(.-)=(.*)$")
				if key == "groups" then
					fnd_group = val
					break
				end
			end
		end

		if not fnd_group then
			return
		end

		if not _M.found_groups[ fnd_group ] then
			_M.found_groups[ fnd_group ] = true
			table.insert( _M.found_groups, fnd_group )
		end
	elseif action == "remove" then --or action == "resolve-failed" then
		--TODO:
	end
end

function _M.Init()
	--avahi.Init() 
	_M.work_discovery["public"] = NDI.DISCOVERY.createNew()
	--avahi.SetDiscoveryCallback( disc_callback )
	--avahi.StartDiscovery("_ndi._tcp")
end

function _M.Step()
end

function _M.Reset()
	local k,v
	for k,v in pairs(_M.work_discovery) do
		v:reset()
	end
end

function _M.ForceRefresh()
	local now = posix_time.clock_gettime( posix_time.CLOCK_MONOTONIC )
	if not _M.last_refresh_time then
		_M.last_refresh_time = now
		_M.Reset()
	else
		local delta = (now.tv_sec - _M.last_refresh_time.tv_sec)*1000
		delta = delta + (now.tv_nsec - _M.last_refresh_time.tv_nsec)/1000000
		if delta >= 3000 then
			_M.last_refresh_time = now
			_M.Reset()
		end
	end
end

function _M.SetWorkGroups( groups )
	if type(groups) ~= "table" then
		groups = { groups }
	end
	local new = {}
	local drop = {}
	local k,v,i,fnd
	local fnd
	for k,v in ipairs(groups) do
		--and v ~= "*" and v ~= "*manual*" 
		if v ~= "" and not _M.work_discovery[v] then
			table.insert( new, v )
		end
	end
	for k,v in pairs(_M.work_discovery) do
		if k ~= "public" then
			fnd = false
			for i=1, #groups do
				if groups[i] == k then
					fnd = true
					break
				end
			end
			if not fnd then
				table.insert(drop,k)
			end
		end
	end

	if #drop == 0 and #new == 0 then
		return
	end

	for i=1, #drop do
		_M.work_discovery[ drop[i] ] = nil
	end
	collectgarbage()
	for i=1, #new do
		_M.work_discovery[ new[i] ] = NDI.DISCOVERY.createNew()
		_M.work_discovery[ new[i] ]:set_group( new[i] )
	end
end

function _M.SetWorkManuals( manuals )
	local list = {}
	if type(manuals) == "table" then
		local k,v
		for k,v in ipairs(manuals) do
			table.insert(list, v)
		end
	elseif type(manuals) == "string" then
		table.insert(list, manuals)
	end

	local k, disc
	for k, disc in pairs(_M.work_discovery) do
		disc:set_manual_iplist(list)
	end
end

function _M.SetDiscoveryServer( server )
	local list = {}
	local k, disc
	for k, disc in pairs(_M.work_discovery) do
		disc:set_discovery_server(server or "")
	end
end

local function match_spec_ip( r, spec, ipSpec )
	local k,v,i
	if type(ipSpec) == "string" then
		for k,v in pairs(r) do
			if v.ip == ipSpec then
				return v
			end
		end
	elseif type(ipSpec) == "table" then
		for k,v in pairs(r) do
			for i=1, #ipSpec do
				if v.ip == ipSpec[i] then
					return v
				end
			end
		end
	end
	return r[spec], "ip-nomatched"
end

function _M.GetWorkSources(spec,group,ipSpec)
	local r
	if group == "" or group == "*" or group == "*manual*" then
		group = nil
	end

	if not ipSpec and type(spec) == "string" then --Get one
		local k, disc, ri
		for k, disc in pairs(_M.work_discovery) do
			if not group or k == group then
				ri = disc:get(spec)
				if ri then
					r = ri
					break
				end
			end
		end
	else --Get list
		local k, disc, ri
		for k, disc in pairs(_M.work_discovery) do
			if not group or k == group then
				if ipSpec then
					ri = disc:get()
				else
					ri = disc:get(spec)
				end
				if ri then
					if not r then
						r = {}
					end
					local x,v
					for x,v in pairs(ri) do
						r[x] = v
					end
				end
			end
		end
	end

	if type(r) == "table" then
		if r.name and r.original_url then
			local ip, port = r.original_url:match("(%d+%.%d+%.%d+%.%d+):?(%d*)")
			if ip then
				port = tonumber(port) or 5960
			else
				ip = ""
				port = 0
			end
			r.ip = ip
			r.port = port
		else
			local k,v
			local ip, port
			for k,v in pairs(r) do
				ip, port = v.original_url:match("(%d+%.%d+%.%d+%.%d+):?(%d*)")
				if ip then
					port = tonumber(port) or 5960
				else
					ip = ""
					port = 0
				end
				v.ip = ip
				v.port = port
			end
		end
	end

	if not r then
		return nil
	end

	if ipSpec then
		if type(spec) == "string" then
			return match_spec_ip( r, spec, ipSpec )
		elseif type(spec) == "table" then
			local x, item, flag
			local filt_r
			for x=1, #spec do
				item, flag = match_spec_ip( r, spec[x], ipSpec )
				if item then
					if not filt_r then
						filt_r = {}
					end
					filt_r[ spec[x] ] = item
				end
			end
			return filt_r
		else
			if type(ipSpec) == "string" then
				return match_spec_ip( r, "*must-no-exist*", ipSpec )
			elseif type(ipSpec) == "table" then
				local x, filt_r, item
				for x=1, #ipSpec do
					item = match_spec_ip( r, "*must-no-exist*", ipSpec[x] )
					if item then
						if not filt_r then
							filt_r = {}
						end
						filt_r[ipSpec[x]] = item
					end
				end
				return filt_r
			else
				return nil
			end
		end
	end

	return r
end

--[[
function _M.UpdateManuals(manuals)
	local list = {}
	if type(manuals) == "table" then
		local k,v
		for k,v in ipairs(manuals) do
			table.insert(list, v)
		end
	elseif type(manuals) == "string" then
		table.insert(list, manuals)
	end
	_M.ui_discovery:set_manual_iplist(list)
end

function _M.SetGroup(group)
	if type(group) == "string" then
		_M.ui_discovery:set_group(group)
	else
		_M.ui_discovery:set_group("public")
	end
end
--]]

function _M.GetNDISources(spec)
	local total_rslt = {}
	for group, disc in pairs(_M.work_discovery) do
		local r = disc:get(spec)
		if type(r) == "table" then
			if r.name and r.original_url then
				local ip, port = r.original_url:match("(%d+%.%d+%.%d+%.%d+):?(%d*)")
				if ip then
					port = tonumber(port) or 5960
				else
					ip = ""
					port = 0
				end
				r.ip = ip
				r.port = port
				return r --Only one.
			else
				--local k,v
				local ip, port
				for k,v in pairs(r) do
					ip, port = v.original_url:match("(%d+%.%d+%.%d+%.%d+):?(%d*)")
					if ip then
						port = tonumber(port) or 5960
					else
						ip = ""
						port = 0
					end
					v.ip = ip
					v.port = port
					total_rslt[k] = v
				end
			end
		end
	end
	return total_rslt
end

function _M.GetNDIGroups()
	return _M.found_groups
end

return _M

