#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL setup v9.6.9
# Persiapan Termux sebelum menjalankan SKYTOOL.
# Memeriksa syarat, memasang paket, dan menyiapkan adb/fastboot yang bisa mengakses USB.

set -e

VERSI="v9.6.9"
LEBAR=36
TOTAL=7
ESC=$'\033'
RESET="${ESC}[0m"
PUTIH="${ESC}[1;97m"
ORANYE="${ESC}[38;5;208m"
ORANYE_TERANG="${ESC}[38;5;215m"
BG_ORANYE="${ESC}[48;5;208m"
BG_ORANYE2="${ESC}[48;5;202m"
ABU="${ESC}[38;5;245m"
ABU_GELAP="${ESC}[38;5;238m"
ABU_TRACK="${ESC}[38;5;236m"
MERAH="${ESC}[38;5;203m"
HIJAU_PROMPT="${ESC}[38;5;79m"
BIRU_PROMPT="${ESC}[38;5;111m"

# Nama langkah (pendek supaya muat satu baris di layar HP)
LABEL=("izin penyimpanan" "arsitektur HP" "termux-api terdeteksi" "apt update" "apt upgrade" "pkg install python git libusb" "termux-adb (fastboot USB)")
# Status tiap langkah: pending, run, ok, fail
STATUS=(pending pending pending pending pending pending pending)
SPIN="⠋"
PESAN=""
BLINK=1

cetak() {
    printf '%s\033[K\n' "$1"
}

# Satu baris judul dengan latar oranye bergaris (garis miring dibuat dari dua warna oranye bergantian)
baris_stripe() {
    local teks="$1" baris="$2" i ch
    local panjang=$(( LEBAR - 2 ))
    while [ ${#teks} -lt $panjang ]; do
        teks="$teks "
    done
    for ((i = 0; i < ${#teks}; i++)); do
        ch="${teks:i:1}"
        if (( ((i + baris * 2) / 4) % 2 )); then
            printf '%s%s%s' "$BG_ORANYE2" "$PUTIH" "$ch"
        else
            printf '%s%s%s' "$BG_ORANYE" "$PUTIH" "$ch"
        fi
    done
    printf '%s' "$RESET"
}

# Menggambar seluruh layar dari awal setiap kali (supaya tidak ada baris tertinggal)
gambar_layar() {
    local selesai=0 persen isi j bar kursor
    for ((j = 0; j < TOTAL; j++)); do
        if [ "${STATUS[$j]}" = "ok" ]; then
            selesai=$((selesai + 1))
        fi
    done
    persen=$(( selesai * 100 / TOTAL ))

    printf '%s' "${ESC}[H"
    cetak ""
    cetak "${PUTIH}SKY${ORANYE}TOOL${RESET}$(printf '%*s' 22 '')${ABU}${VERSI}${RESET}"
    cetak ""
    cetak "$(baris_stripe "MENYIAPKAN TERMUX" 0)${BG_ORANYE}${PUTIH}${SPIN} ${RESET}"
    cetak "$(baris_stripe "langkah ${selesai} dari ${TOTAL} - ${persen}%" 1)"

    isi=$(( persen * LEBAR / 100 ))
    bar=""
    for ((j = 0; j < LEBAR; j++)); do
        if [ "$j" -lt "$isi" ]; then
            bar="${bar}${ORANYE}━"
        else
            bar="${bar}${ABU_TRACK}━"
        fi
    done
    cetak ""
    cetak "${bar}${RESET}"
    cetak ""

    for ((j = 0; j < TOTAL; j++)); do
        case "${STATUS[$j]}" in
            ok)   cetak "${ABU}[ OK ] ${LABEL[$j]}${RESET}" ;;
            run)  cetak "${ORANYE_TERANG}[ .. ] ${LABEL[$j]}${RESET}" ;;
            fail) cetak "${MERAH}[ XX ] ${LABEL[$j]}${RESET}" ;;
            *)    cetak "${ABU_GELAP}[ -- ] ${LABEL[$j]}${RESET}" ;;
        esac
    done

    if [ -n "$PESAN" ]; then
        cetak ""
        cetak "$PESAN"
    fi

    cetak ""
    if [ "$BLINK" -eq 1 ]; then
        kursor="█"
    else
        kursor=" "
    fi
    BLINK=$((1 - BLINK))
    cetak "${HIJAU_PROMPT}root@skytool${RESET}:${BIRU_PROMPT}~${RESET}\$ ${PUTIH}${kursor}${RESET}"
    printf '\033[J'
}

# Menjalankan satu langkah di latar belakang sambil layar digambar ulang.
# Argumen: nomor langkah, lalu perintah yang dijalankan.
jalankan_langkah() {
    local idx="$1"
    shift
    local log pid i=0
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    STATUS[$idx]="run"
    log=$(mktemp)
    "$@" > "$log" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        SPIN="${frames[$((i % 10))]}"
        i=$((i + 1))
        gambar_layar
        sleep 0.15
    done
    if wait "$pid"; then
        STATUS[$idx]="ok"
        gambar_layar
        rm -f "$log"
    else
        STATUS[$idx]="fail"
        gambar_layar
        echo ""
        tail -n 15 "$log"
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

# Memasang font monospace untuk seluruh tampilan Termux (font diambil dari repo ini).
pasang_font() {
    mkdir -p "$HOME/.termux"
    curl -sS -L -o "$HOME/.termux/font.ttf" https://raw.githubusercontent.com/skypin969/skytool/main/fonts/JetBrainsMono.ttf
    termux-reload-settings 2>/dev/null || true
}

# Cek perangkat fastboot langsung setelah setup selesai.
cek_fastboot() {
    local hasil
    hasil=$(fastboot devices 2>&1 < /dev/null || true)
    echo ""
    if echo "$hasil" | grep -qE '[[:space:]]fastboot$'; then
        echo "  Perangkat fastboot terdeteksi:"
        echo "$hasil" | grep -E '[[:space:]]fastboot$'
    else
        echo "  Belum ada perangkat fastboot."
        echo "  Sambungkan HP dalam mode fastboot lewat OTG."
        echo "  Kalau muncul izin USB di layar HP, tekan Izinkan."
        echo "  Lalu jalankan lagi: fastboot devices"
    fi
}

# Font dipasang dulu, sebelum layar pertama digambar
pasang_font || true

clear 2>/dev/null || true

# Langkah 1: izin penyimpanan (perlu tombol di layar HP)
STATUS[0]="run"
if [ ! -d "$HOME/storage" ]; then
    PESAN="Tekan Izinkan di layar HP."
    gambar_layar
    termux-setup-storage || true
    for _ in $(seq 1 60); do
        [ -d "$HOME/storage" ] && break
        sleep 1
    done
    PESAN=""
fi
if [ ! -d "$HOME/storage" ]; then
    STATUS[0]="fail"
    gambar_layar
    echo "Izin penyimpanan belum diberikan. Jalankan lagi perintah awal di README."
    exit 1
fi
STATUS[0]="ok"

# Langkah 2 sampai 7
jalankan_langkah 1 cek_arsitektur
jalankan_langkah 2 cek_termux_api
jalankan_langkah 3 bash -c "yes | apt update"
jalankan_langkah 4 bash -c "yes | apt upgrade"
jalankan_langkah 5 bash -c "yes | pkg install python git termux-api libusb"
jalankan_langkah 6 pasang_termux_adb

gambar_layar
cek_fastboot
