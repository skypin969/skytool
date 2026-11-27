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
# Nomor gambar layar, dipakai untuk menggerakkan kilatan abu-abu pada bilah progres
KILAT=0
# Isi layar terakhir yang sudah ditulis, dipakai untuk menulis ulang baris yang berubah saja
LAYAR_LAMA=()

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
    local selesai=0 persen isi j bar pos
    for ((j = 0; j < TOTAL; j++)); do
        if [ "${STATUS[$j]}" = "ok" ]; then
            selesai=$((selesai + 1))
        fi
    done
    persen=$(( selesai * 100 / TOTAL ))
    # Bilah 10 kotak tanpa spasi di dalam kurung; kotak yang sudah terisi memakai tanda pagar oranye.
    # Dua kotak abu-abu bergerak di atas kotak yang sudah terisi (tanda pagar tidak ikut bergerak).
    isi=$(( persen / 10 ))
    pos=0
    if [ "$isi" -gt 0 ]; then
        pos=$(( KILAT % isi ))
    fi
    bar=""
    for ((j = 0; j < 10; j++)); do
        if [ "$j" -lt "$isi" ]; then
            if [ "$j" -ge "$pos" ] && [ "$j" -lt $(( pos + 2 )) ]; then
                bar="${bar}${ABU_GELAP}#"
            else
                bar="${bar}${ORANYE}#"
            fi
        else
            bar="${bar}${ABU_GELAP}#"
        fi
    done

    cetak ""
    cetak "${TEBAL}${PUTIH}ＳＫＹ${ORANYE}ＴＯＯＬ${RESET} ${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＭＥＮＹＩＡＰＫＡＮ　ＴＥＲＭＵＸ${RESET}"
    cetak ""
    cetak "${PUTIH}[${bar}${PUTIH}]  [  ${ORANYE}${persen}%${PUTIH}  ]  [  ${ORANYE}${selesai}/${TOTAL}${PUTIH}  ]${RESET}"
    cetak ""
    for ((j = 0; j < TOTAL; j++)); do
        case "${STATUS[$j]}" in
            ok)   cetak "${PUTIH}[  ${ORANYE}OK${PUTIH}  ] [  ${ORANYE}$(printf '%-27s' "${LABEL[$j]}")${PUTIH}  ]${RESET}" ;;
            run)  cetak "${PUTIH}[  ${ORANYE_TERANG}OK${PUTIH}  ] [  ${ORANYE_TERANG}$(printf '%-27s' "${LABEL[$j]}")${PUTIH}  ]${RESET}" ;;
            fail) cetak "${MERAH}[  ] [  $(printf '%-27s' "${LABEL[$j]}")  ]${RESET}" ;;
            *)    cetak "${ABU_GELAP}[  OK  ] [  $(printf '%-27s' "${LABEL[$j]}")  ]${RESET}" ;;
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
    local i isi baru_n
    local -a baru=()
    KILAT=$(( KILAT + 1 ))
    isi=$(susun_layar)
    mapfile -t baru <<< "$isi"
    baru_n=${#baru[@]}
    # Hanya baris yang berubah yang ditulis ulang, supaya layar tidak dikosongkan dan digambar penuh
    # setiap 0,2 detik (penyebab kedipan)
    for ((i = 0; i < baru_n; i++)); do
        if [ "${baru[i]}" != "${LAYAR_LAMA[i]-}" ]; then
            printf '\033[%d;1H%s' "$(( i + 1 ))" "${baru[i]}"
        fi
    done
    if [ "${#LAYAR_LAMA[@]}" -gt "$baru_n" ]; then
        printf '\033[%d;1H\033[J' "$(( baru_n + 1 ))"
    fi
    LAYAR_LAMA=("${baru[@]}")
    # Kursor ditaruh di bawah layar, supaya teks lain tercetak di bawah tampilan
    printf '\033[%d;1H' "$(( baru_n + 1 ))"
}

# Menjalankan satu langkah di latar belakang sambil layar digambar ulang.
# Argumen: nomor langkah, lalu perintah yang dijalankan. Mengembalikan 1 kalau gagal.
jalankan_langkah() {
    local idx="$1"
    shift
    local log rc_file pid rc
    STATUS[$idx]="run"
    log=$(mktemp)
    rc_file=$(mktemp)
    rm -f "$rc_file"
    # Perintah dijalankan di latar belakang lalu langsung dilepas dari daftar pekerjaan bash (disown),
    # supaya bash tidak menulis "[1]+ Done ..." ke layar. Kode keluarnya ditulis ke rc_file.
    ( "$@" > "$log" 2>&1; echo $? > "$rc_file" ) &
    pid=$!
    disown "$pid" 2>/dev/null
    while [ ! -s "$rc_file" ]; do
        gambar_layar
        jeda 0.2
    done
    rc=$(cat "$rc_file")
    rm -f "$rc_file"
    if [ "$rc" -eq 0 ]; then
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
    apt_senyap install termux-adb || return 1
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

# Menjalankan apt tanpa pertanyaan dan tanpa tulisan langsung ke layar.
# dpkg kadang menulis ke terminal (/dev/tty) dan itu merusak tampilan yang digambar ulang.
apt_senyap() {
    DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@" < /dev/null
}

langkah_upgrade() {
    apt_senyap upgrade && apt_senyap install --reinstall coreutils
}

langkah_paket() {
    apt_senyap install python git termux-api libusb
}

# Semua langkah instalasi. Berhenti di langkah pertama yang gagal.
jalankan_semua() {
    jalankan_langkah 1 cek_arsitektur || return 1
    jalankan_langkah 2 cek_termux_api || return 1
    jalankan_langkah 3 ulangi bash -c "yes | apt update" || return 1
    jalankan_langkah 4 ulangi langkah_upgrade || return 1
    jalankan_langkah 5 ulangi langkah_paket || return 1
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
            printf '\n'
            while read -r serial mode; do
                [ -z "$serial" ] && continue
                printf '\033[38;2;255;255;255m[ \033[38;2;255;105;0m%s    %s\033[38;2;255;255;255m ]\033[0m\n' "$serial" "$mode"
            done <<< "$keluaran"
        elif [ -n "$keluaran" ]; then
            printf '%s\n' "$keluaran"
        fi
        # Satu baris kosong setelah hasil, sama dengan jarak antara perintah dan hasilnya
        [ -n "$keluaran" ] && printf '\n'
        # Setelah perintah fastboot dijalankan, petunjuk hilang dan prompt kembali [ ~$  ]
        PS1='\[\e[38;2;255;255;255m\][  \[\e[38;2;255;105;0m\]\w\$\[\e[38;2;255;255;255m\]  ]\[\e[0m\] '
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
        # Petunjuk ditulis di baris sendiri di atas prompt, bukan di dalam prompt
        printf '%s\n' "${ABU_GELAP}Ketik : fastboot devices${RESET}"
        PS1='\[\e[38;2;255;255;255m\][  \[\e[38;2;255;105;0m\]\w\$\[\e[38;2;255;255;255m\]  ]\[\e[0m\] '
        pasang_pembungkus_fastboot
    fi

    printf '\033[?25h'
    return $rc
}

main
