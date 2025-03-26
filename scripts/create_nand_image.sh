#!/bin/bash

# Output NAND image file
NAND_IMAGE="./out/nand.img"

# NAND total size (adjust as needed)
NAND_TOTAL_SIZE=$((0x8000000))  # 128MB

# Create empty NAND image
echo "Creating NAND image of size $NAND_TOTAL_SIZE bytes..."
dd if=/dev/zero of=$NAND_IMAGE count=1 bs=$NAND_TOTAL_SIZE

# Define partitions (offset, size)
PARTITIONS=(
    "spl 0x000000 0x20000 ./u-boot-antminer-beaglebone/MLO"
    "spl_backup1 0x20000 0x20000 ./u-boot-antminer-beaglebone/MLO"
    "spl_backup2 0x40000 0x20000 ./u-boot-antminer-beaglebone/MLO"
    "spl_backup3 0x60000 0x20000 ./u-boot-antminer-beaglebone/MLO"
    "u-boot 0x80000 0x1c0000 ./u-boot-antminer-beaglebone/u-boot.img"
    "bootenv 0x240000 0x20000 ./out/bootenv.bin"
    "fdt 0x260000 0x20000 ./fat/extlinux/am335x-boneblack-blackmainer.dtb"
    "kernel 0x280000 0x500000 ./fat/zImage"
    "root 0x800000 0x1400000 ./out/initramfs.bin.SD"
    "config 0x1c00000 0x1400000 ./out/config.ext4"
    "fpgabit 0x3000000 0x5000000 ./out/fpga.ext4"
)

echo "Packing root filesystem into initramfs ..."
cd fs  # Go into the root filesystem folder
# Create the initramfs.cpio.gz
find . | cpio -o -H newc | gzip > ../out/initramfs.cpio.gz
cd ..  # Go back to the parent directory
# Create the U-Boot initramfs image (uImage)
mkimage -A arm -O linux -T ramdisk -C gzip -d ./out/initramfs.cpio.gz ./out/initramfs.bin.SD

echo "Creating /fpgabit partition"
# Define size (0x5000000 = 80MB)
SIZE=$((0x5000000))
# Create an empty file of the correct size
dd if=/dev/zero of=./out/fpga.ext4 bs=$SIZE count=1
# Format it as ext4
./legacy_tools/mkfs.ext4 ./out/fpga.ext4
# Create a temporary mount point
mkdir -p mnt_fpga
# Mount the image
sudo mount -o loop ./out/fpga.ext4 mnt_fpga
# Copy all bitstreams/* into the filesystem
sudo cp -r bitstreams/* mnt_fpga/
# Sync and unmount
sync
sudo umount mnt_fpga
# Remove the temporary mount point
rmdir mnt_fpga

echo "Creating /config partition"
SIZE=$((0x1400000))
# Create an empty file of the correct size
dd if=/dev/zero of=./out/config.ext4 bs=$SIZE count=1
# Format it as ext4
./legacy_tools/mkfs.ext4 ./out/config.ext4
# Create a temporary mount point
mkdir -p mnt_config
# Mount the image
sudo mount -o loop ./out/config.ext4 mnt_config
# Copy all bitstreams/* into the filesystem
sudo cp -r configs/* mnt_config/
# Sync and unmount
sync
sudo umount mnt_config
# Remove the temporary mount point
rmdir mnt_config

echo "Creating bootenv.bin image ..."
mkenvimage -s 0x20000 -o ./out/bootenv.bin ./bootenv/bootenv.txt

echo "Writing partition image ..."
# Create partitions
for entry in "${PARTITIONS[@]}"; do
    set -- $entry
    NAME=$1
    OFFSET=$(($2))
    SIZE=$(($3))
    FILENAME=$4

    echo "Creating partition '$NAME' at offset $OFFSET with size $SIZE and file $FILENAME ..."
    dd if=$FILENAME bs=512 seek=$((OFFSET / 512)) of=$NAND_IMAGE count=$((SIZE / 512)) conv=notrunc
done



echo "NAND image creation complete: $NAND_IMAGE"
