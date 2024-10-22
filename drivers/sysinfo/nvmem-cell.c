// SPDX-License-Identifier: GPL-2.0+
/*
 * (C) Copyright 2024, Beckhoff Automation GmbH & Co. KG
 */

#include <dm.h>
#include <nvmem.h>
#include <sysinfo.h>

const char *sysinfo_id_to_nvmem_cell_name(enum sysinfo_id id)
{
	switch (id) {
	case SYSID_SM_SYSTEM_MANUFACTURER:
		return "system_manufacturer";
	case SYSID_SM_SYSTEM_PRODUCT:
		return "system_product";
	case SYSID_SM_SYSTEM_VERSION:
		return "system_version";
	case SYSID_SM_SYSTEM_SERIAL:
		return "system_serial";
	case SYSID_SM_SYSTEM_SKU:
		return "system_sku";
	case SYSID_SM_SYSTEM_FAMILY:
		return "system_family";
	case SYSID_SM_BASEBOARD_MANUFACTURER:
		return "baseboard_manufacturer";
	case SYSID_SM_BASEBOARD_PRODUCT:
		return "baseboard_product";
	case SYSID_SM_BASEBOARD_VERSION:
		return "baseboard_version";
	case SYSID_SM_BASEBOARD_SERIAL:
		return "baseboard_serial";
	case SYSID_SM_BASEBOARD_ASSET_TAG:
		return "baseboard_asset_tag";
	case SYSID_SM_ENCLOSURE_ASSET_TAG:
		return "chassis_asset_tag";
	default:
		return NULL;
	}
}

int sysinfo_nvmem_get_str(struct udevice *dev, int id, size_t size, char *val)
{
	struct nvmem_cell cell;
	int result = 0;
	const char *name = sysinfo_id_to_nvmem_cell_name(id);

	if (!name)
		return -EINVAL;

	if (nvmem_cell_get_by_name(dev, name, &cell))
		return -ENOENT;

	if (cell.size > size)
		return -ENOSPC;

	result = nvmem_cell_read(&cell, val, cell.size);
	if (result)
		return result;

	/* nvmem data may not be null terminated */
	val[cell.size - 1] = 0;
	return 0;
}

static const struct udevice_id sysinfo_nvmem_ids[] = {
	{ .compatible = "u-boot,sysinfo-nvmem-cell" },
	{ /* sentinel */ }
};

int sysinfo_nvmem_detect(struct udevice *dev)
{
	return 0;
}

static const struct sysinfo_ops sysinfo_nvmem_ops = {
	.detect = sysinfo_nvmem_detect,
	.get_str = sysinfo_nvmem_get_str,
};

U_BOOT_DRIVER(sysinfo_nvmem) = {
	.name           = "sysinfo_nvmem_cell",
	.id             = UCLASS_SYSINFO,
	.of_match       = sysinfo_nvmem_ids,
	.ops		= &sysinfo_nvmem_ops,
};
