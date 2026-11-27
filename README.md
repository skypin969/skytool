<div align="center">

<img src="assets/logo.svg" width="240" alt="SkyTool">

Tool untuk Termux. Repo ini masih tahap awal.

![Version](https://img.shields.io/badge/Version-v9.6.9-4c1) ![Platform](https://img.shields.io/badge/Platform-Termux-2a6fb0)

</div>

---

## Persiapan awal

1. Pasang aplikasi **Termux** dan **Termux:API** dari F-Droid di HP. Jangan pakai versi Play Store.
2. Buka Termux, lalu jalankan satu perintah ini:

```
source <(curl -sS "https://raw.githubusercontent.com/skypin969/skytool/main/setup.sh")
```

Skrip `setup.sh` akan:
- meminta izin penyimpanan di awal (tekan Izinkan di layar HP),
- memeriksa arsitektur HP (harus aarch64 atau arm),
- memeriksa aplikasi Termux:API,
- memasang paket python, git, termux-api, libusb,
- memasang adb dan fastboot dari termux-adb.

---

## Cek perangkat fastboot

Setelah `setup.sh` selesai:

1. Masukkan HP yang ingin dicek ke mode fastboot.
2. Sambungkan HP itu ke HP Termux memakai kabel OTG.
3. Jalankan perintah ini di Termux:

```
fastboot devices
```

Kalau muncul izin USB di layar HP, tekan Izinkan, lalu jalankan perintah tadi lagi.
