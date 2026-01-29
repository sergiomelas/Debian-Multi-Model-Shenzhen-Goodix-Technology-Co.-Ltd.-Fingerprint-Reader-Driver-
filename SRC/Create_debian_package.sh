#!/bin/bash
# FINAL PC-VERIFIED BUILDER
# Includes: Verbose Build, 11 Models, Big Fat Warning, TTY Fix, and Clean Python Output.

echo "##################################################################"
echo "#         Building Multi-Model Goodix Debian Package             #"
echo "##################################################################"

# 1. Setup
DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
PKG_ROOT="${DIR}/package_build_root"
VERSION="1:99.custom"
DEB_NAME="libfprint-2-2-Goodix-custom_99_$(dpkg --print-architecture).deb"

cd "${DIR}"

# 2. Build Dependencies
sudo apt update && sudo apt install -y build-essential dpkg-dev usbutils

# 3. Source & Compile (VERBOSE OUTPUT)
[ -d "./libfprint/" ] || git clone https://github.com --branch 55b4-experimental
[ -d "./goodix-fp-dump/" ] || git clone https://github.com --recurse-submodules

cd ./libfprint/
rm -rf builddir && rm -rf "${PKG_ROOT}"
meson setup builddir --prefix=/usr
DESTDIR="${PKG_ROOT}" ninja -C builddir install
cd ..

# 4. Bundle all Flash scripts
mkdir -p "${PKG_ROOT}/usr/share/goodix-flash"
cp -r ./goodix-fp-dump/* "${PKG_ROOT}/usr/share/goodix-flash/"

# 5. ROBUST DYNAMIC DEPENDENCY DETECTION (Proven Method)
echo "Detecting exact system library names..."
mkdir -p "${PKG_ROOT}/DEBIAN"
LIB_FILE=$(find "${PKG_ROOT}/usr/lib" -name "libfprint-2.so.2*" -type f | head -n 1)
SHLIBS=$(dpkg-shlibdeps -O "$LIB_FILE" 2>/dev/null | grep "^shlibs:Depends=" | sed 's/^shlibs:Depends=//' | sed 's/([^)]*)//g')
SHLIBS=$(echo "$SHLIBS" | sed 's/libgusb2/libgusb2-2/g')

if [ -z "$SHLIBS" ]; then
    SHLIBS="libc6, libglib2.0-0t64, libusb-1.0-0, libnss3"
fi

# 6. Metadata (PC-Verified Minimal Dependencies)
cat <<EOF > "${PKG_ROOT}/DEBIAN/control"
Package: libfprint-2-2
Version: ${VERSION}
Section: libs
Priority: optional
Architecture: $(dpkg --print-architecture)
Maintainer: $(whoami)
Depends: ${SHLIBS}, python3-crcmod, python3-usb, debconf (>= 0.5), usbutils
Provides: libfprint-2-2
Replaces: libfprint-2-2
Description: Custom Multi-Model Goodix driver for libfprint.
 Fixed: Robust depends, Big Fat Warning, and Clean TTY Output.
EOF

# 7. Debconf Templates (Warning + Model Confirmation)
cat <<EOF > "${PKG_ROOT}/DEBIAN/templates"
Template: libfprint-2-2/flash_warning
Type: note
Description: !!! BIG FAT WARNING: HARDWARE FLASHING !!!
 The installer has detected model: 27c6:\${model_id}
 .
 1. Flashing is PERSISTENT on hardware.
 2. DO NOT flash if the sensor is already working.
 3. Power interruption or wrong model selection can BRICK the sensor.

Template: libfprint-2-2/flash_confirm
Type: boolean
Default: false
Description: ARE YOU SURE you want to flash model \${model_id}?
 Detected ID: 27c6:\${model_id}
 Script: /usr/share/goodix-flash/\${script_name}
 .
 Selecting YES will CLEAR the terminal for the interactive flash tool.
 Plese remember that reflashing is neded only in the sensor stop working
 For example if you boothed in windows. In any other case choose NO
EOF

# 8. Debconf Config Logic (All 11 Models + Force Dialog)
cat <<'EOF' > "${PKG_ROOT}/DEBIAN/config"
#!/bin/sh
set -e
. /usr/share/debconf/confmodule
db_fset libfprint-2-2/flash_confirm seen false
HW_ID=$(lsusb -d 27c6: | awk '{print $6}' | cut -d: -f2)
case "$HW_ID" in
    5110) S="run_5110.py";; 5117) S="run_5117.py";; 5120) S="run_5120_spi.py";;
    521d) S="run_521d.py";; 532d) S="run_532d.py";; 5385) S="run_5385.py";;
    538d) S="run_538d.py";; 5395) S="run_5395.py";; 5503) S="run_5503.py";;
    55a4) S="run_55a4.py";; 55b4) S="run_55b4.py";; *) S="unknown";;
esac
if [ "$S" != "unknown" ]; then
    db_subst libfprint-2-2/flash_warning model_id "$HW_ID"
    db_subst libfprint-2-2/flash_confirm model_id "$HW_ID"
    db_subst libfprint-2-2/flash_confirm script_name "$S"
    db_input critical libfprint-2-2/flash_warning || true
    db_go
    db_input high libfprint-2-2/flash_confirm || true
    db_go
fi
EOF

# 9. Hardware Detection (preinst)
cat <<'EOF' > "${PKG_ROOT}/DEBIAN/preinst"
#!/bin/bash
set -e
HW_ID=$(lsusb -d 27c6: | awk '{print $6}' | cut -d: -f2)
case "$HW_ID" in
    5110|5117|5120|521d|532d|5385|538d|5395|5503|55a4|55b4) exit 0 ;;
    *) echo "ERROR: No supported Goodix sensor found." ; exit 1 ;;
esac
EOF

# 10. Post-Installation (Interactive, Clean TTY, and PAM)
cat <<'EOF' > "${PKG_ROOT}/DEBIAN/postinst"
#!/bin/bash
set -e
. /usr/share/debconf/confmodule
HW_ID=$(lsusb -d 27c6: | awk '{print $6}' | cut -d: -f2)
case "$HW_ID" in
    5110) S="run_5110.py";; 5117) S="run_5117.py";; 5120) S="run_5120_spi.py";;
    521d) S="run_521d.py";; 532d) S="run_532d.py";; 5385) S="run_5385.py";;
    538d) S="run_538d.py";; 5395) S="run_5395.py";; 5503) S="run_5503.py";;
    55a4) S="run_55a4.py";; 55b4) S="run_55b4.py";; *) S="";;
esac

db_get libfprint-2-2/flash_confirm
if [ "$RET" = "true" ] && [ -n "$S" ]; then
    clear > /dev/tty
    echo "!!! STARTING INTERACTIVE FLASH FOR 27c6:$HW_ID !!!" > /dev/tty
    cd /usr/share/goodix-flash/
    /usr/bin/python3 "$S" < /dev/tty > /dev/tty 2>&1
fi

[ -x /usr/sbin/pam-auth-update ] && pam-auth-update --disable fprintd > /dev/null 2>&1
PAM_FILES=("/etc/pam.d/sudo" "/etc/pam.d/kde" "/etc/pam.d/sddm-helper" "/etc/pam.d/gdm-password" "/etc/pam.d/gdm-fingerprint")
for F in "${PAM_FILES[@]}"; do
    if [ -f "$F" ]; then
        sed -i '/pam_fprintd.so/d' "$F"
        sed -i '1i auth sufficient pam_fprintd.so' "$F"
    fi
done
ldconfig && systemctl restart fprintd || true
exit 0
EOF

chmod +x "${PKG_ROOT}/DEBIAN/config" "${PKG_ROOT}/DEBIAN/preinst" "${PKG_ROOT}/DEBIAN/postinst"
dpkg-deb --build "${PKG_ROOT}" "${DEB_NAME}"
rm -rf "${PKG_ROOT}"
echo "DONE: ${DEB_NAME} created successfully."
