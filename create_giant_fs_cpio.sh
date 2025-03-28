#!/bin/bash

# Set this flag to true to enable gzip compression
COMPRESS=true

if [[ $(id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit 1
fi

# Remove old initramfs files if they exist
rm -f initramfs.cpio*

# Create initial cpio archive from root_fs
(
  cd root_fs && find . | cpio -o --format=newc -O ../initramfs.cpio
)

# Append tools_fs and modules_fs correctly
(
  cd tools_fs && find . | cpio -o --format=newc -A -O ../initramfs.cpio
)
(
  cd modules_fs && find . | cpio -o --format=newc -A -O ../initramfs.cpio
)

# Verify the cpio file is created
if [[ ! -f initramfs.cpio ]]; then
    echo "Error: initramfs.cpio was not created!"
    exit 1
fi

# Set mkimage compression flag
MKIMAGE_COMPRESSION="none"

# If compression is enabled, create a gzipped version
if [[ "$COMPRESS" == true ]]; then
    echo "Compressing initramfs..."
    gzip -c initramfs.cpio > initramfs.cpio.gz
    CPIO_FILE="initramfs.cpio.gz"
    MKIMAGE_COMPRESSION="gzip"
else
    CPIO_FILE="initramfs.cpio"
fi

# Create the U-Boot image with the correct compression flag
mkimage -A arm -O linux -T ramdisk -C "$MKIMAGE_COMPRESSION" -n "Custom Initramfs" -d "$CPIO_FILE" initramfs.uImage

# Change ownership (ensure the user exists)
chown anonymous:anonymous initramfs.uImage

# Move to tftpboot
mv initramfs.uImage tftpboot/

rm -f initramfs.cpio*

echo "Initramfs successfully created and moved to tftpboot/"
