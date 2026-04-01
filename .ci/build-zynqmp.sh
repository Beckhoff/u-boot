#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) Beckhoff Automation GmbH & Co. KG

set -e
set -u

device="${1:?Missing device argument}"
readonly device

script_path="$(cd "$(dirname "${0}")" && pwd)"
readonly script_path

curl --location --output pmufw.bin \
	'https://git.beckhoff.dev/beckhoff/zynqmp-pmufw-builder/-/jobs/2176082/artifacts/raw/pmufw.bin'
curl --location --output bl31.bin \
	'https://git.beckhoff.dev/beckhoff/arm-trusted-firmware/-/jobs/754226/artifacts/raw/build/zynqmp/release/bl31.bin'

sha256sum --check "${script_path}/pmufw.bin.sha256sum"
sha256sum --check "${script_path}/bl31.bin.sha256sum"

tools/zynqmp_pm_cfg_obj_convert.py "board/beckhoff/${device}/pm_cfg_obj.c" pmu_obj.bin

export BL31=bl31.bin
export BINMAN_ALLOW_MISSING=1
make CROSS_COMPILE=aarch64-linux-gnu- clean mrproper
make CROSS_COMPILE=aarch64-linux-gnu- "beckhoff_${device}_defconfig"
make CROSS_COMPILE=aarch64-linux-gnu- --jobs="$(nproc)"

mkdir --parents "build/${device}"
cp spl/boot.bin u-boot.itb "build/${device}/"
