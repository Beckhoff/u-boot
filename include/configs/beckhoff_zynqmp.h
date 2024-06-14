/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright (C) Beckhoff Automation GmbH & Co. KG
 */

#define BECKHOFF_ZYNQMP_LOAD_FPGA \
	"try_fpga_load=" \
		"fpga_path=${fpga_prefix}${fpga_file}.gz;" \
		"echo \"looking for fpga bitstream ${fpga_path}\";" \
		"if test ! -e mmc 0:1 ${fpga_path}; then;" \
			"echo \"fpga bitstream ${fpga_path} not found\";" \
			"fpga_loaded=0;" \
			"exit;" \
		"fi;" \
		"load mmc 0 ${loadaddr} ${fpga_path};" \
		"if test $? -ne 0; then;" \
			"echo \"loading bitstream ${fpga_path} to ${loadaddr} failed\";" \
			"fpga_loaded=0;" \
			"exit;" \
		"fi;" \
		"setexpr loadaddr_unzipped ${loadaddr} + ${filesize};" \
		"unzip ${loadaddr} ${loadaddr_unzipped};" \
		"if test $? -ne 0; then;" \
			"echo \"unzip bitstream ${fpga_path} failed\";" \
			"fpga_loaded=0;" \
			"exit;" \
		"fi;" \
		"fpga load 0 ${loadaddr_unzipped} ${file} ${filesize};" \
		"if test $? -ne 0; then;" \
			"fpga_loaded=0;" \
			"exit;" \
		"fi;" \
		"echo \"loaded bitstream from ${fpga_path} successfully\";" \
		"fdt addr ${fdtcontroladdr};" \
		"fdt set /chosen ccat0-firmware-loaded ${fpga_path};" \
		"fpga_loaded=1;" \
		"exit;" \
	"\0" \
	"load_fpga_bitstream=" \
	"mtd read beckhoff_factory_data ${loadaddr} 0xc4 0x20;" \
	"setexpr termination_addr ${loadaddr} + 0x20;" \
	"mw.b ${termination_addr} 0x00;" \
	"setexpr.s mtd_fpga_file *${loadaddr};" \
	"fpga_prefix=\"beckhoff/fpga/\";" \
	"fpga_file=${mtd_fpga_file};" \
	"fpga_loaded=0;" \
	"run try_fpga_load;" \
	"if test ${fpga_loaded} -ne 1; then;" \
		"fpga_file=${fpga_fallback_file};" \
		"run try_fpga_load;" \
	"fi;" \
	"\0" \
	"eth_phy_configure_leds=" \
		"mdio write ${eth_addr} 0x1c 0x8807;" \
		"mdio write ${eth_addr} 0x1c 0xb8ea;" \
		"echo \"${eth_addr}: LEDs configured\";" \
		"exit;" \
	"\0" \
	"eth_phy_eee_advertisement_disable=" \
		"mdio write ${eth_addr} 0x0D 0x0007;" \
		"mdio write ${eth_addr} 0x0E 0x003C;" \
		"mdio write ${eth_addr} 0x0D 0x4007;" \
		"mdio write ${eth_addr} 0x0E 0x0000;" \
		"mdio write ${eth_addr} 0x0D 0x0007;" \
		"mdio write ${eth_addr} 0x0E 0x803D;" \
		"mdio write ${eth_addr} 0x0D 0x4007;" \
		"mdio write ${eth_addr} 0x0E 0x4000;" \
		"echo \"${eth_addr}: EEE Advertisement disabled\";" \
		"exit;" \
	"\0"
