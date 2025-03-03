#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <device>"
    echo "Example: $0 /dev/mmcblk0"
    exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: Device $DEVICE not found!"
    exit 1
fi

BOOT_LABEL="BOOT"
CONFIG_LABEL="CONFIG"
ROOT_LABEL="ROOTFS"
FPGABIT_LABEL="BITSTREAMS"

# Ensure device is not mounted
echo "Unmounting $DEVICE..."
sudo umount "${DEVICE}"* || true

# Create partitions using MB
echo "Creating partitions on $DEVICE..."
sudo parted -s "$DEVICE" mklabel msdos

# Create BOOT partition (64MB)
sudo parted -a optimal -s "$DEVICE" mkpart primary fat32 0% 64MB
sudo parted -s "$DEVICE" set 1 boot on

# Create ROOT partition (middle partition)
sudo parted -s "$DEVICE" mkpart primary ext2 64MB 192MB

# Create CONFIG partition (64MB)
sudo parted -s "$DEVICE" mkpart primary fat32 192MB 256MB

# And the bitstream partition
sudo parted -s "$DEVICE" mkpart primary fat32 256MB 1024MB

# Get partition names
BOOT_PART="${DEVICE}p1"
ROOT_PART="${DEVICE}p2"
CONFIG_PART="${DEVICE}p3"
BIT_PART="${DEVICE}p4"

# Wait for the kernel to detect new partitions
sleep 2

# Format partitions
echo "Formatting BOOT partition..."
sudo mkfs.vfat -F 32 -n "$BOOT_LABEL" "$BOOT_PART"

echo "Formatting CONFIG partition..."
sudo mkfs.vfat -F 32 -n "$CONFIG_LABEL" "$CONFIG_PART"

echo "Formatting BITSTREAM partition..."
sudo mkfs.vfat -F 32 -n "$FPGABIT_LABEL" "$BIT_PART"

echo "Formatting ROOT partition using create_ext4_from_config.sh..."
sudo mkfs.ext2 -L "$ROOT_LABEL" "$ROOT_PART"

# Mount partitions
BOOT_MOUNT=$(mktemp -d)
ROOT_MOUNT=$(mktemp -d)
FPGA_MOUNT=$(mktemp -d)

sudo mount "$BOOT_PART" "$BOOT_MOUNT"
sudo mount "$ROOT_PART" "$ROOT_MOUNT"
sudo mount "$BIT_PART"  "$FPGA_MOUNT"

# Copy bootloader files
echo "Copying bootloader files to BOOT partition..."
sudo cp u-boot-antminer-beaglebone/MLO u-boot-antminer-beaglebone/u-boot.img "$BOOT_MOUNT"
sudo cp -r fat/* "$BOOT_MOUNT"

# Copy root filesystem
echo "Copying root filesystem to ROOT partition..."
sudo cp -a fs/* "$ROOT_MOUNT"

# Copy bitstreams
sudo cp -r bitstreams/* "$FPGA_MOUNT"

# Sync and unmount
echo "Syncing files..."
sync
sudo umount "$BOOT_MOUNT"
sudo umount "$ROOT_MOUNT"
sudo umount "$FPGA_MOUNT"

# Cleanup
rmdir "$BOOT_MOUNT" "$ROOT_MOUNT"

echo "SD card setup complete!"
