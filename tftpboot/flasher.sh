SERVER_IP=192.168.100.1
echo "Checking MTD"
cat /proc/mtd

echo "Downloading necessary tools ..."
wget http://$SERVER_IP/nandwrite

echo "Detecting whether eMMC or NAND ..."

if [ -e /dev/mtd8 ]; then
    echo "** DETECTED: NAND ***"

    echo "Flashing MLO..."
    wget http://$SERVER_IP/MLO -O MLO && \
    ./flash_eraseall /dev/mtd0 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd0 MLO >/dev/null 2>&1 && \
    ./flash_eraseall /dev/mtd1 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd1 MLO >/dev/null 2>&1
    ./flash_eraseall /dev/mtd2 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd2 MLO >/dev/null 2>&1
    ./flash_eraseall /dev/mtd3 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd3 MLO >/dev/null 2>&1
    rm MLO

    echo "Flashing u-boot..."
    wget http://$SERVER_IP/u-boot.img -O u-boot.img && \
    ./flash_eraseall /dev/mtd4 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd4 u-boot.img >/dev/null 2>&1 && rm u-boot.img

    echo "Flashing bootenv..."
    wget http://$SERVER_IP/bootenv.bin -O bootenv.bin && \
    ./flash_eraseall /dev/mtd5 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd5 bootenv.bin >/dev/null 2>&1 && rm bootenv.bin

    echo "Flashing device tree..."
    wget http://$SERVER_IP/am335x-boneblack-blackmainer.dtb -O dtb && \
    ./flash_eraseall /dev/mtd6 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd6 dtb >/dev/null 2>&1 && rm dtb

    echo "Flashing kernel..."
    wget http://$SERVER_IP/uImage.bin -O kernel && \
    ./flash_eraseall /dev/mtd7 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd7 kernel >/dev/null 2>&1 && rm kernel

    echo "Flashing initramfs..."
    wget http://$SERVER_IP/initramfs.bin.SD -O initramfs && \
    ./flash_eraseall /dev/mtd8 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd8 initramfs >/dev/null 2>&1 && rm initramfs

    echo "Flashing config..."
    wget http://$SERVER_IP/config.ext4 -O config && \
    ./flash_eraseall /dev/mtd9 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd9 config >/dev/null 2>&1 && rm config

    echo "Flashing FPGA..."
    wget http://$SERVER_IP/fpga.ext4 -O fpga && \
    ./flash_eraseall /dev/mtd10 >/dev/null 2>&1 && \
    ./nandwrite -p /dev/mtd10 fpga >/dev/null 2>&1 && rm fpga

else
    echo "** NAND NOT PRESENT !!!"
fi
