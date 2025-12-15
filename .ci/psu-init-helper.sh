#!/bin/sh

usage() {
	cat <<- EOF
		PSU Init Helper Script

		Updates or checks psu_init_gpl.c files from Xilinx SDK archives.

		USAGE:
			${0##*/} update <device> <xsa-file>
			${0##*/} check <device> <xsa-file>

		COMMANDS:
			update  Extract and process psu_init_gpl.c from XSA file to board directory
			check   Verify if current psu_init_gpl.c matches the one in XSA file

		ARGUMENTS:
			device    Device name (cx8200, cx9240)
			xsa-file  Path to the .xsa file containing psu_init_gpl.c

		EXAMPLES:
			${0##*/} update cx9240 ./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3/SDK/CX9240.xsa
			${0##*/} check cx9240 ./fpga/Beckhoff.HWE.FPGA.EmbeddedControl.CX9240.3/SDK/CX9240.xsa

	EOF
}

cleanup() {
	set +e
	if ! test -z "${TEMP_DIR+x}"; then
		rm -rf "${TEMP_DIR}"
	fi
}

run() {
	local _mode="${1:?Missing command}"
	local _device="${2:?Missing device}"
	local _xsa_file="${3:?Missing xsa-file}"
	local _board_dir="${u_boot_root}/board/beckhoff/${_device}"
	readonly _mode _device _xsa_file _board_dir
	mkdir -p "${TEMP_DIR}/input" "${TEMP_DIR}/output"

	if ! unzip -q "${_xsa_file}" "psu_init_gpl.c" "psu_init_gpl.h" -d "${TEMP_DIR}/input" 2> /dev/null; then
		printf 'ERROR: Failed to extract psu_init_gpl files from %s\n' "${_xsa_file}" >&2
		return 1
	fi
	"${u_boot_root}/tools/zynqmp_psu_init_minimize.sh" "${TEMP_DIR}/input" "${TEMP_DIR}/output"

	if test "${_mode}" = "update"; then
		cp "${TEMP_DIR}/output/psu_init_gpl.c" "${_board_dir}/"
		return 0
	fi

	if diff -q "${_board_dir}/psu_init_gpl.c" "${TEMP_DIR}/output/psu_init_gpl.c" > /dev/null; then
		printf '✓ psu_init_gpl.c for %s is up to date\n' "${_device}" >&2
	else
		printf '✗ psu_init_gpl.c for %s is outdated\n' "${_device}" >&2
		printf '  Run: %s update %s %s\n' "${0}" "${_device}" "${_xsa_file}" >&2
		return 1
	fi
}

main() {
	if test $# -ne 3; then
		printf 'ERROR: Invalid number of arguments\n' >&2
		usage >&2
		exit 1
	fi

	case "${1}" in
		update | check)
			run "${1}" "${2}" "${3}"
			;;
		*)
			printf 'ERROR: Unknown command: %s\n' "${1}" >&2
			usage >&2
			exit 1
			;;
	esac
}

set -e
set -u

trap cleanup EXIT INT TERM

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly script_path
u_boot_root="$(cd "${script_path}/.." && pwd)"
readonly u_boot_root

main "$@"
