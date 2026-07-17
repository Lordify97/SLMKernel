#!/bin/bash

export TC=/home/$USER/Android/ToolChain/ZyClang-14/

export CROSS_COMPILE=$TC/bin/aarch64-linux-gnu-
export LD=$TC/bin/ld.lld
export OBJCOPY=$TC/bin/llvm-objcopy
export AS=$TC/bin/llvm-as
export NM=$TC/bin/llvm-nm
export STRIP=$TC/bin/llvm-strip
export OBJDUMP=$TC/bin/llvm-objdump
export READELF=$TC/bin/llvm-readelf
export CC=$TC/bin/clang
export ARCH=arm64

export KCFLAGS=' -w -pipe -O3'
export KCPPFLAGS=' -O3'
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y

#setup configs directory
export CFGDIR=arch/arm64/configs

rm -rf $CFGDIR/compiled_defconfig
make -C $(pwd) O=$(pwd)/out clean -j$(nproc) && make -C $(pwd) O=$(pwd)/out mrproper -j$(nproc)
clear

read -p "`echo -e 'thanks for building slmkernel \ntell what device you wanna build for 💩💩 \nsupported devices: a32, a22, f22, m22(experimental), m32(experimental)  '`" choice
case "$choice" in 
  a32|A32 ) export DEVICE="a32";;
  a22|A22 ) export DEVICE="a22";;
  f22|F22 ) export DEVICE="f22";;
  m22|M22 ) export DEVICE="m22";;
  m32|M32 ) export DEVICE="m32";;
  * ) echo "u made a typo or $choice not supported yet srry 💩" && exit;;
esac

#edit perf.config to battery.config to disable perf tweaks, dont use them at the same time!
#add $CFGDIR/ksu.config at the end before ">" for ksu integration(optional)
#example: build m22 battery life oriented karnal with ksu: $CFGDIR/mt6768_slm_defconfig $CFGDIR/"$DEVICE".config $CFGDIR/battery.config $CFGDIR/ksu.config
cat $CFGDIR/mt6768_slm_defconfig $CFGDIR/"$DEVICE".config $CFGDIR/battery.config $CFGDIR/ksu.config > $CFGDIR/compiled_defconfig

#selinux and gpu driver control
#buildable: mali bifrost r25p0, mali valhall r32p1, mali avalon r49p1[WIP]
echo '
CONFIG_ALWAYS_ENFORCE=y
# CONFIG_ALWAYS_PERMISSIVE is not set

CONFIG_MTK_GPU_VERSION="mali bifrost r25p0"
' >> "$CFGDIR/compiled_defconfig"

make -C $(pwd) O=$(pwd)/out -j$(nproc) compiled_defconfig
make -s -C $(pwd) O=$(pwd)/out -j$(nproc)

IMAGECHECK="$(pwd)/out/arch/arm64/boot/Image"

if [ -f "$IMAGECHECK" ]; then
    echo "built slm for device: $DEVICE"
    GPU_VER=$(sed -n 's/^CONFIG_MTK_GPU_VERSION="\([^"]*\)"/\1/p' \
        "$(pwd)/out/.config")

    if [ "$GPU_VER" != "mali bifrost r25p0" ]; then
        echo
        echo "================================================================"
        echo "warning: non-stock gpu driver selected"
        echo
        echo "built gpu driver : $GPU_VER"
        echo
        echo "Flash a custom vendor.img that has the corresponding Mali userspace libs,"
        echo "Flash a custom boot.img that has a modified DTS with the new driver support,"
        echo "or your device may bootloop"
        echo "================================================================"
        echo
    fi

echo "Build for $DEVICE done!"
