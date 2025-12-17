/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright (C) Beckhoff Automation GmbH & Co. KG
 */

#ifndef __CONFIG_BECKHOFF_CX9240_H
#define __CONFIG_BECKHOFF_CX9240_H

#include <configs/xilinx_zynqmp.h>
#include <configs/beckhoff_zynqmp.h>

#undef CFG_EXTRA_ENV_SETTINGS
#define CFG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS \
	BOOTENV \
	BECKHOFF_ZYNQMP_LOAD_FPGA \
	"fdt_addr_r=0x28000000\0" \
	"fpga_fallback_file=CX9240-B000-3.bin\0" \
	"preboot=" \
	"run load_fpga_bitstream;" \
	"\0"

#endif /* __CONFIG_BECKHOFF_CX9240_H */
