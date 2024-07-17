/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright (C) Beckhoff Automation GmbH & Co. KG
 */

#ifndef __CONFIG_BECKHOFF_CX8200_H
#define __CONFIG_BECKHOFF_CX8200_H

#include <configs/xilinx_zynqmp.h>
#include <configs/beckhoff_zynqmp.h>

#undef CFG_EXTRA_ENV_SETTINGS
#define CFG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS \
	BOOTENV \
	BECKHOFF_ZYNQMP_LOAD_FPGA \
	"fdt_addr_r=0x28000000\0" \
	"fpga_fallback_file=CX8200-B000-2.bin\0" \
	"preboot=" \
	"env set eth_addr ethernet@ff0d0000;" \
	"run eth_phy_eee_advertisement_disable;" \
	"run load_fpga_bitstream;" \
	"mw.b 0xa0000300 3;" \
	"\0"

#endif /* __CONFIG_BECKHOFF_CX8200_H */
