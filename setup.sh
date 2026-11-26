#!/data/data/com.termux/files/usr/bin/bash
# Persiapan Termux sebelum menjalankan ToolPinz.
# Hanya memeriksa syarat dan memasang paket. Tidak mengubah sistem perangkat.

set -e

echo "[1/5] Meminta izin penyimpanan..."
if [ ! -d "$HOME/storage" ]; then
    echo "Tekan Izinkan di layar HP."
    termux-setup-storage || true
    sleep 3
fi
if [ ! -d "$HOME/storage" ]; then
    echo "Izin penyimpanan belum diberikan. Jalankan lagi perintah awal di README."
    exit 1
fi

echo "[2/5] Memeriksa arsitektur..."
arch=$(dpkg --print-architecture)
if [ "$arch" != "aarch64" ] && [ "$arch" != "arm" ]; then
    echo "Arsitektur $arch tidak didukung."
    exit 1
fi

echo "[3/5] Memeriksa aplikasi Termux:API..."
if ! cmd package list packages --user 0 com.termux.api < /dev/null 2>/dev/null | grep -q 'com.termux.api'; then
    echo "Aplikasi Termux:API belum terpasang. Pasang dulu dari F-Droid, lalu jalankan lagi perintah awal di README."
    exit 1
fi

echo "[4/5] Memperbarui paket..."
yes | apt update
yes | apt upgrade

echo "[5/5] Memasang paket yang dibutuhkan..."
yes | pkg install python git termux-api libusb android-tools

echo "Persiapan selesai."
