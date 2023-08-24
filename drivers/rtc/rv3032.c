// SPDX-License-Identifier: GPL-2.0
/*
 * RTC driver for the Micro Crystal RV3032
 *
 * based on linux driver from
 * Copyright (C) 2020 Micro Crystal SA
 *
 * Alexandre Belloni <alexandre.belloni@bootlin.com>
 *
 */

#include <dm.h>
#include <i2c.h>
#include <linux/delay.h>
#include <regmap.h>
#include <rtc.h>
#include <time.h>

#define RV3032_SEC			0x01
#define RV3032_MIN			0x02
#define RV3032_HOUR			0x03
#define RV3032_WDAY			0x04
#define RV3032_DAY			0x05
#define RV3032_MONTH			0x06
#define RV3032_YEAR			0x07
#define RV3032_ALARM_MIN		0x08
#define RV3032_ALARM_HOUR		0x09
#define RV3032_ALARM_DAY		0x0A
#define RV3032_STATUS			0x0D
#define RV3032_TLSB			0x0E
#define RV3032_TMSB			0x0F
#define RV3032_CTRL1			0x10
#define RV3032_CTRL2			0x11
#define RV3032_CTRL3			0x12
#define RV3032_TS_CTRL			0x13
#define RV3032_CLK_IRQ			0x14
#define RV3032_EEPROM_ADDR		0x3D
#define RV3032_EEPROM_DATA		0x3E
#define RV3032_EEPROM_CMD		0x3F
#define RV3032_RAM1			0x40
#define RV3032_PMU			0xC0
#define RV3032_OFFSET			0xC1
#define RV3032_CLKOUT1			0xC2
#define RV3032_CLKOUT2			0xC3
#define RV3032_TREF0			0xC4
#define RV3032_TREF1			0xC5

#define RV3032_STATUS_VLF		BIT(0)
#define RV3032_STATUS_PORF		BIT(1)
#define RV3032_STATUS_EVF		BIT(2)
#define RV3032_STATUS_AF		BIT(3)
#define RV3032_STATUS_TF		BIT(4)
#define RV3032_STATUS_UF		BIT(5)
#define RV3032_STATUS_TLF		BIT(6)
#define RV3032_STATUS_THF		BIT(7)

#define RV3032_TLSB_CLKF		BIT(1)
#define RV3032_TLSB_EEBUSY		BIT(2)
#define RV3032_TLSB_TEMP		GENMASK(7, 4)

#define RV3032_CLKOUT2_HFD_MSK		GENMASK(4, 0)
#define RV3032_CLKOUT2_FD_MSK		GENMASK(6, 5)
#define RV3032_CLKOUT2_OS		BIT(7)

#define RV3032_CTRL1_EERD		BIT(3)
#define RV3032_CTRL1_WADA		BIT(5)

#define RV3032_CTRL2_STOP		BIT(0)
#define RV3032_CTRL2_EIE		BIT(2)
#define RV3032_CTRL2_AIE		BIT(3)
#define RV3032_CTRL2_TIE		BIT(4)
#define RV3032_CTRL2_UIE		BIT(5)
#define RV3032_CTRL2_CLKIE		BIT(6)
#define RV3032_CTRL2_TSE		BIT(7)

#define RV3032_PMU_TCM			GENMASK(1, 0)
#define RV3032_PMU_TCR			GENMASK(3, 2)
#define RV3032_PMU_BSM			GENMASK(5, 4)
#define RV3032_PMU_NCLKE		BIT(6)

#define RV3032_PMU_BSM_DSM		1
#define RV3032_PMU_BSM_LSM		2

#define RV3032_OFFSET_MSK		GENMASK(5, 0)

#define RV3032_EVT_CTRL_TSR		BIT(2)

#define RV3032_EEPROM_CMD_UPDATE	0x11
#define RV3032_EEPROM_CMD_WRITE		0x21
#define RV3032_EEPROM_CMD_READ		0x22

#define RV3032_EEPROM_USER		0xCB

#define RV3032_EEBUSY_POLL		10000
#define RV3032_EEBUSY_TIMEOUT		100000

#define OFFSET_STEP_PPT			238419

static int rv3032_update_bits(struct udevice *dev, u8 reg, u8 mask, u8 set)
{
	u8 buf;
	int ret;

	ret = dm_i2c_read(dev, reg, &buf, 1);
	if (ret < 0)
		return ret;

	if ((buf & mask) == (set && mask))
		return 0;

	buf = (buf & ~mask) | (set & mask);
	ret = dm_i2c_read(dev, reg, &buf, 1);
	if (ret < 0)
		return ret;

	return 0;
}

static int rv3032_eeprom_busywait(struct udevice *dev)
{
	int ret;
	u8 status;
	unsigned long start = get_timer(0);

	for (;;) {
		ret = dm_i2c_read(dev, RV3032_TLSB, &status, 1);
		if (ret < 0)
			break;
		if (!(status & RV3032_TLSB_EEBUSY))
			break;
		if (get_timer(start) > RV3032_EEBUSY_TIMEOUT)
			return -ETIMEDOUT;
		udelay(RV3032_EEBUSY_POLL);
	}

	return ret;
}

static int rv3032_exit_eerd(struct udevice *dev, u32 eerd)
{
	if (eerd)
		return 0;

	return rv3032_update_bits(dev, RV3032_CTRL1, RV3032_CTRL1_EERD, 0);
}

static int rv3032_enter_eerd(struct udevice *dev, u32 *eerd)
{
	u8 ctrl1;
	int ret;

	ret = dm_i2c_read(dev, RV3032_CTRL1, &ctrl1, sizeof(ctrl1));
	if (ret)
		return ret;

	*eerd = ctrl1 & RV3032_CTRL1_EERD;
	if (*eerd)
		return 0;

	ret = rv3032_update_bits(dev, RV3032_CTRL1,
				 RV3032_CTRL1_EERD, RV3032_CTRL1_EERD);
	if (ret)
		return ret;

	ret = rv3032_eeprom_busywait(dev);
	if (ret) {
		rv3032_exit_eerd(dev, *eerd);

		return ret;
	}

	return 0;
}

static int rv3032_get_time(struct udevice *dev, struct rtc_time *tm)
{
	u8 date[7];
	int ret;
	u8 status;

	ret = dm_i2c_read(dev, RV3032_STATUS, &status, 1);
	if (ret < 0)
		return ret;

	if (status & (RV3032_STATUS_PORF | RV3032_STATUS_VLF))
		return -EINVAL;

	ret = dm_i2c_read(dev, RV3032_SEC, date, sizeof(date));
	if (ret)
		return ret;

	tm->tm_sec  = bcd2bin(date[0] & 0x7f);
	tm->tm_min  = bcd2bin(date[1] & 0x7f);
	tm->tm_hour = bcd2bin(date[2] & 0x3f);
	tm->tm_wday = date[3] & 0x7;
	tm->tm_mday = bcd2bin(date[4] & 0x3f);
	tm->tm_mon  = bcd2bin(date[5] & 0x1f);
	tm->tm_year = bcd2bin(date[6]) + 2000;

	return 0;
}

static int rv3032_set_time(struct udevice *dev, const struct rtc_time *tm)
{
	u8 date[7];
	int ret;

	date[0] = bin2bcd(tm->tm_sec);
	date[1] = bin2bcd(tm->tm_min);
	date[2] = bin2bcd(tm->tm_hour);
	date[3] = tm->tm_wday;
	date[4] = bin2bcd(tm->tm_mday);
	date[5] = bin2bcd(tm->tm_mon);
	date[6] = bin2bcd(tm->tm_year - 2000);

	ret = dm_i2c_write(dev, RV3032_SEC, date,
			   sizeof(date));
	if (ret)
		return ret;

	ret = rv3032_update_bits(dev, RV3032_STATUS,
				 RV3032_STATUS_PORF | RV3032_STATUS_VLF, 0);

	return ret;
}

static int rv3032_eeprom_write(struct udevice *dev, unsigned int reg,
			       const u8 *buf, unsigned int len)
{
	u32 eerd;
	int i, ret;
	u8 cmd;

	ret = rv3032_enter_eerd(dev, &eerd);
	if (ret)
		return ret;

	for (i = 0; i < len; i++) {
		cmd	= RV3032_EEPROM_USER + reg + i;
		ret = dm_i2c_write(dev, RV3032_EEPROM_ADDR,
				   &cmd, 1);
		if (ret)
			goto exit_eerd;

		ret = dm_i2c_write(dev, RV3032_EEPROM_DATA, &buf[i], 1);
		if (ret)
			goto exit_eerd;

		cmd = RV3032_EEPROM_CMD_WRITE;
		ret = dm_i2c_write(dev, RV3032_EEPROM_CMD,
				   &cmd, 1);
		if (ret)
			goto exit_eerd;

		udelay(RV3032_EEBUSY_POLL);

		ret = rv3032_eeprom_busywait(dev);
		if (ret)
			goto exit_eerd;
	}

exit_eerd:
	rv3032_exit_eerd(dev, eerd);

	return ret;
}

static int rv3032_eeprom_read(struct udevice *dev, unsigned int reg,
			      u8 *buf, unsigned int len)
{
	u32 eerd;
	int i, ret;
	u8 cmd, data;

	ret = rv3032_enter_eerd(dev, &eerd);
	if (ret)
		return ret;

	for (i = 0; i < len; i++) {
		cmd = RV3032_EEPROM_USER + reg + i;
		ret = dm_i2c_write(dev, RV3032_EEPROM_ADDR,
				   &cmd, 1);
		if (ret)
			goto exit_eerd;

		cmd = RV3032_EEPROM_CMD_READ;
		ret = dm_i2c_write(dev, RV3032_EEPROM_CMD,
				   &cmd, 1);
		if (ret)
			goto exit_eerd;

		ret = rv3032_eeprom_busywait(dev);
		if (ret)
			goto exit_eerd;

		ret = dm_i2c_read(dev, RV3032_EEPROM_DATA, &data, sizeof(data));
		if (ret)
			goto exit_eerd;
		buf[i] = data;
	}

exit_eerd:
	rv3032_exit_eerd(dev, eerd);

	return ret;
}

static int rv3032_probe(struct udevice *dev)
{
	i2c_set_chip_flags(dev, DM_I2C_CHIP_RD_ADDRESS |
			DM_I2C_CHIP_WR_ADDRESS);

	return 0;
}

static const struct rtc_ops rv3032_rtc_ops = {
	.get = rv3032_get_time,
	.set = rv3032_set_time,
	.read = rv3032_eeprom_read,
	.write = rv3032_eeprom_write,
};

static const struct udevice_id rv3032_rtc_ids[] = {
	{ .compatible = "microcrystal,rv3032", },
	{ }
};

U_BOOT_DRIVER(rtc_rv3032) = {
	.name	= "rtc-rv3028",
	.id	= UCLASS_RTC,
	.probe	= rv3032_probe,
	.of_match = rv3032_rtc_ids,
	.ops	= &rv3032_rtc_ops,
};
