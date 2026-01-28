#!/bin/bash
# Professional Builder for libfprint-2-2 (Debian Sid)
# Dynamically detects exact library names to solve "not installable" errors.

echo "##################################################################"
echo "#         Building libfprint 27c6:55b4 Debian Package            #"
echo "##################################################################"



# 1. Setup
DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
PKG_ROOT="${DIR}/package_build_root"
VERSION="1:99.custom"
DEB_NAME="libfprint-2-2-27c6:55b4_Goodix_Fingerprint_Reader-custom_99_$(dpkg --print-architecture).deb"

cd "${DIR}"

# 2. Build Minimal Dependencies
sudo apt update && sudo apt install -y build-essential dpkg-dev

# 3. Compile libfprint
echo "Compiling..."
[ -d "./libfprint/" ] || git clone https://github.com --branch 55b4-experimental
cd ./libfprint/
rm -rf builddir && rm -rf "${PKG_ROOT}"
meson setup builddir --prefix=/usr
DESTDIR="${PKG_ROOT}" ninja -C builddir install
cd ..

# 4. Bundle Flashing Tools
mkdir -p "${PKG_ROOT}/usr/share/goodix-flash"
[ -d "./goodix-fp-dump/" ] || git clone https://github.com --recurse-submodules
cp -r ./goodix-fp-dump/* "${PKG_ROOT}/usr/share/goodix-flash/"

# 5. DYNAMIC DEPENDENCY DETECTION
echo "Detecting exact system library names..."
mkdir -p "${PKG_ROOT}/DEBIAN"

# Find the compiled library file
LIB_FILE=$(find "${PKG_ROOT}/usr/lib" -name "libfprint-2.so.2*" -type f | head -n 1)

# Detect dependencies and clean the output (removes warnings/garbage)
SHLIBS=$(dpkg-shlibdeps -O "$LIB_FILE" 2>/dev/null | grep "^shlibs:Depends=" | sed 's/^shlibs:Depends=//')

# Fallback just in case detection is empty
if [ -z "$SHLIBS" ]; then
    SHLIBS="libc6, libglib2.0-0t64, libusb-1.0-0, libnss3"
fi

# 6. Create Metadata (Masquerading as the official package name)
cat <<EOF > "${PKG_ROOT}/DEBIAN/control"
Package: libfprint-2-2
Version: ${VERSION}
Section: libs
Priority: optional
Architecture: $(dpkg --print-architecture)
Maintainer: $(whoami)
Depends: ${SHLIBS}, python3-crcmod, python3-usb, debconf (>= 0.5)
Provides: libfprint-2-2
Replaces: libfprint-2-2
Description: Custom Goodix 27c6:55b4 driver for libfprint.
 Satisfies fprintd dependencies with auto-detected Sid libraries.
EOF

# 7. Create Debconf UI & Logic
cat <<EOF > "${PKG_ROOT}/DEBIAN/templates"
Template: libfprint-2-2/flash_confirm
Type: boolean
Default: false
Description: Run the Goodix sensor flash script?
EOF

cat <<'EOF' > "${PKG_ROOT}/DEBIAN/config"
#!/bin/sh
set -e
. /usr/share/debconf/confmodule
db_input high libfprint-2-2/flash_confirm || true
db_go
EOF

# 8. Create Post-Installation Script
cat <<'EOF' > "${PKG_ROOT}/DEBIAN/postinst"
#!/bin/bash
set -e
. /usr/share/debconf/confmodule

db_get libfprint-2-2/flash_confirm
if [ "$RET" = "true" ]; then
    cd /usr/share/goodix-flash/
    python3 run_55b4.py || true
fi

# PAM Logic
[ -x /usr/sbin/pam-auth-update ] && pam-auth-update --disable fprintd
for FILE in "/etc/pam.d/sudo" "/etc/pam.d/kde"; do
    if [ -f "$FILE" ]; then
        sed -i '/pam_fprintd.so/d' "$FILE"
        sed -i '1i auth sufficient pam_fprintd.so' "$FILE"
    fi
done

ldconfig
systemctl restart fprintd || true
exit 0
EOF

chmod +x "${PKG_ROOT}/DEBIAN/config" "${PKG_ROOT}/DEBIAN/postinst"

# 9. Build and Cleanup
dpkg-deb --build "${PKG_ROOT}" "${DEB_NAME}"
rm -rf "${PKG_ROOT}"

echo "DONE: ${DEB_NAME} created."
