#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

set -e
set -u

bsm_output="$(/sbin/hwclock --param-get=bsm)"
if printf '%s' "${bsm_output}" | grep -q "The RTC parameter 0x2 is set to 0x0."; then
	printf "Setting backup switchover mode parameter to 0x1\n"
	/sbin/hwclock --param-set=bsm=0x1
elif printf '%s' "${bsm_output}" | grep -q "The RTC parameter 0x2 is set to 0x1."; then
	printf "Backup switchover mode parameter already set correctly\n"
else
	printf "Unexpected backup switchover mode parameter\n"
	exit 1
fi
