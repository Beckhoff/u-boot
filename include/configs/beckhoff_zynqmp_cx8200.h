/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * Copyright (C) Beckhoff Automation GmbH & Co. KG
 */

#ifndef __CONFIG_BECKHOFF_CX8200_H
#define __CONFIG_BECKHOFF_CX8200_H

#include <configs/xilinx_zynqmp.h>

#undef CFG_EXTRA_ENV_SETTINGS
#define CFG_EXTRA_ENV_SETTINGS \
	ENV_MEM_LAYOUT_SETTINGS \
	BOOTENV \
	"fdt_addr_r=0x28000000\0" \

#endif /* __CONFIG_BECKHOFF_CX8200_H */
