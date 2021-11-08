local MSG = require "api_msg"
local CO = require "api_coservice"
local cjson = require "cjson"
local __flg, FEATURES = pcall( require, "features" )
if not __flg or type(FEATURES) ~= "table" then
	FEATURES = {
	}
end


local dset = {mode="encoder"}

local function API_nav(red, args)
	local nav =
	{
		main_nav= {
			{
				href= "/encoder",
				en_text= "Encoder",
				zh_text= "编码",
				ko_text= "코딩",
				th_text= "การเข้ารหัส",
				mode = "encoder",
			},{
				href= "/decoder",
				en_text= "Decoder",
				zh_text= "解码",
				ko_text= "디코딩",
				th_text= "ถอดรหัส",
				mode = "decoder",
			}, {
				href= "/networksetup",
				en_text= "Network",
				zh_text= "网络",
				th_text= "เครือข่าย",
				ko_text="인터넷",
			}, {
				href= "discoveryServer",
				en_text = "Discovery Server",
				zh_text = "发现服务器",
				th_text = "เซิร์ฟเวอร์การค้นพบ",
				ko_text = "디스커버리 서버",
			}
			},
			sys_nav= {{
				href= "/users",
				en_text= "Manage Users",
				zh_text= "用户管理",
				th_text= "การจัดการผู้ใช้",
				ko_text= "사용자 관리",
			},
			{
				href = "system-time",
				en_text = "System Time",
				zh_text = "系统时间",
				th_text = "เวลาของระบบ",
				ko_text = "시스템 시간",
			},
			{
				href= "reset",
				en_text= "Reconnect",
				zh_text= "快速重连",
				ko_text= "빠른 재 연결",
				th_text = "เชื่อมต่อใหม่อย่างรวดเร็ว",
			}, {
				href= "reboot",
				en_text= "Reboot",
				zh_text= "设备重启",
				ko_text= "장치 다시 시작",
				th_text = "รีสตาร์ทอุปกรณ์",
			}, {
				href= "restore",
				en_text= "Reset Factory Settings",
				zh_text= "恢复出厂设置",
				ko_text= "초기화",
				th_text= "รีเซ็ต",
			}, {
				href= "/firmwareudp",
				en_text= "Firmware Update",
				zh_text= "固件升级",
				ko_text= "펌웨어 업그레이드",
				th_text= "อัพเกรดเฟิร์มแวร์",
			}}
		}

		--No decoding, so remove the decoder item.
		if FEATURES.FEATURE_NO_DECODING then
			table.remove( nav.main_nav, 2 )
		end
		if FEATURES.ENABLE_INTERCOM then
			local intercom = {
				href="voiceIntercom",
				en_text= "Voice Intercom",
				zh_text= "语音对讲",
				th_text = "Voice Intercom",
				ko_text="Voice Intercom",
			}
			table.insert( nav.main_nav,intercom)
		end

		MSG.OK( "", { data =nav  } )
		return true
	end


	local function API_components(red, args)
		local data=
		{{
			name= "vue",
			url= "MIT",
			software= "MIT License",
			address= "https://github.com/vuejs/vue"
		}, {
			name= "Element-UI",
			url= "MIT",
			software= "MIT License",
			address= "https://github.com/ElemeFE/element"
		}, {
			name= "OpenResty",
			url= "BSD",
			software= "BSD license",
			address= "https://github.com/openresty/openresty.org"
		}, {
			name= "luajit",
			url= "MIT",
			software= "MIT license",
			address= "http://luajit.org"
		}, {
			name= "lua",
			url= "MIT",
			software= "MIT license",
			address= "http://www.lua.org"
		}, {
			name= "nginx",
			url= "BSD2C",
			software= "BSD-2c",
			address= "http://nginx.org"
		}, {
			name= "libev",
			url= "BSD2C",
			url2= "GPL",
			software= "BSD-2c",
			software2= "GPLv2+",
			address= "http://dist.schmorp.de/libev"

		}, {
			name= "openssl",
			url= "OpenSSL",
			url2= "SSLeay",
			software= "OpenSSL",
			software2= "SSLeay",
			address= "http://www.openssl.org"
		}}

		MSG.OK( "", { data =data  } )
		return true
	end


	local function API_mode(red, args)
		local modedata =
		{mode=dset.mode}

		MSG.OK( "", { data =modedata  } )
		return true
	end


	local function API_modifyMode(red, args)
		if not args.mode then
			MSG.ERROR("invalidArgError")
			return true
		end
		dset.mode = args.mode

		MSG.OK( "" )
		return true
	end



	--------------

	dset.APIS = dset.APIS or {}

	dset.APIS["nav"] = API_nav
	dset.APIS["components"] = API_components
	dset.APIS["mode"] = API_mode
	dset.APIS["modifyMode"] = API_modifyMode

	return dset



