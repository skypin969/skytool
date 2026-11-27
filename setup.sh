#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL setup v9.6.9
# Persiapan Termux sebelum menjalankan SKYTOOL.
# Aman dijalankan lewat `source` di sesi Termux: tidak memakai set -e, tidak memakai exit,
# dan tidak memasang trap, supaya error tidak menutup Termux.

VERSI="v9.6.9"
ESC=$'\033'
RESET="${ESC}[0m"
TEBAL="${ESC}[1m"
# Warna sama dengan mockup (kode warna 24-bit)
PUTIH="${ESC}[38;2;255;255;255m"
ORANYE="${ESC}[38;2;255;105;0m"
ORANYE_TERANG="${ESC}[38;2;255;178;122m"
ABU_TEKS="${ESC}[38;2;170;176;190m"
ABU_GELAP="${ESC}[38;2;122;128;144m"
MERAH="${ESC}[38;2;226;75;74m"

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

# Menyusun isi layar di memori. Memakai TOTAL, LABEL, STATUS, dan PESAN dari fungsi pemanggil.
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
    cetak "${TEBAL}${PUTIH}ＳＫＹ${ORANYE}ＴＯＯＬ${RESET} ${ABU_TEKS}${VERSI}${RESET}"
    cetak "${TEBAL}${ORANYE}ＭＥＮＹＩＡＰＫＡＮ　ＴＥＲＭＵＸ${RESET}"
    cetak ""
    cetak "[${bar}${RESET}] ${persen}%  (${selesai}/${TOTAL})"
    cetak ""
    for ((j = 0; j < TOTAL; j++)); do
        case "${STATUS[$j]}" in
            ok)   cetak "  ${PUTIH}[  ${RESET}${ORANYE}${LABEL[$j]}${RESET}${PUTIH}  ]${RESET}" ;;
            run)  cetak "  ${ORANYE_TERANG}[  ${LABEL[$j]}  ]${RESET}" ;;
            fail) cetak "  ${MERAH}[  ${LABEL[$j]}  ]${RESET}" ;;
            *)    cetak "  ${ABU_GELAP}[  ${LABEL[$j]}  ]${RESET}" ;;
        esac
    done
    if [ -n "$PESAN" ]; then
        cetak ""
        cetak "$PESAN"
    fi
    cetak ""
    printf '\033[J'
}

# Layar disusun dulu di memori, lalu dicetak sekali sekaligus (supaya tidak berkedip).
gambar_layar() {
    local isi
    isi=$(susun_layar)
    printf '\033[H%s' "$isi"
}

# Menjalankan satu langkah di latar belakang sambil layar digambar ulang.
# Argumen: nomor langkah, lalu perintah yang dijalankan. Mengembalikan 1 kalau gagal.
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
        return 0
    fi
    STATUS[$idx]="fail"
    gambar_layar
    echo ""
    tail -n 15 "$log"
    rm -f "$log"
    return 1
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
        curl -fsSL -o "$PREFIX/etc/apt/trusted.gpg.d/nohajc.gpg" https://nohajc.github.io/nohajc.gpg || return 1
        yes | apt update
    fi
    yes | apt install termux-adb || return 1
    ln -sf "$PREFIX/bin/termux-fastboot" "$PREFIX/bin/fastboot"
    ln -sf "$PREFIX/bin/termux-adb" "$PREFIX/bin/adb"
}

# Memasang font monospace untuk seluruh tampilan Termux (font diambil dari repo ini).
pasang_font() {
    mkdir -p "$HOME/.termux"
    curl -sS -L -o "$HOME/.termux/font.ttf" https://raw.githubusercontent.com/skypin969/skytool/main/fonts/JetBrainsMono.ttf
    termux-reload-settings 2>/dev/null || true
}

# Prompt Termux tetap bawaan (~ $). Pengaturan prompt dari versi sebelumnya dihapus kalau masih ada.
pulihkan_prompt() {
    if [ -f "$HOME/.bashrc" ] && grep -q "SKYTOOL_PROMPT" "$HOME/.bashrc"; then
        sed -i '/SKYTOOL_PROMPT/,+1d' "$HOME/.bashrc"
    fi
}

# Semua langkah instalasi. Berhenti di langkah pertama yang gagal.
jalankan_semua() {
    jalankan_langkah 1 cek_arsitektur || return 1
    jalankan_langkah 2 cek_termux_api || return 1
    jalankan_langkah 3 ulangi bash -c "yes | apt update" || return 1
    jalankan_langkah 4 ulangi bash -c "yes | apt upgrade && apt install -y --reinstall coreutils" || return 1
    jalankan_langkah 5 ulangi bash -c "yes | pkg install python git termux-api libusb" || return 1
    jalankan_langkah 6 pasang_termux_adb || return 1
}

# Membungkus perintah fastboot di sesi ini agar hasil "fastboot devices" tampil seperti contoh:
# [ NOMOR    fastboot ] dengan kurung putih dan tulisan oranye.
# Pembungkus ini hanya ada di sesi ini, tidak ditulis ke .bashrc.
pasang_pembungkus_fastboot() {
    fastboot() {
        local keluaran rc=0 serial mode
        keluaran=$(command fastboot "$@" 2>&1) || rc=$?
        if [ "${1:-}" = "devices" ] && [ -n "$keluaran" ]; then
            while read -r serial mode; do
                [ -z "$serial" ] && continue
                printf '\033[38;2;255;255;255m[ \033[38;2;255;105;0m%s    %s\033[38;2;255;255;255m ]\033[0m\n' "$serial" "$mode"
            done <<< "$keluaran"
        elif [ -n "$keluaran" ]; then
            printf '%s\n' "$keluaran"
        fi
        return $rc
    }
}

main() {
    local TOTAL=7 PESAN=""
    local -a LABEL=("izin penyimpanan" "arsitektur HP" "Termux:API" "apt update" "apt upgrade" "pasang python, git, libusb" "adb & fastboot (termux-adb)")
    local -a STATUS=(pending pending pending pending pending pending pending)

    # Kursor disembunyikan selama proses berjalan, lalu dimunculkan lagi di akhir
    printf '\033[?25l'

    # Font dan prompt dipasang dulu, sebelum layar pertama digambar
    pasang_font || true
    pulihkan_prompt || true

    clear 2>/dev/null || true

    # Langkah 1: izin penyimpanan (perlu tombol di layar HP)
    STATUS[0]="run"
    if [ ! -d "$HOME/storage" ]; then
        PESAN="Tekan Izinkan di layar HP."
        gambar_layar
        termux-setup-storage || true
        local i
        for i in $(seq 1 60); do
            [ -d "$HOME/storage" ] && break
            jeda 1
        done
        PESAN=""
    fi
    if [ ! -d "$HOME/storage" ]; then
        STATUS[0]="fail"
        gambar_layar
        echo "Izin penyimpanan belum diberikan. Jalankan lagi perintah awal di README."
        printf '\033[?25h'
        return 1
    fi
    STATUS[0]="ok"
    gambar_layar

    # Langkah 2 sampai 7
    local rc=0
    jalankan_semua || rc=1

    if [ "$rc" -eq 0 ]; then
        # Setelah persiapan selesai, prompt di sesi ini berubah jadi [ ~$  ] dengan petunjuk abu-abu di sebelahnya.
        # Pengaturan ini tidak ditulis ke .bashrc, jadi saat Termux dibuka lagi prompt kembali ke bawaan.
        PS1='\[\e[38;2;255;105;0m\][ \w\$  ]\[\e[0m\] \[\e[38;2;122;128;144m\]Ketik : fastboot devices\[\e[0m\] '
        pasang_pembungkus_fastboot
    fi

    printf '\033[?25h'
    return $rc
}

main
