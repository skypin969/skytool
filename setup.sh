#!/data/data/com.termux/files/usr/bin/bash
# Persiapan Termux sebelum menjalankan ToolPinz.
# Memeriksa syarat, memasang paket, dan menyiapkan adb/fastboot yang bisa mengakses USB.

set -e

echo "[1/6] Meminta izin penyimpanan..."
if [ ! -d "$HOME/storage" ]; then
    echo "Tekan Izinkan di layar HP."
    termux-setup-storage || true
    sleep 3
fi
if [ ! -d "$HOME/storage" ]; then
    echo "Izin penyimpanan belum diberikan. Jalankan lagi perintah awal di README."
    exit 1
fi

echo "[2/6] Memeriksa arsitektur..."
arch=$(dpkg --print-architecture)
if [ "$arch" != "aarch64" ] && [ "$arch" != "arm" ]; then
    echo "Arsitektur $arch tidak didukung."
    exit 1
fi

echo "[3/6] Memeriksa aplikasi Termux:API..."
if ! cmd package list packages --user 0 com.termux.api < /dev/null 2>/dev/null | grep -q 'com.termux.api'; then
    echo "Aplikasi Termux:API belum terpasang. Pasang dulu dari F-Droid, lalu jalankan lagi perintah awal di README."
    exit 1
fi

echo "[4/6] Memperbarui paket..."
yes | apt update
yes | apt upgrade

echo "[5/6] Memasang paket dasar..."
yes | pkg install python git termux-api libusb

echo "[6/6] Memasang adb dan fastboot (termux-adb, bisa mengakses USB)..."
# Repo resmi termux-adb dari pembuatnya (nohajc). Dipasang langsung di sini, bukan lewat skrip pihak lain.
if [ ! -f "$PREFIX/etc/apt/sources.list.d/termux-adb.list" ]; then
    mkdir -p "$PREFIX/etc/apt/sources.list.d"
    echo "deb https://nohajc.github.io termux extras" > "$PREFIX/etc/apt/sources.list.d/termux-adb.list"
    wget -qP "$PREFIX/etc/apt/trusted.gpg.d" https://nohajc.github.io/nohajc.gpg
    yes | apt update
fi
yes | apt install termux-adb
ln -sf "$PREFIX/bin/termux-fastboot" "$PREFIX/bin/fastboot"
ln -sf "$PREFIX/bin/termux-adb" "$PREFIX/bin/adb"

echo "Persiapan selesai. Sambungkan HP dalam mode fastboot, lalu jalankan: fastboot devices"
echo "Kalau muncul izin USB di layar HP, tekan Izinkan."
