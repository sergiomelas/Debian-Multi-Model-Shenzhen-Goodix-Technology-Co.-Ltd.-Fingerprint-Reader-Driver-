##################################################################
#         Install Multi-Model Shenzhen Goodix Driver             #
#                   Sergio Melas 2026                            #
#         Install Multi-Model Shenzhen Goodix Driver             #
##################################################################

This work is based on the following repositoryes:
github.com/TheWeirdDev/libfprint
github.com/goodix-fp-linux-dev/goodix-fp-dump

The merith for this goes to the developpers of those repositoryes, i jusd package it for Debian

⚠️ **CRITICAL WARNING: FLASHING DANGER**
The flashing process writes to the sensor's hardware memory.
- **DO NOT** run the flash script if the sensor is already working.
- **DO NOT** run the flash script repeatedly if you encounter errors.
- **DANGER:** Excessive flashing or interrupted power during the process can permanently "brick" the fingerprint hardware.

### 📦 Recommended Installation (Debian Package)
The most secure way to install this driver on **Debian Sid** is using the custom `.deb` package.
This method automatically handles **APT Pinning** (preventing system updates from breaking the driver) and **PAM configuration**.

1. **Build the package:** Run the provided `create_deb.sh` script.
2. **Install the package:**
   sudo apt install ./libfprint-2-2-Goodix-custom_99_$(dpkg --print-architecture).deb
3, **The Flash Interface: During installation, a blue Debconf dialog will appear.
   1-Select if the sensor was previously working.
   2-Select only if this is the first time setting up the sensor on this hardware.To revert to standard Debian:
   sudo apt install libfprint-2-2/unstable
   Description of what this does

Multi-Model Goodix Fingerprint Support (Experimental Summary):
1.Firmware & Key Injection (goodix-fp-dump)
   The Problem: Supported Goodix sensors use a Pre-Shared Key (PSK) and TLS-encrypted protocol.
   Linux cannot communicate with the hardware because it lacks the specific key negotiated during Windows initialization.
   The Solution: The flash scripts (run_XXXX.py) reset the sensor's state and inject a known PSK into volatile memory.
   It uploads a compatible firmware blob allowing the Linux driver to communicate using this key.
   Note: This state is volatile. Booting into Windows or a hard power cycle may reset the sensor, requiring the script to be
   re-run (though the base firmware remains persistent).

2.Experimental Driver (libfprint)
    The Problem: Standard libfprint lacks the logic for the TLS handshake or image decoding for these models.
    The Solution: The 55b4-experimental branch provides the necessary modifications for the TLS handshake using the
    injected PSK and utilizes the SIGFM (Signal Fingerprint Matcher) algorithm for low-resolution data.

⚠️ Usage & Dual-Boot Notes:
Windows Users: It is highly recommended to Disable the Fingerprint device in Windows Device Manager.
This prevents Windows from overwriting the Linux-compatible key and firmware state.
Security: This is reverse-engineered experimental software. It is functional for sudo and KDE lock
screens but is not an official production-grade driver.

Manual Installation Instructions (If Package Fails):
**First try the automated install install_manually.sh in the SRC folder. If it fails, follow the manual steps below.
⚠️ ATTENTION: If you have already flashed the sensor once, DO NOT execute Step 3 again. The hardware flash is persistent;
even if you reinstall Debian, the sensor remembers the firmware. You only need to run Step 1, 2, and 4 after a fresh OS install.
What you will need to do after reinstalling Debian:
While the hardware remains "flashed," your new installation lacks the software to communicate with it.

1. Re-install Driver: You must re-compile the experimental libfprint fork.
2. Restore Udev Rules: The installation process will restore the rules needed for system permissions.
3. Re-enroll Fingerprints: Fingerprint templates are stored on your SSD. You must register your fingers again in the new system.

Step 1: Install Build Dependencies
  Open your terminal and install the tools needed to compile the driver:
  sudo apt update
  sudo apt install -y fprintd meson libgusb-dev libcairo2-dev libgudev-1.0-dev
  libgirepository1.0-dev libnss3-dev libssl-dev gtk-doc-tools git python3-venv usbutils

Step 2: Build the Experimental Driver
  This installs the software required to talk to the Goodix sensor.
  Clone the experimental branch
  git clone github.com/TheWeirdDev/libfprint --branch 55b4-experimental
  cd libfprint/
  Clear old builds and setup (Modern Meson syntax)
  rm -rf builddir
  meson setup builddir -Ddoc=false -Dprefix=/usr
  ninja -C builddir
  sudo ninja -C builddir install
  sudo ldconfig
Step 3: Flash the Sensor Firmware (ONE TIME ONLY)
  STOP: Skip this step if your sensor was working previously. Only run this if the sensor has never been used in Linux before.
  git clone github.com/goodix-fp-linux-dev/goodix-fp-dump --recurse-submodules
  cd goodix-fp-dump/
  Install flash dependencies
  sudo apt install -y python3-crcmod python3-usb libusb-1.0-0

  DETECT YOUR MODEL:
  Run: lsusb -d 27c6:
  Then run the corresponding script for your ID:
  5110 -> sudo python3 run_5110.py
  5117 -> sudo python3 run_5117.py
  5120 -> sudo python3 run_5120_spi.py
  521d -> sudo python3 run_521d.py
  532d -> sudo python3 run_532d.py
  5385 -> sudo python3 run_5385.py
  538d -> sudo python3 run_538d.py
  5395 -> sudo python3 run_5395.py
  5503 -> sudo python3 run_5503.py
  55a4 -> sudo python3 run_55a4.py
  55b4 -> sudo python3 run_55b4.py
  Note: If you encounter a timeout error, use a utility like usbreset to reset the device.
Step 4: Enable Fingerprint Login
  After the driver is installed, enable it in the system:
  1, Install PAM Module:
    sudo apt install -y libpam-fprintd
  2. Configure PAM:
     1.first option still bugging with sddm
       Run the following and ensure "Fingerprint authentication" is selected:
       sudo pam-auth-update --enable fprintd
     2.Second otion, mantain figerprint only for sudo and unlock screen
       Run the following and ensure "Fingerprint authentication" is selected:
       sudo pam-auth-update --disable fprintd
       create /etc/pam.d/kde with the content:

       #%PAM-1.0
       auth sufficient pam_fprintd.so
       auth include common-auth
       account include common-account
       password include common-password
       session include common-sessionedit

       /etc/pam.d/sudo add at the beginning:
       auth sufficient pam_fprintd.so

   3. Restart Service:
      sudo systemctl restart fprintd

   4. Enroll Your Finger:
      Go to Settings > Users in GNOME/KDE, or use the terminal:
      fprintd-enroll

Step 5: Lock libfprint so in not system updated
  Create a preference file:
  /etc/apt/preferences.d/libfprint-hold

  Add the following configuration to block updates:

  Package: libfprint-2-2
  Pin: release *
  Pin-Priority: 1001
  Package: fprintd
  Pin: release *
  Pin-Priority: 1001

Done

##################################################################################################################
Change log:
-V1.0 25-01-2026: Initial version pubblic version
-V1.1 29-01-2026: Updated for Multi-Model support (11 models)


