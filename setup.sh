#!/data/data/com.termux/files/usr/bin/bash
# Persiapan Termux sebelum menjalankan ToolPinz.
# Memeriksa syarat, memasang paket, dan menyiapkan adb/fastboot yang bisa mengakses USB.

set -e

# Menjalankan satu langkah. Selama berjalan, hanya ada satu baris yang berubah:
# titik-titik bergantian (., .., ...). Kalau berhasil: tanda centang hijau.
# Kalau gagal: tanda silang dan isi pesan error.
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
        printf "\r%s %-3s" "$msg" "$frame"
        i=$((i + 1))
        sleep 0.5
    done
    if wait "$pid"; then
        printf "\r%s \033[0;32m✔\033[0m   \n" "$msg"
    else
        printf "\r%s \033[0;31m✘\033[0m   \n" "$msg"
        cat "$log"
        rm -f "$log"
        exit 1
    fi
    rm -f "$log"
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

# Langkah 1: izin penyimpanan (perlu tombol di layar HP, jadi tidak pakai animasi)
echo "Meminta izin penyimpanan..."
if [ ! -d "$HOME/storage" ]; then
    echo "Tekan Izinkan di layar HP."
    termux-setup-storage || true
    sleep 3
fi
if [ ! -d "$HOME/storage" ]; then
    echo "Izin penyimpanan belum diberikan. Jalankan lagi perintah awal di README."
    exit 1
fi
printf "Izin penyimpanan \033[0;32m✔\033[0m\n"

# Langkah 2: arsitektur
arch=$(dpkg --print-architecture)
if [ "$arch" != "aarch64" ] && [ "$arch" != "arm" ]; then
    echo "Arsitektur $arch tidak didukung."
    exit 1
fi
printf "Arsitektur $arch \033[0;32m✔\033[0m\n"

# Langkah 3: Termux:API
if ! cmd package list packages --user 0 com.termux.api < /dev/null 2>/dev/null | grep -q 'com.termux.api'; then
    echo "Aplikasi Termux:API belum terpasang. Pasang dulu dari F-Droid, lalu jalankan lagi perintah awal di README."
    exit 1
fi
printf "Termux:API \033[0;32m✔\033[0m\n"

# Langkah 4 sampai 6: instalasi dengan animasi titik-titik
run_step "Memperbarui daftar paket (apt update)" bash -c "yes | apt update"
run_step "Memasang pembaruan paket (apt upgrade)" bash -c "yes | apt upgrade"
run_step "Memasang python, git, termux-api, libusb" bash -c "yes | pkg install python git termux-api libusb"
run_step "Memasang adb dan fastboot (termux-adb)" pasang_termux_adb

echo ""
echo "Persiapan selesai. Sambungkan HP dalam mode fastboot, lalu jalankan: fastboot devices"
echo "Kalau muncul izin USB di layar HP, tekan Izinkan."
