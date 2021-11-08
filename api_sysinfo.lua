local _M = {}

_M.cpu_saved = {
	u = 0,
	n = 0,
	s = 0,
	i = 0,
	w = 0,
	x = 0,
	y = 0
}

function _M.GetCpuCores()
	local file = io.open( "/proc/stat", "r" )
	if not file then
		return 1
	end

	local line = file:read("l")
	local count = 0
	while true do
		line = file:read("l")
		if not line then
			break
		end
		if line:match("^cpu[0-9]+") then
			count = count + 1
		else
			break
		end
	end
	file:close()
	return count
end

function _M.GetCpuLoad()
	local file = io.open( "/proc/stat", "r" )
	if not file then
		return 0, 99	--load: 0, idle: 99
	end

	local line = file:read("l")
	file:close()

	local cpu,u,n,s,i,w,x,y = line:match( "(.-)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)" )
	u = u and tonumber(u) or 0
	n = n and tonumber(n) or 0
	s = s and tonumber(s) or 0
	i = i and tonumber(i) or 0
	w = w and tonumber(w) or 0
	x = x and tonumber(x) or 0
	y = y and tonumber(y) or 0

	local du = u - _M.cpu_saved.u
	local dn = n - _M.cpu_saved.n
	local ds = s - _M.cpu_saved.s
	local di = i - _M.cpu_saved.i
	local dw = w - _M.cpu_saved.w
	local dx = x - _M.cpu_saved.x
	local dy = y - _M.cpu_saved.y

	_M.cpu_saved.u = u
	_M.cpu_saved.n = n
	_M.cpu_saved.s = s
	_M.cpu_saved.i = i
	_M.cpu_saved.w = w
	_M.cpu_saved.x = x
	_M.cpu_saved.y = y

	local total = du + dn + ds + di + dw + dx + dy
	if total < 1 then
		total = 1
	end

	local scale = 100/total
	local idle = di*scale
	return 100-idle, idle
end


function _M.GetMemUse()
	local file = io.open( "/proc/meminfo", "r" )
	if not file then
		return nil, nil
	end

	local free = nil
	local total = nil
	local v
	local line = file:read("l")
	while line and ( not free or not total ) do
		v = line:match( "MemTotal:%s+(%d+)" )
		if v then
			total = tonumber(v)
		else
			v = line:match( "MemFree:%s+(%d+)" )
			if v then
				free = tonumber(v)
			end
		end
		line = file:read("l")
	end

	file:close()
	return free, total
end

function _M.GetDiskSpaces()
	local result = {
		sys = { total=0, used=0, free=0, percent=100 },
		data = { total=0, used=0, free=0, percent=100 }
	}

	local file=io.popen("/bin/df -m","r")
	if not file then
		return result
	end

	local line = file:read("l")
	while line and (result.sys.total <= 0 or result.data.total <=0 ) do
		local flag,t,u,f,p = line:match( "(.-)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%%%s+/$" )
		if flag then
			result.sys.total = tonumber(t)
			result.sys.used = tonumber(u)
			result.sys.free = tonumber(f)
			result.sys.percent = tonumber(p)
		else
			flag,t,u,f,p = line:match( "(.-)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%%%s+/data$" )
			if flag then
				result.data.total = tonumber(t)
				result.data.used = tonumber(u)
				result.data.free = tonumber(f)
				result.data.percent = tonumber(p)
			end
		end

		line=file:read("l")
	end

	file:close()
	return result
end

function _M.GetPersisTime()
	local file=io.open("/proc/uptime", "r")
	if not file then
		return 0, {year=1970,month=1,day=1,hour=8,min=0,sec=0}
	end

	local line = file:read("l")
	file:close()
	local pers = line:match("(%d+)")
	if not pers then
		return 0, {year=1970,month=1,day=1,hour=8,min=0,sec=0}
	else
		return tonumber(pers), os.date("*t",os.time() - tonumber(pers))
	end
end


return _M

