#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL menu v9.6.9
# Menu utama SKYTOOL. Dijalankan setelah perintah `fastboot devices` berhasil.
# Setiap pilihan membuka skrip sendiri dari repo (misalnya pilihan 1 membuka flash_rom_fastboot.sh).
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

# Alamat repo tempat skrip pilihan diambil. Bisa diganti lewat SKYTOOL_BASE untuk uji coba.
SKYTOOL_BASE="${SKYTOOL_BASE:-https://raw.githubusercontent.com/skypin969/skytool/main}"
# Pesan singkat di bawah layar, misalnya kalau skrip belum ada
MENU_PESAN=""

cetak() {
    printf '%s\033[K\n' "$1"
}

# Logo SKYTOOL: SKY putih, TOOL oranye (huruf pagga, tiga baris)
cetak_logo() {
    cetak "${TEBAL}${PUTIH}░█▀▀░█░█░█░█${ORANYE}░▀█▀░█▀█░█▀█░█░░${RESET}"
    cetak "${TEBAL}${PUTIH}░▀▀█░█▀▄░░█░${ORANYE}░░█░░█░█░█░█░█░░${RESET}"
    cetak "${TEBAL}${PUTIH}░▀▀▀░▀░▀░░▀░${ORANYE}░░▀░░▀▀▀░▀▀▀░▀▀▀${RESET}"
}

# Satu baris menu: nomor dan nama dengan lebar tetap 27 karakter supaya kurung tutup sejajar
baris_menu() {
    printf '%s' "${PUTIH}[  ${ORANYE}$1${PUTIH}  ] [  ${ORANYE}$(printf '%-27s' "$2")${PUTIH}  ]${RESET}"
}

# Layar menu utama: tiga pilihan dan KELUAR
gambar_menu_utama() {
    clear
    cetak ""
    cetak_logo
    cetak ""
    cetak "${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＭＥＮＵ ＴＯＯＬ${RESET}"
    cetak ""
    cetak "$(baris_menu 1 "FLASH ROM FASTBOOT TGZ")"
    cetak "$(baris_menu 2 "FLASH FILE IMG")"
    cetak "$(baris_menu 3 "ADB SIDELOAD")"
    cetak ""
    cetak "${ABU_GELAP}[  0  ] [  KELUAR  ]${RESET}"
    cetak ""
    if [ -n "$MENU_PESAN" ]; then
        cetak "$MENU_PESAN"
        cetak ""
    fi
    printf '\033[J'
}

# Mengambil skrip dari repo lalu menjalankannya. Argumen: nama file skrip (misalnya flash_rom_fastboot.sh).
# Kalau skrip belum ada di repo atau HP tidak terhubung internet, layar menu tetap jalan.
buka_skrip() {
    local kode
    if ! kode=$(curl -fsS "$SKYTOOL_BASE/$1" 2>/dev/null); then
        MENU_PESAN="${ABU_TEKS}Menu ini belum dibuat, atau HP tidak terhubung internet.${RESET}"
        return 1
    fi
    source <(printf '%s\n' "$kode")
}

# Layar menu utama: membaca pilihan sampai pengguna memilih 0 (KELUAR)
menu_utama() {
    local pilihan
    while true; do
        gambar_menu_utama
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
            1)
                buka_skrip flash_rom_fastboot.sh
                ;;
            2)
                buka_skrip flash_file_img.sh
                ;;
            3)
                buka_skrip adb_sideload.sh
                ;;
            *)
                MENU_PESAN="${MERAH}Nomor itu tidak ada di daftar.${RESET}"
                ;;
        esac
    done
}

menu_utama
