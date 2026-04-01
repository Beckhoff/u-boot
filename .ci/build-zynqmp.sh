#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

usage() {
	cat <<- EOF
		Build script for Beckhoff ZynqMP u-boot targets.

		USAGE:
			${0##*/} build <device>
			${0##*/} download
			${0##*/} update-checksums
			${0##*/} commit-binaries

		COMMANDS:
			build               Build u-boot for device (cx8200, cx9240)
			download            Download FPGA packages, firmware, and update psu_init files
			update-checksums    Update all sha256sum files from current files on disk
			commit-binaries     Commit FPGA binaries, psu_init files, and checksums

		EXAMPLES:
			${0##*/} build cx8200
			${0##*/} build cx9240
			${0##*/} download
			${0##*/} update-checksums
			${0##*/} commit-binaries

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

update_checksum() {
	local _file _sha256 _basename
	_file="${1:?Missing file}"
	_sha256="${2:?Missing sha256sum file}"
	_basename="$(basename "${_file}")"

	(cd "$(dirname "${_file}")" && sha256sum "${_basename}") > "${_sha256}"
	printf 'Updated %s\n' "${_sha256}" >&2
}

update_fpga_checksums() {
	find fpga -type f -name "*.bin.gz" -exec sha256sum {} + \
		| LC_ALL=C sort > "${script_path}/fpga.sha256sum"
	printf 'Updated %s\n' "${script_path}/fpga.sha256sum" >&2
}

download_binaries() {
	if sha256sum --check --status "${script_path}/fpga.sha256sum" 2> /dev/null; then
		printf 'FPGA binaries: checksums OK, skipping download\n' >&2
	else
		: "${AZDEVOPS_PAT_RO=}"
		AZDEVOPS_PAT_RO="${AZDEVOPS_PAT_RO}" nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.1 -OutputDirectory fpga/ -Version 2.0.0-202411261448
		AZDEVOPS_PAT_RO="${AZDEVOPS_PAT_RO}" nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.2 -OutputDirectory fpga/ -Version 2.2.2-202509261031
		AZDEVOPS_PAT_RO="${AZDEVOPS_PAT_RO}" nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.2 -OutputDirectory fpga/ -Version 2.0.0-202411281238
		AZDEVOPS_PAT_RO="${AZDEVOPS_PAT_RO}" nugetctl install \
			Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3 -OutputDirectory fpga/ -Version 2.4.0-202509261117

		find ./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.2/ \
			-type f -name "*.bin" ! -name "*-2.bin" \
			-exec sh -xuc 'mv "$1" "${1%.bin}-2.bin"' _ {} \;
		find ./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3/ \
			-type f -name "*.bin" ! -name "*-3.bin" \
			-exec sh -xuc 'mv "$1" "${1%.bin}-3.bin"' _ {} \;

		find ./fpga -type f -name "*.bin" -exec gzip --no-name {} \;

		"${script_path}/psu-init-helper.sh" update cx8200 \
			./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX8200.2/SDK/CX8200.xsa
		"${script_path}/psu-init-helper.sh" update cx9240 \
			./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3/SDK/CX9240.xsa

		find ./fpga -name "*.nupkg" -delete

		sha256sum --check "${script_path}/fpga.sha256sum"
	fi

	download_file pmufw.bin \
		'https://git.beckhoff.dev/beckhoff/zynqmp-pmufw-builder/-/jobs/2176082/artifacts/raw/pmufw.bin' \
		"${script_path}/pmufw.bin.sha256sum"
	download_file bl31.bin \
		'https://git.beckhoff.dev/beckhoff/arm-trusted-firmware/-/jobs/754226/artifacts/raw/build/zynqmp/release/bl31.bin' \
		"${script_path}/bl31.bin.sha256sum"
}

build_device() {
	local _device
	_device="${1:?Missing device}"

	download_binaries

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

update_checksums() {
	printf 'Updating checksums...\n' >&2
	update_checksum pmufw.bin "${script_path}/pmufw.bin.sha256sum"
	update_checksum bl31.bin "${script_path}/bl31.bin.sha256sum"
	update_fpga_checksums
}

commit_binaries() {
	download_binaries
	find fpga -name "*.bin.gz" -exec git add --force {} +
	git add --force \
		pmufw.bin \
		bl31.bin \
		board/beckhoff/*/psu_init_gpl.c \
		"${script_path}/pmufw.bin.sha256sum" \
		"${script_path}/bl31.bin.sha256sum" \
		"${script_path}/fpga.sha256sum"
	git commit --message "bhf: update FPGA binaries and psu_init files"
}

set -e
set -u

script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly script_path

case "${1:-}" in
	build)
		build_device "${2:?Missing device argument}"
		;;
	download)
		download_binaries
		;;
	update-checksums)
		update_checksums
		;;
	commit-binaries)
		commit_binaries
		;;
	"" | --help | -h)
		usage
		;;
	*)
		# Backwards compatibility: bare device name
		build_device "${1}"
		;;
esac
