#!/data/data/com.termux/files/usr/bin/bash
# Persiapan Termux sebelum menjalankan ToolPinz.
# Hanya memeriksa syarat dan memasang paket. Tidak mengubah sistem perangkat.

set -e

echo "[1/4] Memeriksa arsitektur..."
arch=$(dpkg --print-architecture)
if [ "$arch" != "aarch64" ] && [ "$arch" != "arm" ]; then
    echo "Arsitektur $arch tidak didukung."
    exit 1
fi

echo "[2/4] Memeriksa izin penyimpanan..."
if [ ! -d "$HOME/storage" ]; then
    echo "Meminta izin penyimpanan. Tekan Izinkan di layar HP."
    termux-setup-storage || true
    sleep 3
fi
if [ ! -d "$HOME/storage" ]; then
    echo "Izin penyimpanan belum diberikan. Jalankan lagi: bash ~/ToolPinz/setup.sh"
    exit 1
fi

echo "[3/4] Memeriksa aplikasi Termux:API..."
if ! cmd package list packages --user 0 com.termux.api < /dev/null 2>/dev/null | grep -q 'com.termux.api'; then
    echo "Aplikasi Termux:API belum terpasang. Pasang dulu dari F-Droid, lalu jalankan lagi: bash ~/ToolPinz/setup.sh"
    exit 1
fi

echo "[4/4] Memperbarui dan memasang paket..."
yes | apt update
yes | apt upgrade
yes | pkg install python git termux-api libusb android-tools

echo "Persiapan selesai."
