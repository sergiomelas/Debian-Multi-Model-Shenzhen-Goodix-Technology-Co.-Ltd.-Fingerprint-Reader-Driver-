#!/bin/bash
# SML Master Builder - Goodix Fingerprint Suite
# Version 3.4 - Restored Clear Question Text + Lockfile Fix
# Developed by Sergio Melas - 2026
set -e

# Identity Configuration
export DEBFULLNAME="Sergio Melas"
export DEBEMAIL="sergiomelas@gmail.com"
MAINTAINER="${DEBFULLNAME} <${DEBEMAIL}>"

echo "##################################################################"
echo "#          Building Multi-Model Goodix Debian Package            #"
echo "##################################################################"

# 1. Setup Variables
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="${DIR}/package_build_root"
VERSION="1:99.custom"
DEB_NAME="libfprint-2-2-Goodix-custom_99_$(dpkg --print-architecture).deb"

LIB_ZIP="${DIR}/libfprint.zip"
FLASH_ZIP="${DIR}/goodix-fp-dump.zip"
TEMP_SRC_LIB="${DIR}/libfprint_extracted"
TEMP_SRC_FLASH="${DIR}/goodix_flash_extracted"

cd "${DIR}"

# 2. Preparation & Extraction
sudo apt update && sudo apt install -y build-essential dpkg-dev usbutils unzip meson ninja-build doctest-dev
sudo rm -rf "$TEMP_SRC_LIB" "$TEMP_SRC_FLASH" "$PKG_ROOT"
mkdir -p "$TEMP_SRC_LIB" "$TEMP_SRC_FLASH"

unzip -q "$LIB_ZIP" -d "$TEMP_SRC_LIB"
unzip -q "$FLASH_ZIP" -d "$TEMP_SRC_FLASH"

# 3. Dynamic Meson Compilation
MESON_PATH=$(find "$TEMP_SRC_LIB" -name "meson.build" -exec grep -l "project(" {} + | head -n 1 | xargs dirname)
cd "$MESON_PATH"
rm -rf builddir

# Smart Option Checker to prevent "Unknown option" errors dynamically
OPT="-Dintrospection=false"
if [ -f "meson_options.txt" ]; then
    if grep -q "option('tests'" meson_options.txt; then OPT="$OPT -Dtests=false"; fi
    if grep -q "option('docs'" meson_options.txt; then OPT="$OPT -Ddocs=false";
    elif grep -q "option('gtk_doc'" meson_options.txt; then OPT="$OPT -Dgtk_doc=false"; fi
fi


# Clear any lingering configured states before running setup
rm -rf builddir
# Fix internal sigfm module forced doctest linkage failures on Debian
SIGFM_MESON=$(find . -path "*/sigfm/meson.build" | head -n 1)
if [ -n "$SIGFM_MESON" ] && [ -f "$SIGFM_MESON" ]; then
    # Neutralize the forced doctest library dependency assignment block
    sed -i "s/dependency('doctest')/dependency('', required: false)/g" "$SIGFM_MESON"
    sed -i "s/cc.find_library('doctest')/dependency('', required: false)/g" "$SIGFM_MESON"
    # Prevent building the sigfm-tests target binary
    sed -i "/executable('sigfm-tests'/,/^)/d" "$SIGFM_MESON"
fi

meson setup builddir --prefix=/usr $OPT

DESTDIR="${PKG_ROOT}" ninja -C builddir install
cd "${DIR}"

# 4. Integrate Flash Scripts
mkdir -p "${PKG_ROOT}/usr/share/goodix-flash"
FLASH_SRC_PATH=$(find "$TEMP_SRC_FLASH" -name "run_*.py" -printf '%h\n' | head -n 1)
cp -r "$FLASH_SRC_PATH"/* "${PKG_ROOT}/usr/share/goodix-flash/"
mkdir -p "${PKG_ROOT}/DEBIAN"

# 5. Dependency Detection
LIB_FILE=$(find "${PKG_ROOT}/usr/lib" -name "libfprint-2.so.2*" -type f | head -n 1)
SHLIBS=$(dpkg-shlibdeps -O "$LIB_FILE" 2>/dev/null | grep "^shlibs:Depends=" | sed 's/^shlibs:Depends=//' | sed 's/([^)]*)//g')
SHLIBS=$(echo "$SHLIBS" | sed 's/libgusb2/libgusb2-2/g')
[ -z "$SHLIBS" ] && SHLIBS="libc6, libglib2.0-0t64, libusb-1.0-0, libnss3"

# 6. Metadata
cat <<EOF > "${PKG_ROOT}/DEBIAN/control"
Package: libfprint-2-2
Version: ${VERSION}
Section: libs
Priority: optional
Architecture: $(dpkg --print-architecture)
Maintainer: ${MAINTAINER}
Depends: ${SHLIBS}, python3-crcmod, python3-usb, debconf (>= 0.5), usbutils
Provides: libfprint-2-2
Replaces: libfprint-2-2
Description: Custom Goodix driver - V3.4 Final Release.
EOF

# 7. Templates (Restored Clearer Wording)
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

# 8. CONFIG (Lockfile Protected)
cat <<'EOF' > "${PKG_ROOT}/DEBIAN/config"
#!/bin/sh
set -e
. /usr/share/debconf/confmodule

LOCKFILE="/tmp/goodix_install.lock"

if [ ! -f "$LOCKFILE" ]; then
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
        touch "$LOCKFILE"
    fi
fi
EOF

# 9. POSTINST (Silent Execution + PAM + Lock Cleanup)
cat <<'EOF' > "${PKG_ROOT}/DEBIAN/postinst"
#!/bin/bash
set -e
. /usr/share/debconf/confmodule

db_get libfprint-2-2/flash_confirm
if [ "$RET" = "true" ]; then
    HW_ID=$(lsusb -d 27c6: | awk '{print $6}' | cut -d: -f2)
    case "$HW_ID" in
        5110) S="run_5110.py";; 5117) S="run_5117.py";; 5120) S="run_5120_spi.py";;
        521d) S="run_521d.py";; 532d) S="run_532d.py";; 5385) S="run_5385.py";;
        538d) S="run_538d.py";; 5395) S="run_5395.py";; 5503) S="run_5503.py";;
        55a4) S="run_55a4.py";; 55b4) S="run_55b4.py";; *) S="";;
    esac
    if [ -n "$S" ]; then
        clear > /dev/tty
        echo "!!! STARTING FLASH FOR 27c6:$HW_ID !!!" > /dev/tty
        cd /usr/share/goodix-flash/
        /usr/bin/python3 "$S" < /dev/tty > /dev/tty 2>&1
    fi
fi

rm -f "/tmp/goodix_install.lock"

[ -x /usr/sbin/pam-auth-update ] && pam-auth-update --disable fprintd > /dev/null 2>&1
PAM_FILES=("/etc/pam.d/sudo" "/etc/pam.d/kde" "/etc/pam.d/sddm-helper" "/etc/pam.d/gdm-password")
for F in "${PAM_FILES[@]}"; do
    if [ -f "$F" ]; then
        sed -i '/pam_fprintd.so/d' "$F"
        sed -i '1i auth sufficient pam_fprintd.so' "$F"
    fi
done
ldconfig && systemctl restart fprintd || true
exit 0
EOF

# 10. Assembly & Final Cleanup
chmod +x "${PKG_ROOT}/DEBIAN/config" "${PKG_ROOT}/DEBIAN/postinst"
sudo chown -R root:root "${PKG_ROOT}"
dpkg-deb --build "${PKG_ROOT}" "${DEB_NAME}"

echo "Cleaning up build artifacts..."
sudo rm -rf "${PKG_ROOT}" "$TEMP_SRC_LIB" "$TEMP_SRC_FLASH"
echo "DONE: ${DEB_NAME} created. Question text restored & Lockfile active."
