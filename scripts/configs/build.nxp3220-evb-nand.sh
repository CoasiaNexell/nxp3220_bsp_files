#!/bin/bash

TARGET_RESULT=result-nxp3220-evb-nand

# For BL2
TARGET_BL2_CHIP=nxp3220
TARGET_BL2_BOARD=evb
TARGET_BL2_PMIC=nxe1500
TARGET_BL2_NSIH=nsih_evb_nand_ddr3_800Mhz.txt

# For BL32
TARGET_BL32_LOADADDR=0x5F000000

# For Kernel
TARGET_KERNEL_DEFCONFIG=nxp3220_evb_nand_defconfig
TARGET_KERNEL_DTB=nxp3220-evb-nand
TARGET_KERNEL_IMAGE=zImage

# For U-boot
TARGET_UBOOT_DEFCONFIG=nxp3220_evb_nand_defconfig

# For Buildroot
TARGET_BR2_DEFCONFIG=nxp3220_sysv_defconfig

# For Filesystem image
TARGET_IMAGE_TYPE="ubi"
TARGET_BOOT_IMAGE_SIZE=32M
TARGET_ROOT_IMAGE_SIZE=82M

FLASH_PAGE_SIZE=2048
FLASH_BLOCK_SIZE=128K
FLASH_DEVICE_SIZE=128M

# build script
BUILD_CONFIG_DIR="$(dirname `realpath $BASH_SOURCE`)"
source $BUILD_SRC_DIR/build.common.sh
