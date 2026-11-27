#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL setup v9.6.9
# Persiapan Termux sebelum menjalankan SKYTOOL.
# Memeriksa syarat, memasang paket, dan menyiapkan adb/fastboot yang bisa mengakses USB.

set -e

VERSI="v9.6.9"
TOTAL=7
ESC=$'\033'
RESET="${ESC}[0m"
# Warna sama dengan mockup (kode warna 24-bit)
PUTIH="${ESC}[38;2;255;255;255m"
ORANYE="${ESC}[38;2;255;105;0m"
ORANYE_TERANG="${ESC}[38;2;255;178;122m"
ABU_TEKS="${ESC}[38;2;108;112;128m"
ABU="${ESC}[38;2;95;100;114m"
ABU_GELAP="${ESC}[38;2;46;50;64m"
ABU_TRACK="${ESC}[38;2;27;30;38m"
MERAH="${ESC}[38;2;226;75;74m"

LABEL=("izin penyimpanan" "arsitektur HP" "Termux:API" "apt update" "apt upgrade" "pasang python, git, libusb" "adb & fastboot (termux-adb)")
STATUS=(pending pending pending pending pending pending pending)
PESAN=""

cetak() {
    printf '%s\033[K\n' "$1"
}

# Jeda singkat tanpa perintah luar (sleep bisa rusak saat apt upgrade mengganti libpcre2)
jeda() {
    read -r -t "$1" _ <> <(:) 2>/dev/null || true
}

# Mengulang perintah sampai 3 kali kalau gagal (mirror Termux kadang sedang sinkronisasi)
ulangi() {
    local n
    for n in 1 2 3; do
        if "$@"; then
            return 0
        fi
        jeda 8
    done
    return 1
}

# Menyusun isi layar di memori (tanpa mencetak)
susun_layar() {
    local selesai=0 persen isi j bar
    for ((j = 0; j < TOTAL; j++)); do
        if [ "${STATUS[$j]}" = "ok" ]; then
            selesai=$((selesai + 1))
        fi
    done
    persen=$(( selesai * 100 / TOTAL ))
    isi=$(( persen / 5 ))
    bar=""
    for ((j = 0; j < 20; j++)); do
        if [ "$j" -lt "$isi" ]; then
            bar="${bar}${ORANYE}#"
        else
            bar="${bar} "
        fi
    done

    cetak ""
    cetak "${PUTIH}SKY${ORANYE}TOOL${RESET} ${ABU_TEKS}${VERSI}${RESET}"
    cetak "${ORANYE_TERANG}MENYIAPKAN TERMUX${RESET}"
    cetak ""
    cetak "[${bar}${RESET}] ${persen}%  (${selesai}/${TOTAL})"
    cetak ""
    for ((j = 0; j < TOTAL; j++)); do
        case "${STATUS[$j]}" in
            ok)   cetak "  ${ABU}[ OK ] ${LABEL[$j]}${RESET}" ;;
            run)  cetak "  ${ORANYE_TERANG}[ .. ] ${LABEL[$j]}${RESET}" ;;
            fail) cetak "  ${MERAH}[ XX ] ${LABEL[$j]}${RESET}" ;;
            *)    cetak "  ${ABU_GELAP}[    ] ${LABEL[$j]}${RESET}" ;;
        esac
    done
    if [ -n "$PESAN" ]; then
        cetak ""
        cetak "$PESAN"
    fi
    printf '\033[J'
}

# Layar disusun dulu di memori, lalu dicetak sekali sekaligus (supaya tidak berkedip).
gambar_layar() {
    local isi
    isi=$(susun_layar)
    printf '\033[H%s' "$isi"
}

# Menjalankan satu langkah di latar belakang sambil layar digambar ulang.
# Argumen: nomor langkah, lalu perintah yang dijalankan.
jalankan_langkah() {
    local idx="$1"
    shift
    local log pid
    STATUS[$idx]="run"
    log=$(mktemp)
    "$@" > "$log" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        gambar_layar
        jeda 0.5
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
        mkdir -p "$PREFIX/etc/apt/trusted.gpg.d"
        curl -fsSL -o "$PREFIX/etc/apt/trusted.gpg.d/nohajc.gpg" https://nohajc.github.io/nohajc.gpg
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
        jeda 1
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
gambar_layar

# Langkah 2 sampai 7
jalankan_langkah 1 cek_arsitektur
jalankan_langkah 2 cek_termux_api
jalankan_langkah 3 ulangi bash -c "yes | apt update"
jalankan_langkah 4 ulangi bash -c "yes | apt upgrade && apt install -y --reinstall coreutils"
jalankan_langkah 5 ulangi bash -c "yes | pkg install python git termux-api libusb"
jalankan_langkah 6 pasang_termux_adb

gambar_layar
cek_fastboot
