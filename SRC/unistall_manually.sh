#!/bin/bash
# Universal Goodix Driver Uninstaller
set -e

echo "Removing Multi-Model Goodix Driver files..."

# Remove binaries and headers
sudo rm -rf /usr/local/lib/libfprint-2*
sudo rm -rf /usr/local/include/libfprint-2
sudo rm -rf /usr/local/lib/pkgconfig/libfprint-2.pc

# Remove flash scripts
sudo rm -rf /usr/local/share/goodix-flash

sudo ldconfig
echo "Uninstallation complete. Note: PAM changes must be reverted manually."
