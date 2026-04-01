#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

usage() {
	cat <<- EOF
		Build script for Beckhoff ZynqMP u-boot targets.

		USAGE:
			${0##*/} <device>

		ARGUMENTS:
			device    Device name (cx8200, cx9240)

		EXAMPLES:
			${0##*/} cx8200
			${0##*/} cx9240

	EOF
}

set -e
set -u

_device="${1:?Missing device argument
$(usage)}"
readonly _device

script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly script_path

curl --location --output pmufw.bin \
	'https://git.beckhoff.dev/beckhoff/zynqmp-pmufw-builder/-/jobs/2176082/artifacts/raw/pmufw.bin'
curl --location --output bl31.bin \
	'https://git.beckhoff.dev/beckhoff/arm-trusted-firmware/-/jobs/754226/artifacts/raw/build/zynqmp/release/bl31.bin'

sha256sum --check "${script_path}/pmufw.bin.sha256sum"
sha256sum --check "${script_path}/bl31.bin.sha256sum"

tools/zynqmp_pm_cfg_obj_convert.py "board/beckhoff/${_device}/pm_cfg_obj.c" pmu_obj.bin

BL31=bl31.bin
export BL31
BINMAN_ALLOW_MISSING=1
export BINMAN_ALLOW_MISSING
make CROSS_COMPILE=aarch64-linux-gnu- clean mrproper
make CROSS_COMPILE=aarch64-linux-gnu- "beckhoff_${_device}_defconfig"
make CROSS_COMPILE=aarch64-linux-gnu- --jobs="$(nproc)"

mkdir --parents "build/${_device}"
cp spl/boot.bin u-boot.itb "build/${_device}/"
