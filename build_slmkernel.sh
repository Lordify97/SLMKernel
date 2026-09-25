#!/bin/bash
set -e

export TC="/home/$USER/Android/ToolChain/ZyClang-14/"

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

export KCFLAGS=-w
export CONFIG_SECTION_MISMATCH_WARN_ONLY=y

KERNEL_DIR="$(pwd)"
OUT_DIR="$KERNEL_DIR/out"
CFG_DIR="$KERNEL_DIR/arch/arm64/configs"

echo "=============================================="
echo "SLM KERNEL BUILD"
echo "=============================================="
echo "ARCH: $ARCH"
echo "SUBARCH: $SUBARCH"
echo "Kernel: $KERNEL_DIR"
echo "Output: $OUT_DIR"
echo "=============================================="

# Validate source configuration files
for config in \
    "$CFG_DIR/mt6768_slm_defconfig" \
    "$CFG_DIR/a32.config" \
    "$CFG_DIR/battery.config"\
    "$CFG_DIR/ksu.config"; do

    if [ ! -f "$config" ]; then
        echo "ERROR: Missing config: $config"
        exit 1
    fi
done

# Fix legacy 4.14 Kconfig compatibility
if grep -q 'source "scripts/Kconfig.include"' "$KERNEL_DIR/Kconfig"; then
    cp "$KERNEL_DIR/Kconfig" "$KERNEL_DIR/Kconfig.backup"
    sed -i '/source "scripts\/Kconfig.include"/d' "$KERNEL_DIR/Kconfig"
fi

# Normalize Sensorhub Kconfig files
find "$KERNEL_DIR/drivers/sensorhub" \
    -type f -name 'Kconfig*' \
    -exec sed -i 's/\r//g' {} +

# Build a combined defconfig
rm -f "$CFG_DIR/compiled_defconfig"

cat \
    "$CFG_DIR/mt6768_slm_defconfig" \
    "$CFG_DIR/a32.config" \
    "$CFG_DIR/battery.config" \
    "$CFG_DIR/ksu.config" \
    > "$CFG_DIR/compiled_defconfig"

if [ ! -s "$CFG_DIR/compiled_defconfig" ]; then
    echo "ERROR: compiled_defconfig is empty"
    exit 1
fi

echo "Generated defconfig:"
wc -l "$CFG_DIR/compiled_defconfig"

# Generate the kernel configuration
make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH=arm64 \
    SUBARCH=arm64 \
    KCFLAGS=-w \
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
    compiled_defconfig

# Verify generated .config
if [ ! -s "$OUT_DIR/.config" ]; then
    echo "ERROR: out/.config was not generated"
    exit 1
fi

echo "Kernel configuration generated successfully"

# Build kernel
make -C "$KERNEL_DIR" \
    O="$OUT_DIR" \
    ARCH=arm64 \
    SUBARCH=arm64 \
    KCFLAGS=-w \
    CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
    -j16

# Copy Image
if [ ! -f "$OUT_DIR/arch/arm64/boot/Image" ]; then
    echo "ERROR: Image was not generated"
    exit 1
fi

mkdir -p "$KERNEL_DIR/arch/arm64/boot"

cp "$OUT_DIR/arch/arm64/boot/Image" \
   "$KERNEL_DIR/arch/arm64/boot/Image"

echo "=============================================="
echo "BUILD COMPLETED SUCCESSFULLY"
echo "=============================================="

