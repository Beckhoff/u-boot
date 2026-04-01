#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

usage() {
	cat >&2 << EOF
Build script for Beckhoff ZynqMP u-boot targets.

USAGE:
    ${0##*/} build <device>

COMMANDS:
    build               Build u-boot for device (cx8200, cx9240)

EXAMPLES:
    ${0##*/} build cx8200
    ${0##*/} build cx9240

EOF
}

build_device() {
	local _device
	_device="${1:?Missing device}"

	curl --location --output pmufw.bin \
		'https://git.beckhoff.dev/beckhoff/zynqmp-pmufw-builder/-/jobs/2176082/artifacts/raw/pmufw.bin'
	curl --location --output bl31.bin \
		'https://git.beckhoff.dev/beckhoff/arm-trusted-firmware/-/jobs/754226/artifacts/raw/build/zynqmp/release/bl31.bin'

	sha256sum --check "${script_path}/sha256sum"

	tools/zynqmp_pm_cfg_obj_convert.py "board/beckhoff/${_device}/pm_cfg_obj.c" pmu_obj.bin

	export BL31=bl31.bin
	export BINMAN_ALLOW_MISSING=1
	make CROSS_COMPILE=aarch64-linux-gnu- clean mrproper
	make CROSS_COMPILE=aarch64-linux-gnu- "beckhoff_${_device}_defconfig"
	make CROSS_COMPILE=aarch64-linux-gnu- --jobs="$(nproc)"

	mkdir --parents "build/${_device}"
	cp spl/boot.bin u-boot.itb "build/${_device}/"
}

set -e
set -u

script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly script_path

if test "$#" -eq 0; then
	usage
	exit 0
fi

mode="${1}"
shift

case "${mode}" in
	build)
		build_device "${1:?Missing device argument}"
		;;
	--help | -h)
		usage
		;;
	*)
		printf 'ERROR: Unknown command: %s\n' "${mode}" >&2
		usage >&2
		exit 1
		;;
esac
