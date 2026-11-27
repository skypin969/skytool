#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL setup v9.6.9
# Persiapan Termux sebelum menjalankan SKYTOOL.
# Memeriksa syarat, memasang paket, dan menyiapkan adb/fastboot yang bisa mengakses USB.

set -e

VERSI="v9.6.9"
MERAH='\033[0;31m'
HIJAU='\033[0;32m'
ORANYE='\033[38;5;208m'
ABU='\033[0;90m'
RESET='\033[0m'

tampil_judul() {
    clear 2>/dev/null || true
    printf "\n\033[1;97mSKY${ORANYE}TOOL${RESET}  ${ABU}%s${RESET}\n" "$VERSI"
    printf "\033[48;5;208m\033[1;97m MENYIAPKAN TERMUX \033[0m\n\n"
}

# Satu langkah berjalan di latar belakang. Selama berjalan hanya satu baris yang berubah:
# "[ .. ]" dengan titik-titik bergantian. Berhasil: "[ OK ]" hijau. Gagal: "[ XX ]" merah dan isi error.
run_step() {
    local msg="$1"
    shift
    local log frame i=0
    local frames=("." ".." "...")
    log=$(mktemp)
    "$@" > "$log" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        frame="${frames[$((i % 3))]}"
        printf "\r\033[2K  ${ORANYE}[ .. ]${RESET} %s %s" "$msg" "$frame"
        i=$((i + 1))
        sleep 0.5
    done
    if wait "$pid"; then
        printf "\r\033[2K  ${HIJAU}[ OK ]${RESET} %s\n" "$msg"
        rm -f "$log"
    else
        printf "\r\033[2K  ${MERAH}[ XX ]${RESET} %s\n" "$msg"
        echo ""
        tail -n 20 "$log"
        rm -f "$log"
        exit 1
    fi
}

cek_arsitektur() {
    local arch
    arch=$(dpkg --print-architecture)
    if [ "$arch" != "aarch64" ] && [ "$arch" != "arm" ]; then
        echo "Arsitektur $arch tidak didukung."
        return 1
    fi
}

cek_termux_api() {
    if ! cmd package list packages --user 0 com.termux.api < /dev/null 2>/dev/null | grep -q 'com.termux.api'; then
        echo "Aplikasi Termux:API belum terpasang. Pasang dulu dari F-Droid, lalu jalankan lagi perintah awal di README."
        return 1
    fi
}

pasang_termux_adb() {
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
}

# Cek perangkat fastboot langsung setelah setup selesai.
cek_fastboot() {
    local hasil
    hasil=$(fastboot devices 2>&1 < /dev/null || true)
    echo ""
    if echo "$hasil" | grep -qE '[[:space:]]fastboot$'; then
        printf "  ${HIJAU}Perangkat fastboot terdeteksi:${RESET}\n"
        echo "$hasil" | grep -E '[[:space:]]fastboot$'
    else
        printf "  ${ABU}Belum ada perangkat fastboot.${RESET}\n"
        echo "  Sambungkan HP dalam mode fastboot lewat OTG."
        echo "  Kalau muncul izin USB di layar HP, tekan Izinkan."
        echo "  Lalu jalankan lagi: fastboot devices"
    fi
}

tampil_judul

# Langkah 1: izin penyimpanan (perlu tombol di layar HP, jadi tanpa animasi)
if [ ! -d "$HOME/storage" ]; then
    echo "  Tekan Izinkan di layar HP."
    termux-setup-storage || true
    for _ in $(seq 1 30); do
        [ -d "$HOME/storage" ] && break
        sleep 1
    done
fi
if [ ! -d "$HOME/storage" ]; then
    printf "  ${MERAH}[ XX ]${RESET} Izin penyimpanan\n"
    echo "  Jalankan lagi perintah awal di README."
    exit 1
fi
printf "  ${HIJAU}[ OK ]${RESET} Izin penyimpanan\n"

# Langkah 2 sampai 7: setiap langkah tampil dengan animasi titik-titik.
# Teks dibuat pendek supaya muat dalam satu baris di layar HP.
run_step "Memeriksa arsitektur HP" cek_arsitektur
run_step "Memeriksa Termux:API" cek_termux_api
run_step "Memperbarui daftar paket" bash -c "yes | apt update"
run_step "Memasang pembaruan paket" bash -c "yes | apt upgrade"
run_step "Memasang python, git, libusb" bash -c "yes | pkg install python git termux-api libusb"
run_step "Memasang adb & fastboot" pasang_termux_adb

echo ""
printf "  ${HIJAU}Persiapan selesai.${RESET}\n"
cek_fastboot
