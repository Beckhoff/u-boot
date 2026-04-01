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
    download            Download firmware and FPGA bitstreams
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

	if grep --fixed-strings '  fpga/' "${script_path}/sha256sum" \
		| sha256sum --check --status 2> /dev/null; then
		printf 'fpga: checksums OK, skipping download\n' >&2
	else
		: "${AZDEVOPS_PAT_RO:?AZDEVOPS_PAT_RO must be set}"
		nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.1 -OutputDirectory fpga/ -Version 2.0.0-202411261448
		nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.2 -OutputDirectory fpga/ -Version 2.2.2-202509261031
		nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.2 -OutputDirectory fpga/ -Version 2.0.0-202411281238
		nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3 -OutputDirectory fpga/ -Version 2.4.0-202509261117

		# We need to move the fpga binaries to the paths expected by our debian package install file and eeprom names
		find ./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.2/ \
			-type f -name "*.bin" ! -name "*-2.bin" \
			-exec sh -xuc 'mv "$1" "${1%.bin}-2.bin"' _ {} \;
		find ./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3/ \
			-type f -name "*.bin" ! -name "*-3.bin" \
			-exec sh -xuc 'mv "$1" "${1%.bin}-3.bin"' _ {} \;

		find ./fpga -type f -name "*.bin" -exec gzip --no-name {} \;

		find ./fpga -name "*.nupkg" -delete

		grep --fixed-strings '  fpga/' "${script_path}/sha256sum" | sha256sum --check
	fi

	"${script_path}/psu-init-helper.sh" check cx8200 \
		./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.2/SDK/CX8200.xsa
	"${script_path}/psu-init-helper.sh" check cx9240 \
		./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3/SDK/CX9240.xsa
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
	{
		sha256sum pmufw.bin bl31.bin
		find fpga -type f -name "*.bin.gz" -exec sha256sum {} +
	} | LC_ALL=C sort > "${script_path}/sha256sum"
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
