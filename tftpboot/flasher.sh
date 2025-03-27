SERVER_IP=192.168.100.1

echo "Downloading necessary tools ..."
tftp -g -r nandwrite $SERVER_IP

echo "Downloading images ..."
tftp -g -r initramfs.bin.SD $SERVER_IP
tftp -g -r fpga.ext4 $SERVER_IP
tftp -g -r config.ext4 $SERVER_IP
tftp -g -r bootenv.bin $SERVER_IP
tftp -g -r u-boot.img $SERVER_IP
tftp -g -r MLO $SERVER_IP
tftp -g -r uImage.bin $SERVER_IP
tftp -g -r am335x-boneblack-blackmainer.dtb $SERVER_IP

echo "Detecting whether eMMC or NAND ..."

if [ -e /dev/mtd8 ]; then
    echo "** DETECTED: NAND ***"
    if [ -e MLO ]; then
        echo "flash spl partition 1 of 4"
        flash_eraseall /dev/mtd0 >/dev/null 2>&1
        nandwrite -p /dev/mtd0 MLO >/dev/null 2>&1

        echo "flash spl partition 2 of 4"
        flash_eraseall /dev/mtd1 >/dev/null 2>&1
        nandwrite -p /dev/mtd1 MLO >/dev/null 2>&1

        echo "flash spl partition 3 of 4"
        flash_eraseall /dev/mtd2 >/dev/null 2>&1
        nandwrite -p /dev/mtd2 MLO >/dev/null 2>&1

        echo "flash spl partition 4 of 4"
        flash_eraseall /dev/mtd3 >/dev/null 2>&1
        nandwrite -p /dev/mtd3 MLO >/dev/null 2>&1
    fi

    if [ -e u-boot.img ]; then
        echo "flash u-boot bootloader"
        flash_eraseall /dev/mtd4 >/dev/null 2>&1
        nandwrite -p /dev/mtd4 u-boot.img >/dev/null 2>&1
        flash_eraseall /dev/mtd5 >/dev/null 2>&1
    fi

    if [ -e bootenv.bin ]; then
        echo "flash bootenv"
        flash_eraseall /dev/mtd5 >/dev/null 2>&1
        nandwrite -p /dev/mtd5 bootenv.bin >/dev/null 2>&1
    fi

    if [ -e bootenv.bin ]; then
        echo "flash device tree"
        flash_eraseall /dev/mtd6 >/dev/null 2>&1
        nandwrite -p /dev/mtd6 am335x-boneblack-blackmainer.dtb >/dev/null 2>&1
    fi

    if [ -e bootenv.bin ]; then
        echo "flash kernel"
        flash_eraseall /dev/mtd7 >/dev/null 2>&1
        nandwrite -p /dev/mtd7 uImage.bin >/dev/null 2>&1
    fi

    if [ -e bootenv.bin ]; then
        echo "flash filesystem"
        flash_eraseall /dev/mtd8 >/dev/null 2>&1
        nandwrite -p /dev/mtd8 initramfs.bin.SD >/dev/null 2>&1
    fi

    if [ -e bootenv.bin ]; then
        echo "flash config"
        flash_eraseall /dev/mtd9 >/dev/null 2>&1
        nandwrite -p /dev/mtd9 config.ext4 >/dev/null 2>&1
    fi

    if [ -e bootenv.bin ]; then
        echo "flash fpga"
        flash_eraseall /dev/mtd10 >/dev/null 2>&1
        nandwrite -p /dev/mtd10 fpga.ext4 >/dev/null 2>&1
    fi
else
    echo "** DETECTED: eMMC ***"
    
    # Ensure eMMC is unmounted before flashing
    umount /dev/mmcblk0p* >/dev/null 2>&1
    
    # Partition eMMC
    echo "Partitioning eMMC ..."
    echo -e "o\nn\np\n1\n2048\n+128M\nt\n1\nc\nn\np\n2\n+16M\nn\np\n3\n\nw" | fdisk /dev/mmcblk0
    partprobe /dev/mmcblk0
    
    # Format partitions
    mkfs.vfat -F 32 /dev/mmcblk0p1
    mkfs.ext4 /dev/mmcblk0p2
    mkfs.ext4 /dev/mmcblk0p3
    
    # Flash bootloader (MLO and u-boot)
    echo "Flashing MLO ..."
    dd if=MLO of=/dev/mmcblk0 bs=512 seek=1 conv=fsync
    
    echo "Flashing U-Boot ..."
    dd if=u-boot.img of=/dev/mmcblk0 bs=512 seek=256 conv=fsync
    
    # Mount FAT partition and copy boot files
    echo "Copying boot files to FAT partition ..."
    mount /dev/mmcblk0p1 /mnt
    cp initramfs.bin.SD /mnt/
    cp uImage.bin /mnt/
    cp bootenv.bin /mnt/
    cp am335x-boneblack-blackmainer.dtb /mnt/
    sync
    umount /mnt
    
    # Flash config and FPGA bitstream to ext4 partitions
    echo "Flashing config partition ..."
    dd if=config.ext4 of=/dev/mmcblk0p2 bs=1M conv=fsync
    
    echo "Flashing FPGA bitstream ..."
    dd if=fpga.ext4 of=/dev/mmcblk0p3 bs=1M conv=fsync
    
    sync
fi

echo "FLASHING COMPLETE!!!"
