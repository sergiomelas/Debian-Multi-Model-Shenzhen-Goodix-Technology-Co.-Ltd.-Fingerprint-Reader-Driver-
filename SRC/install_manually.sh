#!/bin/bash
# Universal Goodix Driver Installer - Distro Agnostic
# Version 1.0 - Sergio Melas 2026
set -e

echo "##################################################################"
echo "#          Universal Multi-Model Goodix Driver Installer         #"
echo "#        (Requires manual dependency installation first)         #"
echo "##################################################################"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_SRC_LIB="${DIR}/libfprint_extracted"
TEMP_SRC_FLASH="${DIR}/goodix_flash_extracted"
LIB_ZIP="${DIR}/libfprint.zip"
FLASH_ZIP="${DIR}/goodix-fp-dump.zip"

# 1. Extraction
echo "Extracting local source archives..."
rm -rf "$TEMP_SRC_LIB" "$TEMP_SRC_FLASH"
mkdir -p "$TEMP_SRC_LIB" "$TEMP_SRC_FLASH"
unzip -q "$LIB_ZIP" -d "$TEMP_SRC_LIB"
unzip -q "$FLASH_ZIP" -d "$TEMP_SRC_FLASH"

# 2. Compile libfprint
# Finds the root folder inside the zip where meson.build exists
MESON_PATH=$(find "$TEMP_SRC_LIB" -name "meson.build" -exec grep -l "project(" {} + | head -n 1 | xargs dirname)

echo "Building libfprint in $MESON_PATH..."
cd "$MESON_PATH"
rm -rf builddir

# Smart Option Checker to prevent errors
OPT="-Dintrospection=false"
if [ -f "meson_options.txt" ]; then
    if grep -q "option('docs'" meson_options.txt; then OPT="$OPT -Ddocs=false";
    elif grep -q "option('gtk_doc'" meson_options.txt; then OPT="$OPT -Dgtk_doc=false"; fi
fi

# We use /usr/local for agnostic installs
meson setup builddir --prefix=/usr/local $OPT
sudo ninja -C builddir install
sudo ldconfig
cd "${DIR}"

# 3. Flash Scripts Integration
echo "Installing flash scripts to /usr/local/share/goodix-flash..."
sudo mkdir -p "/usr/local/share/goodix-flash"
FLASH_SRC_PATH=$(find "$TEMP_SRC_FLASH" -name "run_*.py" -printf '%h\n' | head -n 1)
sudo cp -r "$FLASH_SRC_PATH"/* "/usr/local/share/goodix-flash/"

# 4. Cleanup Source "Crap"
echo "Cleaning up build artifacts..."
sudo rm -rf "$TEMP_SRC_LIB" "$TEMP_SRC_FLASH"

# 5. Instructions for hardware initialization
HW_ID=$(lsusb -d 27c6: | awk '{print $6}' | cut -d: -f2 || echo "unknown")
echo "******************************************************************"
echo "INSTALLATION COMPLETE"
echo "Detected Model ID: 27c6:$HW_ID"
echo "Flash Scripts are located in: /usr/local/share/goodix-flash/"
echo "If you need to flash, run: sudo python3 /usr/local/share/goodix-flash/run_your_id.py"
echo "******************************************************************"
