/* 
 *  i.MX 8M Plus Applications Processor Reference Manual, Rev. 1, 06/2021
 *  8.2.4.144-299 SW_PAD_CTL_PAD_XXX Control Register
 */

#ifndef __DTS_IMX8MP_PADCONF_H
#define __DTS_IMX8MP_PADCONF_H

/* Pull Select Field */
#define PAD_PULL_DISABLE		(0x0 << 8)
#define PAD_PULL_ENABLE		(0x1 << 8)

/* Input Select Field */
#define PAD_INPUT_CMOS		(0x0 << 7)
#define PAD_INPUT_SCHMITT	(0x1 << 7)

/* Pull Up / Down Config. Field */
#define PAD_WEAK_PULL_DOWN	(0x0 << 6)
#define PAD_WEAK_PULL_UP		(0x1 << 6)

/* Open Drain Field */
#define PAD_OPEN_DRAIN_DISABLE	(0x0 << 5)
#define PAD_OPEN_DRAIN_ENABLE	(0x1 << 5)

/* Slew Rate Field */
#define PAD_SLOW_SLEW_RATE	(0x0 << 4)
#define PAD_FAST_SLEW_RATE	(0x1 << 4)

/* Drive Strength Field */
#define PAD_DSE_X1			(0x0 << 1)
#define PAD_DSE_X2			(0x2 << 1)
#define PAD_DSE_X4			(0x1 << 1)
#define PAD_DSE_X6			(0x3 << 1)

#endif /* __DTS_IMX8MP_PADCONF_H */


/*
Example:

&iomuxc {
	pinctrl-names = "default";

	pinctrl_uart3: uart3grp {
		fsl,pins = <
			MX8MP_IOMUXC_ECSPI1_SCLK__UART3_DCE_RX				(PAD_PULL_ENABLE | PAD_WEAK_PULL_UP)
			MX8MP_IOMUXC_ECSPI1_MOSI__UART3_DCE_TX				(PAD_PULL_ENABLE | PAD_WEAK_PULL_UP)
			MX8MP_IOMUXC_ECSPI1_MISO__UART3_DCE_CTS				(PAD_PULL_ENABLE | PAD_WEAK_PULL_UP)
			MX8MP_IOMUXC_ECSPI1_SS0__UART3_DCE_RTS				(PAD_PULL_ENABLE | PAD_WEAK_PULL_UP)
		>;
	};
};

*/
