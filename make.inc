##
## Makefile of %%this_module%%
##
## History:
##    2016/04/08 - [Jacob Zuo] Created file
##
## Copyright (C) 2016-2017, Kiloview, Inc.
##
## All rights reserved. No Part of this file may be reproduced, stored
## in a retrieval system, or transmitted, in any form, or by any means,
## electronic, mechanical, photocopying, recording, or otherwise,
## without the prior consent of Kiloview, Inc.
##

LOCAL_PATH	:= $(call my-dir)

### luaLibs
include $(CLEAR_VARS)

.PHONY: general_codec_service spark_codec_service n20_codec_service n20plus_codec_service n20pro_codec_service u40_codec_service n10_codec_service n10_pro_codec_service

general_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
spark_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
n20_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
spark_8chn_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
n20plus_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
n20pro_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
u40_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
n10_codec_service: PRIV_LOCAL := $(LOCAL_PATH)
n10_pro_codec_service: PRIV_LOCAL := $(LOCAL_PATH)

general_codec_service: APP_TARGET_LOCATION := $(subst /,\\/,/usr/local/bin/codec)

general_codec_service:
	@mkdir -p $(FAKEROOT_DIR)/usr/local/bin/codec
	@rm -Rf $(FAKEROOT_DIR)/usr/local/bin/codec/hdmi_chips.lua || true #Remove old files.
	@rm -Rf $(FAKEROOT_DIR)/usr/local/bin/codec/iocfg.lua || true #Remove old files.
	@cp -Rf $(PRIV_LOCAL)/chips $(FAKEROOT_DIR)/usr/local/bin/codec
	@cp -Rf $(PRIV_LOCAL)/chips_io/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/*.lua $(FAKEROOT_DIR)/usr/local/bin/codec
	@cp -Rf $(PRIV_LOCAL)/keyboard $(FAKEROOT_DIR)/usr/local/bin/codec/
	@cp -Rf $(PRIV_LOCAL)/PtzManager $(FAKEROOT_DIR)/usr/local/bin/codec/
	@chmod +x $(FAKEROOT_DIR)/usr/local/bin/codec/codec.lua
	@cp -Rf $(PRIV_LOCAL)/etc/* $(FAKEROOT_DIR)/etc/
	@sed -i "s/%APP_LOC%/$(APP_TARGET_LOCATION)/g" $(FAKEROOT_DIR)/etc/coserver/local/codec
	@echo "Install $@ DONE."

spark_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_spark/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/ || true
	@cp -Rf $(PRIV_LOCAL)/avio_spark/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

n20_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/ite66021.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/sii9136.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_n20/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

spark_8chn_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_spark_8chn/ite66021.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/sii9136.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_spark_8chn/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

n20plus_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/ite68051.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/sii9136.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_n20_plus/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

n20pro_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/ite68051.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_n20_pro/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

u40_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_hdmi/ite68051.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_u40/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

n10_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_sdi_SD/fpga_rx.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_sdi_SD/fpga_tx.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_sdi_SD/video_formats.lua $(FAKEROOT_DIR)/usr/local/bin/codec/
	@cp -Rf $(PRIV_LOCAL)/avio_n10/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

n10_pro_codec_service: general_codec_service
	@cp -Rf $(PRIV_LOCAL)/chips_audio/aic3104.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_sdi/fpga_rx.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/chips_sdi/fpga_tx.lua $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@cp -Rf $(PRIV_LOCAL)/avio_n10_pro/* $(FAKEROOT_DIR)/usr/local/bin/codec/chips/
	@echo "Install $@ DONE."

ndi_codec_error_prompt:
	@echo "ERROR: You must specify a valid 'PRODUCT_SERIES' in your product declare.env, current PRODUCT_SERIES=$(PRODUCT_SERIES) is not supported!"
	@false

ifeq ($(PRODUCT_SERIES),GO)
$(call add-target-into-kiloview-modules, n20_codec_service)
else ifeq ($(KILOVIEW_PRODUCT_ID),SparkIO)
$(call add-target-into-kiloview-modules, n20_codec_service)
else ifeq ($(KILOVIEW_PRODUCT_ID),SparkIO_hdmi8chn)
$(call add-target-into-kiloview-modules, spark_8chn_codec_service)
else ifeq ($(KILOVIEW_PRODUCT_ID),SparkIO_3gsdi)
$(call add-target-into-kiloview-modules, n10_codec_service)
else ifeq ($(KILOVIEW_PRODUCT_ID),SparkIO_3gsdi_12s)
$(call add-target-into-kiloview-modules, n10_codec_service)
else ifeq ($(KILOVIEW_PRODUCT_ID),SparkIO_hdmi20)
$(call add-target-into-kiloview-modules, n20plus_codec_service)
else ifeq ($(KILOVIEW_PRODUCT_ID),SparkIO_12gsdi)
$(call add-target-into-kiloview-modules, n10_pro_codec_service)
else ifeq ($(PRODUCT_SERIES),GO_PLUS)
$(call add-target-into-kiloview-modules, n20plus_codec_service)
else ifeq ($(PRODUCT_SERIES),GO_PRO)
$(call add-target-into-kiloview-modules, n20pro_codec_service)
else ifeq ($(PRODUCT_SERIES),GO_U)
$(call add-target-into-kiloview-modules, u40_codec_service)
else ifeq ($(PRODUCT_SERIES),GO_SDI)
$(call add-target-into-kiloview-modules, n10_codec_service)
else ifeq ($(PRODUCT_SERIES),GO_SDI_PRO)
$(call add-target-into-kiloview-modules, n10_pro_codec_service)
else ifeq ($(PRODUCT_SERIES),NDI)
$(call add-target-into-kiloview-modules, spark_codec_service)
else
$(call add-target-into-kiloview-modules, ndi_codec_error_prompt)
endif


