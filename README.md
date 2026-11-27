# skytool

Tool untuk Termux. Repo ini masih tahap awal.

## Persiapan awal

1. Pasang aplikasi **Termux** dan **Termux:API** dari F-Droid di HP. Jangan pakai versi Play Store.
2. Buka Termux, lalu jalankan satu perintah ini:

```
curl -sS https://raw.githubusercontent.com/skypin969/skytool/main/setup.sh | bash
```

Skrip `setup.sh` akan:
- meminta izin penyimpanan di awal (tekan Izinkan di layar HP),
- memeriksa arsitektur HP (harus aarch64 atau arm),
- memeriksa aplikasi Termux:API,
- memasang paket: python, git, termux-api, libusb, android-tools.

Kalau muncul pesan `curl: command not found`, jalankan dulu `pkg install -y curl`, lalu ulangi perintah di atas.
