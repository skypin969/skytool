# ToolPinz

Tool untuk Termux. Repo ini masih tahap awal.

## Persiapan awal

1. Pasang aplikasi **Termux** dan **Termux:API** dari F-Droid di HP. Jangan pakai versi Play Store.
2. Buka Termux, lalu jalankan dua perintah ini:

```
pkg install -y curl
```

```
bash <(curl -fsSL https://raw.githubusercontent.com/skypin969/ToolPinz/main/setup.sh)
```

Skrip `setup.sh` akan:
- meminta izin penyimpanan di awal (tekan Izinkan di layar HP),
- memeriksa arsitektur HP (harus aarch64 atau arm),
- memeriksa aplikasi Termux:API,
- memasang paket: python, git, termux-api, libusb, android-tools.

Kalau ada langkah yang gagal, perbaiki sesuai pesannya, lalu jalankan ulang perintah kedua.
