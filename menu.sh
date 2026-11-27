#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL menu v9.6.9
# Menu utama SKYTOOL. Dijalankan setelah perintah `fastboot devices` berhasil.
# Aman dijalankan lewat `source` di sesi Termux: tidak memakai set -e, tidak memakai exit,
# dan tidak memasang trap, supaya error tidak menutup Termux.

VERSI="v9.6.9"
ESC=$'\033'
RESET="${ESC}[0m"
TEBAL="${ESC}[1m"
# Warna sama dengan setup.sh (kode warna 24-bit)
PUTIH="${ESC}[38;2;255;255;255m"
ORANYE="${ESC}[38;2;255;105;0m"
ABU_TEKS="${ESC}[38;2;170;176;190m"
ABU_GELAP="${ESC}[38;2;122;128;144m"
MERAH="${ESC}[38;2;226;75;74m"

# Folder Download di Termux (dibuat oleh termux-setup-storage pada setup.sh)
MENU_DL="$HOME/storage/downloads"
# Pesan singkat di bawah daftar, misalnya kalau nomor salah
MENU_PESAN=""
# Isi daftar: nama yang tampil, lokasi, dan jenisnya (tgz atau ekstrak)
MENU_NAMA=()
MENU_JALUR=()
MENU_JENIS=()

cetak() {
    printf '%s\033[K\n' "$1"
}

# Mengisi daftar: semua file .tgz di folder Download, lalu ROM yang sudah diekstrak
# (folder dengan nama yang sama dengan file .tgz).
muat_daftar() {
    local f nama
    MENU_NAMA=()
    MENU_JALUR=()
    MENU_JENIS=()
    shopt -s nullglob
    for f in "$MENU_DL"/*.tgz; do
        MENU_NAMA+=("$(basename "$f")")
        MENU_JALUR+=("$f")
        MENU_JENIS+=("tgz")
    done
    for f in "$MENU_DL"/*.tgz; do
        nama=$(basename "$f" .tgz)
        if [ -d "$MENU_DL/$nama" ]; then
            MENU_NAMA+=("$nama")
            MENU_JALUR+=("$MENU_DL/$nama")
            MENU_JENIS+=("ekstrak")
        fi
    done
    shopt -u nullglob
}

# Menggambar seluruh layar menu
gambar_menu() {
    local i nomor ada_tgz=0 ada_ekstrak=0
    clear
    cetak ""
    cetak "${TEBAL}${PUTIH}ＳＫＹ${ORANYE}ＴＯＯＬ${RESET} ${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＭＥＮＵ　ＴＯＯＬ${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}FLASH ROM FASTBOOT${RESET}"
    cetak ""

    cetak "${ABU_TEKS}ROM .tgz di folder Download:${RESET}"
    for ((i = 0; i < ${#MENU_NAMA[@]}; i++)); do
        if [ "${MENU_JENIS[i]}" = "tgz" ]; then
            ada_tgz=1
            nomor=$((i + 1))
            cetak "${PUTIH}[  ${ORANYE}${nomor}${PUTIH}  ] [  ${ORANYE}${MENU_NAMA[i]}${PUTIH}  ]${RESET}"
        fi
    done
    if [ "$ada_tgz" -eq 0 ]; then
        cetak "${ABU_GELAP}  (tidak ada file .tgz)${RESET}"
    fi
    cetak ""

    cetak "${ABU_TEKS}ROM yang sudah diekstrak:${RESET}"
    for ((i = 0; i < ${#MENU_NAMA[@]}; i++)); do
        if [ "${MENU_JENIS[i]}" = "ekstrak" ]; then
            ada_ekstrak=1
            nomor=$((i + 1))
            cetak "${PUTIH}[  ${ORANYE}${nomor}${PUTIH}  ] [  ${ORANYE}${MENU_NAMA[i]}${PUTIH}  ]${RESET}"
        fi
    done
    if [ "$ada_ekstrak" -eq 0 ]; then
        cetak "${ABU_GELAP}  (belum ada)${RESET}"
    fi
    cetak ""

    cetak "${ABU_GELAP}[  0  ] [  kembali  ]${RESET}"
    cetak ""
    if [ -n "$MENU_PESAN" ]; then
        cetak "$MENU_PESAN"
        cetak ""
    fi
    printf '\033[J'
}

# Loop menu: tampilkan daftar, baca pilihan, ulangi sampai pengguna memilih 0
menu_utama() {
    local pilihan
    while true; do
        muat_daftar
        gambar_menu
        printf '%s' "${PUTIH}Pilih nomor, lalu Enter: ${RESET}"
        read -r pilihan || return 0
        MENU_PESAN=""
        case "$pilihan" in
            "")
                ;;
            0)
                clear
                return 0
                ;;
            *[!0-9]*)
                MENU_PESAN="${MERAH}Ketik angka saja.${RESET}"
                ;;
            *)
                if [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#MENU_NAMA[@]}" ]; then
                    MENU_PESAN="${ABU_TEKS}Langkah flash untuk pilihan ini belum dibuat.${RESET}"
                else
                    MENU_PESAN="${MERAH}Nomor itu tidak ada di daftar.${RESET}"
                fi
                ;;
        esac
    done
}

menu_utama
