#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

usage() {
	cat <<- EOF
		Build script for Beckhoff ZynqMP u-boot targets.

		USAGE:
			${0##*/} build <device>

		COMMANDS:
			build    Build u-boot for device (cx8200, cx9240)

		EXAMPLES:
			${0##*/} build cx8200
			${0##*/} build cx9240

	EOF
}

download_file() {
	local _output _url _sha256
	_output="${1:?Missing output}"
	_url="${2:?Missing url}"
	_sha256="${3:?Missing sha256sum file}"

	if test -f "${_output}" && sha256sum --check --status "${_sha256}" 2> /dev/null; then
		printf '%s: checksum OK, skipping download\n' "${_output}" >&2
		return
	fi
	printf '%s: downloading...\n' "${_output}" >&2
	curl --location --output "${_output}" "${_url}"
	sha256sum --check "${_sha256}"
}

build_device() {
	local _device
	_device="${1:?Missing device}"

	download_file pmufw.bin \
		'https://git.beckhoff.dev/beckhoff/zynqmp-pmufw-builder/-/jobs/2176082/artifacts/raw/pmufw.bin' \
		"${script_path}/pmufw.bin.sha256sum"
	download_file bl31.bin \
		'https://git.beckhoff.dev/beckhoff/arm-trusted-firmware/-/jobs/754226/artifacts/raw/build/zynqmp/release/bl31.bin' \
		"${script_path}/bl31.bin.sha256sum"

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
}

set -e
set -u

script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly script_path

case "${1:-}" in
	build)
		build_device "${2:?Missing device argument}"
		;;
	"" | --help | -h)
		usage
		;;
	*)
		# Backwards compatibility: bare device name
		build_device "${1}"
		;;
esac
