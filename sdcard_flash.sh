#!/bin/sh

GREEN='\e[0;32m'
RED='\e[0;31m'
PURPLE='\e[0;35m'
NC='\e[0m'

echo "${GREEN}**********************************************************"
echo "****************sdcard writing script*********************"
echo "**********************************************************${NC}"

STARTTIME=$(date +%s)
if [ $# -ne 2 ]
  then
    echo "${RED}No arguments supplied"
    echo "argument 1 specify the Image folder path"
    echo "argument 2 specify the sdcard drive path${NC}"
    echo "${PURPLE}Usage: ./sdcard_flash.sh argument1 argument2"
    echo "example: sudo ./sdcard_flash.sh /home/images /dev/sdx${NC}"
    
    exit 1
fi


##---------Start of variables---------------------##

## Set Image path here
IMAGE_DRIVE_PATH=$1

SD_DRIVE_PATH=$2

# Name of the images to grab from USB drive mount path
UBOOT_FILE="u-boot.imx"
ROOTFS="buildroot/rootfs.tar"
DTB="imx6dl-kb-nextgen.dtb"
KERNEL="zImage"

umount ${SD_DRIVE_PATH}*
sleep 2
sync
umount ${SD_DRIVE_PATH}*
sync

## Kill any partition info that might be there
dd if=/dev/zero of=$SD_DRIVE_PATH bs=4k count=1
sync
sync

## Partitioning the Sdcard using information gathered.
## Here is where you can add/remove partitions.
## We are building 2 partitions:
##  1. FAT32 to save bootloaded, kernel
##  2. Linux to save filesystem

echo "${GREEN}**********************************************************"
echo "                      clearing sdcard...                    "
echo "**********************************************************${NC}"
sleep 2

dd if=/dev/zero of=$SD_DRIVE_PATH bs=1024 count=1024

sleep 2

SIZE=`fdisk -l $SD_DRIVE_PATH | grep Disk | awk '{print $5}'`

echo "DISK SIZE = $SIZE bytes"
sync

sleep 3

cat << END | fdisk -H 255 -S 63 $SD_DRIVE_PATH
n
p
1
2048
2000000
n
p
2
2000001

w
END

echo "${GREEN}**********************************************************"
echo "            PARTITIONING of sdcard is done                  "
echo "**********************************************************${NC}"


echo "${GREEN}**********************************************************"
echo "               copy bootloader to eMMC              "
echo "**********************************************************${NC}"

dd if=${IMAGE_DRIVE_PATH}/u-boot.imx of=${SD_DRIVE_PATH} bs=512 seek=2 conv=fsync
uboot_pid=$!

echo "Waiting for ${UBOOT_FILE} to finish dd..."
wait $uboot_pid
sync
sync

echo "${GREEN}**********************************************************"
echo "                copy kernel & DTB file                    "
echo "**********************************************************${NC}"
mkdosfs -F 32 -n "boot" ${SD_DRIVE_PATH}1
mldosfs_pid=$!

echo "${GREEN}**********************************************************"
echo "          Waiting for FAT32 partitioning to finish...     "
echo "**********************************************************${NC}"
wait $mldosfs_pid

mkdir part1
mount ${SD_DRIVE_PATH}1 part1
mount1_pid=$!

echo "${GREEN}**********************************************************"
echo "           Waiting for FAT32 mouting to finish...         "
echo "**********************************************************${NC}"
wait $mount1_pid

cd part1
sync
cp ${IMAGE_DRIVE_PATH}/${DTB} .
dtb_pid=$!

echo "${GREEN}**********************************************************"
echo "           Waiting for ${DTB} to finish...           "
echo "**********************************************************${NC}"
wait $dtb_pid

cp ${IMAGE_DRIVE_PATH}/${KERNEL} .
kernel_pid=$!

echo "${GREEN}**********************************************************"
echo "           Waiting for ${KERNEL} to finish...        "
echo "**********************************************************${NC}"
wait $kernel_pid
cd ../

echo "${GREEN}**********************************************************"
echo "                      copy rootfs                         "
echo "**********************************************************${NC}"
mkfs.ext4 -F -L "rootfs" ${SD_DRIVE_PATH}2
mke2fs_pid=$!

echo "${GREEN}**********************************************************"
echo "          Waiting for ext4 partitioning to finish...      "
echo "**********************************************************${NC}"
wait $mke2fs_pid

mkdir part2
mount ${SD_DRIVE_PATH}2 part2
mount2_pid=$!

echo "${GREEN}**********************************************************"
echo "            Waiting for ext2 mouting to finish...         "
echo "**********************************************************${NC}"
wait $mount2_pid

tar -C part2 -xvf ${IMAGE_DRIVE_PATH}/${ROOTFS}
rootfsflash_pid=$!

echo "${GREEN}**********************************************************"
echo "          Waiting for ${ROOTFS} to SDCARD write finish... "
echo "**********************************************************${NC}"
wait $rootfsflash_pid

chown -R root:root part2/*

sleep 4
umount part2
umount part1

sleep 2
sync
sync

rm -rf part2
rm -rf part1

umount ${SD_DRIVE_PATH}1
umount ${SD_DRIVE_PATH}2


echo "${GREEN}**********************************************************"
echo "**********************FINISHED FLASHING*******************"
echo "**********************************************************${NC}"
