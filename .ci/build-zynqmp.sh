#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

usage() {
	cat >&2 << EOF
Build script for Beckhoff ZynqMP u-boot targets.

USAGE:
    ${0##*/} build <device>
    ${0##*/} download
    ${0##*/} update-checksums

COMMANDS:
    build               Build u-boot for device (cx8200, cx9240)
    download            Download firmware (pmufw.bin, bl31.bin)
    update-checksums    Update sha256sum file from current files on disk

EXAMPLES:
    ${0##*/} build cx8200
    ${0##*/} build cx9240
    ${0##*/} download
    ${0##*/} update-checksums

EOF
}

download_file() {
	local _output _url
	_output="${1:?Missing output}"
	_url="${2:?Missing url}"

	if test -f "${_output}" \
		&& grep --fixed-strings "  ${_output}" "${script_path}/sha256sum" \
		| sha256sum --check --status 2> /dev/null; then
		printf '%s: checksum OK, skipping download\n' "${_output}" >&2
		return
	fi
	printf '%s: downloading...\n' "${_output}" >&2
	curl --location --output "${_output}" "${_url}"
	grep --fixed-strings "  ${_output}" "${script_path}/sha256sum" | sha256sum --check
}

download_binaries() {
	download_file pmufw.bin \
		'https://git.beckhoff.dev/beckhoff/zynqmp-pmufw-builder/-/jobs/2176082/artifacts/raw/pmufw.bin'
	download_file bl31.bin \
		'https://git.beckhoff.dev/beckhoff/arm-trusted-firmware/-/jobs/754226/artifacts/raw/build/zynqmp/release/bl31.bin'
}

build_device() {
	local _device
	_device="${1:?Missing device}"

	download_binaries

	tools/zynqmp_pm_cfg_obj_convert.py "board/beckhoff/${_device}/pm_cfg_obj.c" pmu_obj.bin

	export BL31=bl31.bin
	export BINMAN_ALLOW_MISSING=1
	make CROSS_COMPILE=aarch64-linux-gnu- clean mrproper
	make CROSS_COMPILE=aarch64-linux-gnu- "beckhoff_${_device}_defconfig"
	make CROSS_COMPILE=aarch64-linux-gnu- --jobs="$(nproc)"

	mkdir --parents "build/${_device}"
	cp spl/boot.bin u-boot.itb "build/${_device}/"
}

update_checksums() {
	sha256sum pmufw.bin bl31.bin > "${script_path}/sha256sum"
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
	download)
		download_binaries
		;;
	update-checksums)
		update_checksums
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
