##################################################################
#                                                                #
#          Install Multi-Model Shenzhen Goodix Driver            #
#                      Sergio Melas 2026                         #
#                                                                #
##################################################################

This work is based on the following repositories:
- github.com/TheWeirdDev/libfprint (Experimental Driver)
- github.com/goodix-fp-linux-dev/goodix-fp-dump (Flash Tools)

Credit goes to the original developers; I have standardized this as a
professional implementation with automated build logic for modern Linux
environments.

⚠️ CRITICAL WARNING: FLASHING DANGER
The flashing process writes directly to the sensor's hardware memory.
- DO NOT run the flash if the sensor is already working.
- DO NOT run the flash repeatedly if you encounter errors.
- DANGER: Power interruption during flashing can permanently "brick"
  the fingerprint hardware.

---

### 📦 Option 1: Debian/Ubuntu Installation (Recommended)
The most secure way to install this driver on Debian Sid or Ubuntu is using
the custom .deb package. This method handles APT Pinning and PAM
configuration automatically.

1. Build the package:
   Ensure 'libfprint.zip' and 'goodix-fp-dump.zip' are in the source folder.
   Run 'bash Create_debian_package.sh'. All build artifacts are
   automatically wiped after completion to keep your workspace clean.

2. Install the package:
   sudo apt install ./libfprint-2-2-Goodix-custom_99_amd64.deb

3. The Flash Interface:
   During installation, a blue Debconf dialog will appear.
   - Select NO: If the sensor was previously working (installs drivers only).
   - Select YES: Only if this is the first time setting up the sensor
     on this hardware or if the state was reset by Windows.
   *Note: This version includes a safety lock to prevent accidental
   double-prompts.*

---

### 🛠 Option 2: Universal/Agnostic Installation
Use this method for non-Debian distributions (Arch, Fedora, etc.) or if you
prefer a manual, local installation. This script installs to /usr/local
to avoid conflicts with system package managers.

1. Install Dependencies:
   Manually install meson, ninja, libusb-1.0, glib2, nss, pixman-1,
   and python3 (with 'usb' and 'crcmod' modules) using your
   distribution's package manager.

2. Build and Install:
   Ensure both .zip archives are present and run 'bash build_and_install.sh'.

3. Hardware Initialization:
   Agnostic installs require manual flashing for new users.
   Identify your ID via 'lsusb -d 27c6:' and run the corresponding script
   in /usr/local/share/goodix-flash/.

4. PAM Configuration:
   You must manually add 'auth sufficient pam_fprintd.so' to the top of
   your /etc/pam.d/sudo or desktop manager configuration files.

---

### 🔍 Technical Summary

1. Firmware & Key Injection (goodix-fp-dump):
   Supported Goodix sensors use a Pre-Shared Key (PSK) negotiated in
   Windows. The provided flash scripts reset the sensor state
   and inject a known PSK into volatile memory, enabling Linux
   communication. Note: Booting into Windows may
   require a re-flash.

2. Experimental Driver (libfprint):
   Standard libfprint lacks the TLS handshake logic required for these
   models. The 55b4-experimental branch adds TLS support
   and utilizes the SIGFM algorithm for matching.

⚠️ Usage & Dual-Boot Notes:
Windows Users: Highly recommended to DISABLE the Fingerprint device
in Windows Device Manager. This prevents Windows from overwriting the
Linux-compatible key and firmware state.

---

### 🗑 Testing & Removal
To perform a clean installation cycle or restore the system:
- Debian: sudo apt purge libfprint-2-2 && sudo apt autoremove
- Agnostic: Run 'bash uninstall.sh' and manually revert PAM changes.

---

### 📜 Change log
- V1.0 (2026-01-25): Initial public version.
- V1.1 (2026-01-29): Updated for 11-model support.
- V1.2 (2026-03-03): Integrated SML Master Builder (V3.4) to handle local
  ZIP archives, prevent build stalls, and implement a single-ask lockfile
  for the Debian installer.

##################################################################
