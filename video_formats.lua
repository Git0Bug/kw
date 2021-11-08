local coaf = require "coaf.core"
local _dbg = require "coaf.debug"

local _M = {
}

local failsafe_format = {
	id = "1080p60", 
	name = "1920x1080p 60Hz", format_mode = "HD", vicCode = 16,
	xRes = 1920, yRes = 1080, frame_rate = 60, interlaced = false,
	clock_rate = 148.5, 
	hTotal = 2200,
	hActive = 1920,
	hSyncRising = 1920+88,
	hSyncFalling = 1920+88+44,
	vTotal = 1125,
	vActive = 1080,
	vSyncRising = 1080+4,
	vSyncFalling = 1080+4+5,
	vTotal2 = 0,
	vActive2 = 0,
	vSyncRising2 = 0,
	vSyncFalling2 = 0,
}

local standard_formats = {
	{
		id = "4k60",
		name = "4096x2160p 60Hz", format_mode = "UHD_420", vicCode = 97,
		xRes = 4096, yRes = 2160, frame_rate = 60, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 4096,
		hSyncRising = 4096+88,
		hSyncFalling = 4096+88+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},	
	{
		id = "4k60",
		name = "3840x2160p 60Hz", format_mode = "UHD_420", vicCode = 97,
		xRes = 3840, yRes = 2160, frame_rate = 60, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 3840,
		hSyncRising = 3840+176,
		hSyncFalling = 3840+176+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k59", alias_id = "4k60",
		name = "4096x2160p 59.94Hz", format_mode = "UHD_420", ntsc_mode = true, vicCode = 97,
		xRes = 4096, yRes = 2160, frame_rate = 60/1.001, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 4096,
		hSyncRising = 4096+88,
		hSyncFalling = 4096+88+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},		
	{
		id = "4k59", alias_id = "4k60",
		name = "3840x2160p 59.94Hz", format_mode = "UHD_420", ntsc_mode = true, vicCode = 97,
		xRes = 3840, yRes = 2160, frame_rate = 60/1.001, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 3840,
		hSyncRising = 3840+176,
		hSyncFalling = 3840+176+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k50",
		name = "4096x2160p 50Hz", format_mode = "UHD_420", vicCode = 96,
		xRes = 4096, yRes = 2160, frame_rate = 50, interlaced = false,
		clock_rate = 297, 
		hTotal = 5280,
		hActive = 4096,
		hSyncRising = 4096+968,
		hSyncFalling = 4096+968+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k50",
		name = "3840x2160p 50Hz", format_mode = "UHD_420", vicCode = 96,
		xRes = 3840, yRes = 2160, frame_rate = 50, interlaced = false,
		clock_rate = 297, 
		hTotal = 5280,
		hActive = 3840,
		hSyncRising = 3840+1056,
		hSyncFalling = 3840+1056+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k30",
		name = "4096x2160p 30Hz", format_mode = "UHD", vicCode = 95,
		xRes = 4096, yRes = 2160, frame_rate = 30, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 4096,
		hSyncRising = 4096+88,
		hSyncFalling = 4096+88+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},		
	{
		id = "4k30",
		name = "3840x2160p 30Hz", format_mode = "UHD", vicCode = 95,
		xRes = 3840, yRes = 2160, frame_rate = 30, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 3840,
		hSyncRising = 3840+176,
		hSyncFalling = 3840+176+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k29", alias_id = "4k30",
		name = "4096x2160p 29.97Hz", format_mode = "UHD", vicCode = 95,
		xRes = 4096, yRes = 2160, frame_rate = 30/1.001, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 4096,
		hSyncRising = 4096+88,
		hSyncFalling = 4096+88+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},	
	{
		id = "4k29", alias_id = "4k30",
		name = "3840x2160p 29.97Hz", format_mode = "UHD", vicCode = 95,
		xRes = 3840, yRes = 2160, frame_rate = 30/1.001, interlaced = false,
		clock_rate = 297, 
		hTotal = 4400,
		hActive = 3840,
		hSyncRising = 3840+176,
		hSyncFalling = 3840+176+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k25",
		name = "4096x2160p 25Hz", format_mode = "UHD", vicCode = 94,
		xRes = 4096, yRes = 2160, frame_rate = 25, interlaced = false,
		clock_rate = 297, 
		hTotal = 5280,
		hActive = 4096,
		hSyncRising = 4096+968,
		hSyncFalling = 4096+968+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},	
	{
		id = "4k25",
		name = "3840x2160p 25Hz", format_mode = "UHD", vicCode = 94,
		xRes = 3840, yRes = 2160, frame_rate = 25, interlaced = false,
		clock_rate = 297, 
		hTotal = 5280,
		hActive = 3840,
		hSyncRising = 3840+1056,
		hSyncFalling = 3840+1056+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k24",
		name = "4096x2160p 24Hz", format_mode = "UHD", vicCode = 93,
		xRes = 4096, yRes = 2160, frame_rate = 24, interlaced = false,
		clock_rate = 297, 
		hTotal = 5500,
		hActive = 4096,
		hSyncRising = 4096+1118,
		hSyncFalling = 4096+1118+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},	
	{
		id = "4k24",
		name = "3840x2160p 24Hz", format_mode = "UHD", vicCode = 93,
		xRes = 3840, yRes = 2160, frame_rate = 24, interlaced = false,
		clock_rate = 297, 
		hTotal = 5500,
		hActive = 3840,
		hSyncRising = 3840+1276,
		hSyncFalling = 3840+1276+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "4k23", alias_id = "4k24",
		name = "4096x2160p 23.98Hz", format_mode = "UHD", vicCode = 93,
		xRes = 4096, yRes = 2160, frame_rate = 24/1.001, interlaced = false,
		clock_rate = 297, 
		hTotal = 5500,
		hActive = 4096,
		hSyncRising = 4096+1118,
		hSyncFalling = 4096+1118+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},	
	{
		id = "4k23", alias_id = "4k24",
		name = "3840x2160p 23.98Hz", format_mode = "UHD", vicCode = 93,
		xRes = 3840, yRes = 2160, frame_rate = 24/1.001, interlaced = false,
		clock_rate = 297, 
		hTotal = 5500,
		hActive = 3840,
		hSyncRising = 3840+1276,
		hSyncFalling = 3840+1276+88,
		vTotal = 2250,
		vActive = 2160,
		vSyncRising = 2160+8,
		vSyncFalling = 2160+8+10,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p60",
		name = "1920x1080p 60Hz", format_mode = "HD", vicCode = 16,
		xRes = 1920, yRes = 1080, frame_rate = 60, interlaced = false,
		clock_rate = 148.5, 
		hTotal = 2200,
		hActive = 1920,
		hSyncRising = 1920+88,
		hSyncFalling = 1920+88+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p59", alias_id = "1080p60",
		name = "1920x1080p 59.94Hz", format_mode = "HD", ntsc_mode = true, vicCode = 16, 
		xRes = 1920, yRes = 1080, frame_rate = 60/1.001, interlaced = false,
		clock_rate = 148.5, 
		hTotal = 2200,
		hActive = 1920,
		hSyncRising = 1920+88,
		hSyncFalling = 1920+88+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p50",
		name = "1920x1080p 50Hz", format_mode = "HD", vicCode = 31,
		xRes = 1920, yRes = 1080, frame_rate = 50, interlaced = false,
		clock_rate = 148.5, 
		hTotal = 2640,
		hActive = 1920,
		hSyncRising = 1920+528,
		hSyncFalling = 1920+528+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p30",
		name = "1920x1080p 30Hz", format_mode = "HD", vicCode = 34,
		xRes = 1920, yRes = 1080, frame_rate = 30, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2200,
		hActive = 1920,
		hSyncRising = 1920+88,
		hSyncFalling = 1920+88+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p29", alias_id = "1080p30",
		name = "1920x1080p 29.97Hz", format_mode = "HD", ntsc_mode = true, vicCode = 34,
		xRes = 1920, yRes = 1080, frame_rate = 30/1.001, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2200,
		hActive = 1920,
		hSyncRising = 1920+88,
		hSyncFalling = 1920+88+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p25",
		name = "1920x1080p 25Hz", format_mode = "HD", vicCode = 33,
		xRes = 1920, yRes = 1080, frame_rate = 25, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2640,
		hActive = 1920,
		hSyncRising = 1920+528,
		hSyncFalling = 1920+528+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p24",
		name = "1920x1080p 24Hz", format_mode = "HD", vicCode = 32,
		xRes = 1920, yRes = 1080, frame_rate = 24, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2750,
		hActive = 1920,
		hSyncRising = 1920+638,
		hSyncFalling = 1920+638+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p23", alias_id = "1080p24",
		name = "1920x1080p 23.98Hz", format_mode = "HD", ntsc_mode = true, vicCode = 32,
		xRes = 1920, yRes = 1080, frame_rate = 24/1.001, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2750,
		hActive = 1920,
		hSyncRising = 1920+638,
		hSyncFalling = 1920+638+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},

	{
		id = "1080p60",
		name = "2048x1080p 60Hz", format_mode = "HD", vicCode = 16,
		xRes = 2048, yRes = 1080, frame_rate = 60, interlaced = false,
		clock_rate = 148.5, 
		hTotal = 2200,
		hActive = 2048,
		hSyncRising = 2048+44,
		hSyncFalling = 2048+44+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p59", alias_id = "1080p60",
		name = "2048x1080p 59.94Hz", format_mode = "HD", ntsc_mode = true, vicCode = 16, 
		xRes = 2048, yRes = 1080, frame_rate = 60/1.001, interlaced = false,
		clock_rate = 148.5, 
		hTotal = 2200,
		hActive = 2048,
		hSyncRising = 2048+44,
		hSyncFalling = 2048+44+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p50",
		name = "2048x1080p 50Hz", format_mode = "HD", vicCode = 31,
		xRes = 2048, yRes = 1080, frame_rate = 50, interlaced = false,
		clock_rate = 148.5, 
		hTotal = 2640,
		hActive = 2048,
		hSyncRising = 2048+484,
		hSyncFalling = 2048+484+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p30",
		name = "2048x1080p 30Hz", format_mode = "HD", vicCode = 34,
		xRes = 2048, yRes = 1080, frame_rate = 30, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2200,
		hActive = 2048,
		hSyncRising = 2048+44,
		hSyncFalling = 2048+44+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p29", alias_id = "1080p30",
		name = "2048x1080p 29.97Hz", format_mode = "HD", ntsc_mode = true, vicCode = 34,
		xRes = 2048, yRes = 1080, frame_rate = 30/1.001, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2200,
		hActive = 2048,
		hSyncRising = 2048+44,
		hSyncFalling = 2048+44+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p25",
		name = "2048x1080p 25Hz", format_mode = "HD", vicCode = 33,
		xRes = 2048, yRes = 1080, frame_rate = 25, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2640,
		hActive = 2048,
		hSyncRising = 2048+484,
		hSyncFalling = 2048+484+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p24",
		name = "2048x1080p 24Hz", format_mode = "HD", vicCode = 32,
		xRes = 2048, yRes = 1080, frame_rate = 24, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2750,
		hActive = 2048,
		hSyncRising = 2048+594,
		hSyncFalling = 2048+594+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "1080p23", alias_id = "1080p24",
		name = "2048x1080p 23.98Hz", format_mode = "HD", ntsc_mode = true, vicCode = 32,
		xRes = 2048, yRes = 1080, frame_rate = 24/1.001, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 2750,
		hActive = 2048,
		hSyncRising = 2048+594,
		hSyncFalling = 2048+594+44,
		vTotal = 1125,
		vActive = 1080,
		vSyncRising = 1080+4,
		vSyncFalling = 1080+4+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},

	{
		id = "1080i60",
		name = "1920x1080i 60Hz", format_mode = "HD", vicCode = 5,
		xRes = 1920, yRes = 1080, frame_rate = 60, interlaced = true,
		clock_rate = 74.25, 
		hTotal = 2200,
		hActive = 1920,
		hSyncRising = 1920+88,
		hSyncFalling = 1920+88+44,
		vTotal = 562,
		vActive = 540,
		vSyncRising = 540+2,
		vSyncFalling = 540+2+5,
		vTotal2 = 563,
		vActive2 = 540,
		vSyncRising2 = 540+2,
		vSyncFalling2 = 540+2+5,
	},
	{
		id = "1080i59", alias_id = "1080i60",
		name = "1920x1080i 59.94Hz", format_mode = "HD", ntsc_mode = true, vicCode = 5, 
		xRes = 1920, yRes = 1080, frame_rate = 60/1.001, interlaced = true,
		clock_rate = 74.25, 
		hTotal = 2200,
		hActive = 1920,
		hSyncRising = 1920+88,
		hSyncFalling = 1920+88+44,
		vTotal = 562,
		vActive = 540,
		vSyncRising = 540+2,
		vSyncFalling = 540+2+5,
		vTotal2 = 563,
		vActive2 = 540,
		vSyncRising2 = 540+2,
		vSyncFalling2 = 540+2+5,
	},
	{
		id = "1080i50",
		name = "1920x1080i 50Hz", format_mode = "HD", vicCode = 20,
		xRes = 1920, yRes = 1080, frame_rate = 50, interlaced = true,
		clock_rate = 74.25, 
		hTotal = 2640,
		hActive = 1920,
		hSyncRising = 1920+528,
		hSyncFalling = 1920+528+44,
		vTotal = 562,
		vActive = 540,
		vSyncRising = 540+2,
		vSyncFalling = 540+2+5,
		vTotal2 = 563,
		vActive2 = 540,
		vSyncRising2 = 540+2,
		vSyncFalling2 = 540+2+5,
	},
	{
		id = "720p60",
		name = "1280x720p 60Hz", format_mode = "HD", vicCode = 4,
		xRes = 1280, yRes = 720, frame_rate = 60, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 1650,
		hActive = 1280,
		hSyncRising = 1280+110,
		hSyncFalling = 1280+110+40,
		vTotal = 750,
		vActive = 720,
		vSyncRising = 720+5,
		vSyncFalling = 720+5+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "720p59", alias_id = "720p60",
		name = "1280x720p 59.94Hz", format_mode = "HD", ntsc_mode = true, vicCode = 4,
		xRes = 1280, yRes = 720, frame_rate = 60/1.001, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 1650,
		hActive = 1280,
		hSyncRising = 1280+110,
		hSyncFalling = 1280+110+40,
		vTotal = 750,
		vActive = 720,
		vSyncRising = 720+5,
		vSyncFalling = 720+5+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	{
		id = "720p50",
		name = "1280x720p 50Hz", format_mode = "HD", vicCode = 19,
		xRes = 1280, yRes = 720, frame_rate = 50, interlaced = false,
		clock_rate = 74.25, 
		hTotal = 1980,
		hActive = 1280,
		hSyncRising = 1280+440,
		hSyncFalling = 1280+440+40,
		vTotal = 750,
		vActive = 720,
		vSyncRising = 720+5,
		vSyncFalling = 720+5+5,
		vTotal2 = 0,
		vActive2 = 0,
		vSyncRising2 = 0,
		vSyncFalling2 = 0,
	},
	--TODO: Vertical resolutions.
}

local function format_match( filter_fmts, xRes, yRes, fr, interlaced )
	local best_match, half_match, ntsc_match, half_ntsc_match, xy_match
	local i
	for i=1, #filter_fmts do
		if (not xRes or filter_fmts[i].xRes == xRes) and (not yRes or filter_fmts[i].yRes == yRes) then
			if not xy_match then
				xy_match = i
			end
			if fr and fr > 0 then
				if math.abs(fr-filter_fmts[i].frame_rate) <= 0.01 then
					best_match = i
					break
				elseif not ntsc_match and math.abs(fr - filter_fmts[i].frame_rate) <= 0.1 then
					ntsc_match = i
				elseif fr <= 30 then
					if not half_match and math.abs(fr*2 - filter_fmts[i].frame_rate) <= 0.01 then
						half_match = i
					elseif not half_ntsc_match and math.abs(fr*2 - filter_fmts[i].frame_rate) <= 0.1 then
						half_ntsc_match = i
					end
				else
					if not half_match and math.abs(fr/2 - filter_fmts[i].frame_rate) <= 0.01 then
						half_match = i
					elseif not half_ntsc_match and math.abs(fr/2 - filter_fmts[i].frame_rate) <= 0.1 then
						half_ntsc_match = i
					end
				end
			else
				best_match = i
				break
			end
		end
	end

	if best_match then
		return "best", filter_fmts[best_match]
	elseif half_match then
		return "half", filter_fmts[half_match]
	elseif ntsc_match then
		return "ntsc", filter_fmts[ntsc_match]
	elseif half_ntsc_match then
		return "half-ntsc", filter_fmts[half_ntsc_match]
	elseif xy_match then
		return "xy", filter_fmts[xy_match]
	else
		return nil, nil
	end
end

function _M.GetFormatSetting( specModes, specFr, xRes, yRes, fr, interlaced )
	local filter_fmts = {}
	if type(specModes) == "string" then
		specModes = { specModes }
	elseif type(specModes) ~= "table" then
		specModes = { '*' }
	end

	local i,j
	for i=1, #standard_formats do
		if ((interlaced and standard_formats[i].interlaced) or (not interlaced and not standard_formats[i].interlaced)) then
			for j=1, #specModes do
				if specModes[j] == '*' or standard_formats[i].format_mode == specModes[j] then
					if not specFr or specFr <= 0 or math.abs(specFr-standard_formats[i].frame_rate) <= 0.01 then
						table.insert( filter_fmts, standard_formats[i] )
						break
					end
				end
			end
		end
	end

	local m, fmt = format_match( filter_fmts, xRes, yRes, fr, interlaced )
	if fmt then
		return m, fmt
	else
		return nil, nil
	end

--[[ Now, don't consider support surround cases.
	local surround_fmts = {}
	-- Find the best surround format. (reverse order)
	for i=#filter_fmts,1,-1 do
		fmt = filter_fmts[i]
		if fmt.hTotal >= xRes + (fmt.hSyncFalling - fmt.hActive) + 8 then
			if interlaced then
				if fmt.vTotal >= yRes/2 + (fmt.vSyncFalling - fmt.vActive) + 2 and
				   fmt.vTotal2 >= yRes/2 + (fmt.vSyncFalling2 - fmt.vActive2) + 2 then
					table.insert( surround_fmts, fmt )
				end
			else
				if fmt.vTotal >= yRes + (fmt.vSyncFalling - fmt.vActive) + 2 then
					table.insert( surround_fmts, fmt )
				end
			end
		end
	end

	m, fmt = format_match( surround_fmts, nil, nil, fr, interlaced )
	if fmt then
		--NOTE: Must copy it.
		local rslt = {}
		local k,v
		for k,v in pairs(fmt) do
			rslt[k] = v
		end

		rslt.xRes = xRes
		rslt.yRes = yRes
		rslt.vicCode = 0
		rslt.name = xRes .. "x" .. yRes .. (interlaced and "i" or "p") .. " " .. math.floor(fmt.frame_rate * 100)/100 .. "Hz"
		rslt.hActive = xRes
		rslt.hSyncRising = xRes + (fmt.hSyncRising - fmt.hActive)
		rslt.hSyncFalling = xRes + (fmt.hSyncFalling - fmt.hActive)
		if interlaced then
			rslt.vActive = yRes/2
			rslt.vSyncRising = yRes/2 + (fmt.vSyncRising - fmt.vActive )
			rslt.vSyncFalling = yRes/2 + (fmt.vSyncFalling - fmt.vActive )
			rslt.vActive2 = yRes/2
			rslt.vSyncRising2 = yRes/2 + (fmt.vSyncRising2 - fmt.vActive2 )
			rslt.vSyncFalling2 = yRes/2 + (fmt.vSyncFalling2 - fmt.vActive2 )
		else
			rslt.vActive = yRes
			rslt.vSyncRising = yRes + (fmt.vSyncRising - fmt.vActive )
			rslt.vSyncFalling = yRes + (fmt.vSyncFalling - fmt.vActive )
		end
		return "surround", rslt
	else
		return nil, nil
	end
--]]

end

function _M.GetFailSafeFormat()
	return failsafe_format
end

function _M.GetFormatByID(id)
	for i=1, #standard_formats do
		if standard_formats[i].id == id then
			return standard_formats[i]
		end
	end
	return nil
end

return _M

