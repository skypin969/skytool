# ToolPinz

Tool untuk Termux. Repo ini masih tahap awal.

## Persiapan awal

1. Pasang aplikasi **Termux** dan **Termux:API** dari F-Droid di HP. Jangan pakai versi Play Store.
2. Buka Termux, lalu jalankan satu perintah ini. Izin penyimpanan diminta paling awal, jadi tekan Izinkan di layar HP saat muncul:

```
termux-setup-storage && pkg install -y git && git clone https://github.com/skypin969/ToolPinz ~/ToolPinz && bash ~/ToolPinz/setup.sh
```

Skrip `setup.sh` akan:
- memeriksa arsitektur HP (harus aarch64 atau arm),
- memastikan izin penyimpanan sudah ada,
- memeriksa aplikasi Termux:API,
- memasang paket: python, git, termux-api, libusb, android-tools.

Kalau ada langkah yang gagal, perbaiki sesuai pesannya, lalu jalankan ulang `bash ~/ToolPinz/setup.sh`.
