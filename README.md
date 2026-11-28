<div align="center">

<img src="assets/logo.svg" width="240" alt="SkyTool">

A tool for Termux. This repo is still in its early stage.

![Version](https://img.shields.io/badge/Version-v9.6.9-4c1) ![Platform](https://img.shields.io/badge/Platform-Termux-2a6fb0) [![Telegram](https://img.shields.io/badge/Telegram-%40Skypin969-2aabee?logo=telegram&logoColor=white)](https://t.me/Skypin969)

</div>

---

## First step

1. Install the **Termux** and **Termux:API** apps on your phone from **F-Droid** or from the GitHub releases page: [termux-app](https://github.com/termux/termux-app/releases) and [termux-api](https://github.com/termux/termux-api/releases). Use the same source for both apps. Do not use the Play Store versions.
2. Open Termux and run this one command:

```
source <(curl -sS "https://raw.githubusercontent.com/skypin969/skytool/main/setup.sh")
```

The `setup.sh` script will:
- ask for storage permission at the start (tap Allow on the phone screen),
- check the phone architecture (must be aarch64 or arm),
- check that the Termux:API app is installed,
- install the python, git, termux-api and libusb packages,
- install adb and fastboot from termux-adb.

---

## Check the fastboot device

After `setup.sh` finishes:

1. Put the phone you want to check into fastboot mode.
2. Connect that phone to the Termux phone with an OTG cable.
3. Run this command in Termux:

```
fastboot devices
```

If a USB permission prompt appears on the phone screen, tap Allow, then run the command again.

---

## Tool menu

Once `fastboot devices` shows the phone, run this command in Termux to open the menu:

```
source <(curl -sS "https://raw.githubusercontent.com/skypin969/skytool/main/menu.sh")
```

The main menu `menu.sh` opens other scripts from the repo based on the number you choose:
- `1` FLASH ROM FASTBOOT TGZ opens `flash_rom_fastboot.sh`. This script lists `.tgz` files and ROM folders in the phone storage. A ROM folder is recognized by its contents (it has an `images` folder and a `flash_all*.sh` script), so it is still found even if the name was changed. Choose a `.tgz` to extract it first, then pick a flash method. Flashing runs like MiTool: it waits for the device, then runs the script and shows the result.
- `2` FLASH FILE IMG opens `flash_file_img.sh`. It flashes one `.img` file to one partition. See the section below.
- `3` ADB SIDELOAD is not built yet.

---

## FLASH FILE IMG

Pilih `2` di menu utama.

1. `[ 1 ] [ Cek fastboot ]`: tekan `1` setelah HP masuk mode fastboot.
2. `[ 1 ] [ boot ]` ... `[ 5 ] [ lainnya ]`: pilih partisi. Tambah `a` atau `b` untuk slot, misalnya `1b`, atau ketik `5super` untuk partisi lain.
3. `[ Partisi Dipilih ]`, `[ Folder ] : Download`, dan `[ File img yang ada ]`: ketik nama file, lalu Enter.
4. Hasil muncul dengan `[ OK ]` atau `[ !! ]`, lalu log di `~/skytool_flash_img.log`.
5. `[ 1 ] [ Reboot perangkat ]` atau `[ 2 ] [ Reboot recovery ]`, lalu `[ 0 ] [ Kembali ]`.
