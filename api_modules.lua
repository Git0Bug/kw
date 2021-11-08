local modules = {}

modules["users"] = require "api_users"
modules["user"] = require "api_users"
modules["network"] = require "api_network"
modules["sys-time"] = require "api_systime"
modules["sys"] = require "api_sys"
modules["firmware"] = require "api_firmware"
modules["audio"] = require "api_audio"
modules["device"] = require "api_device"
modules["info"] = require "api_info"
modules["ptz"] = require "api_ptz"
modules["mode"] = require "api_mode"
modules["tally"] = require "api_tally"
modules["decoderMode/scan"] = require "api_dec_scan"
modules["decoderMode/preset"] = require "api_dec_preset"
modules["decoderMode/blank"] = require "api_dec_blank"
modules["decoderMode/current"] = require "api_dec_current"
modules["decoderMode/output"] = require "api_dec_output"
modules["decoderMode/ptz"] = require "api_dec_ptz"
modules["encoderMode/ptz"] = require "api_enc_ptz"
modules["decoderMode/switch"] = require "api_dec_switch"
modules["encoder/ndi"] = require "api_device"
modules["decoder/discovery"] = require "api_dec_scan"
modules["decoder/preset"] = require "api_dec_preset"
modules["decoder/current"] = require "api_dec_current"
modules["decoder/output"] = require "api_dec_output"

return modules

