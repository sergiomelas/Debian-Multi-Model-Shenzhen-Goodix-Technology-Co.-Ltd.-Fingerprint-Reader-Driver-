#!/bin/bash
# Install 27c6:Multi-Model Shenzhen Goodix Driver with Debian Sid Protection
# Target: Sudo & KDE Lock Screen Only (Login excluded)

echo "##################################################################"
echo "#         Install Multi-Model Shenzhen Goodix Driver             #"
echo "#                   Sergio Melas 2026                            #"
echo "#         Supporting 11 Models (5110 to 55b4)                    #"
echo "##################################################################"

# 1. Setup & Dependencies
DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
cd "${DIR}"
sudo -v

echo "Installing dependencies..."
sudo apt update
sudo apt install -y \
    git python3-crcmod python3-usb libusb-1.0-0 fprintd meson \
    libgusb-dev libcairo2-dev libgudev-1.0-dev libgirepository1.0-dev \
    libnss3-dev libssl-dev gtk-doc-tools python3-venv libglib2.0-dev-bin \
    libpam-fprintd usbutils

# 2. Check and Download Missing Repositories
echo "******************************************************************"
echo "NOTE: Downloading repositories if missing..."
echo "If the sensor is already working, DO NOT run the python flash script."
echo "If you ever need to update them, uncomment the line in the script."
echo "******************************************************************"

if [ ! -d "./libfprint/" ]; then
    echo "libfprint directory missing. Downloading experimental driver..."
    # Using the branch with multi-model support
    git clone https://github.com/TheWeirdDev/libfprint --branch 55b4-experimental
fi

if [ ! -d "./goodix-fp-dump/" ]; then
    echo "goodix-fp-dump directory missing. Downloading flash tools..."
    git clone https://github.com/goodix-fp-linux-dev/goodix-fp-dump --recurse-submodules
fi

# 3. Build and Install libfprint (Clean Reinstall)
if [ -d "./libfprint/" ]; then
    echo "Building libfprint from source..."
    cd ./libfprint/
    rm -rf builddir
    # Prefix /usr ensures it overwrites the system library to prevent Sid conflicts
    meson setup builddir --prefix=/usr
    sudo ninja -C builddir install
    sudo ldconfig
    cd ..
else
    echo "Error: Failed to find or download ./libfprint/ directory!"
    exit 1
fi

# 4. APT Version Locking (Protection from Debian Sid Updates)
echo "Locking libfprint version at high priority..."
sudo tee /etc/apt/preferences.d/libfprint-hold <<EOF
Package: libfprint-2-2
Pin: release *
Pin-Priority: 1001

Package: fprintd
Pin: release *
Pin-Priority: 1001
EOF

# 5. PAM Configuration (Specific to Sudo and KDE Lock Screen Only)
echo "Updating PAM configuration..."

# Disable global profile to ensure fingerprint is NOT used for initial login
sudo pam-auth-update --disable fprintd

# Manually enable for sudo and kde lock screen
PAM_FILES=("/etc/pam.d/sudo" "/etc/pam.d/kde")

for FILE in "${PAM_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "Configuring $FILE..."
        # Remove any existing pam_fprintd lines to avoid duplicates
        sudo sed -i '/pam_fprintd.so/d' "$FILE"

        # Insert 'auth sufficient pam_fprintd.so' at the top
        if grep -q "#%PAM-1.0" "$FILE"; then
            sudo sed -i '/#%PAM-1.0/a auth sufficient pam_fprintd.so' "$FILE"
        else
            sudo sed -i '1i auth sufficient pam_fprintd.so' "$FILE"
        fi
    fi
done

# 6. Sensor Persistence Reminder & Multi-Model Detection
echo "******************************************************************"
echo "NOTE: Flashing is PERSISTENT on the hardware."
echo "If the sensor is already working, DO NOT run the python flash script."

# Logic for dynamic model detection
HW_ID=$(lsusb -d 27c6: | awk '{print $6}' | cut -d: -f2)
case "$HW_ID" in
    5110) S="run_5110.py";; 5117) S="run_5117.py";; 5120) S="run_5120_spi.py";;
    521d) S="run_521d.py";; 532d) S="run_532d.py";; 5385) S="run_5385.py";;
    538d) S="run_538d.py";; 5395) S="run_5395.py";; 5503) S="run_5503.py";;
    55a4) S="run_55a4.py";; 55b4) S="run_55b4.py";; *) S="unknown";;
esac

if [ "$S" != "unknown" ]; then
    echo "Detected Model: 27c6:$HW_ID -> Recommended Script: $S"
    echo "If you ever need it, uncomment the lines in Section 6 of this script."
    # if [ -d "./goodix-fp-dump/" ]; then
    #     cd ./goodix-fp-dump/
    #     sudo python3 "$S"
    #     cd ..
    # fi
else
    echo "No compatible Goodix sensor detected for flashing."
fi
echo "******************************************************************"

# 7. Finalize Services (Single Restart)
echo "Restarting fprintd service..."
sudo systemctl restart fprintd

echo "Done! Check your protection status with: apt-cache policy libfprint-2-2"
