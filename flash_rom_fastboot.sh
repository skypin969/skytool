#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL FLASH ROM FASTBOOT TGZ v9.6.9
# Dibuka dari menu.sh (pilihan 1). Menampilkan file .tgz dan folder ROM di penyimpanan HP.
# Dijalankan lewat `source`, jadi tidak memakai set -e, exit, atau trap.

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

# Folder yang dicari, sama seperti MiTool (termux.py): seluruh penyimpanan bersama HP.
# Dibuat oleh termux-setup-storage pada setup.sh.
MENU_DL="$HOME/storage/shared"
# Pesan singkat di bawah layar, misalnya kalau nomor salah
MENU_PESAN=""
# Isi daftar ROM: nama yang tampil, lokasi, dan jenisnya (tgz atau ekstrak)
MENU_NAMA=()
MENU_JALUR=()
MENU_JENIS=()

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

# Satu baris ROM: nomor di kurung, lalu nama ROM di kurung tanpa spasi (contoh: [nama.rom])
baris_rom() {
    printf '%s' "${PUTIH}[  ${ORANYE}$1${PUTIH}  ] ${PUTIH}[${ORANYE}$2${PUTIH}]${RESET}"
}

# Sama seperti MiTool (rom.py): folder ROM dikenali dari ISINYA, bukan dari namanya.
# Folder dianggap ROM fastboot kalau ada folder "images" dan salah satu skrip flash_all*.sh.
cek_folder_rom() {
    local dir="$1" skrip
    [ -d "$dir/images" ] || return 1
    for skrip in flash_all.sh flash_all_lock.sh flash_all_except_data_storage.sh flash_all_except_storage.sh; do
        [ -f "$dir/$skrip" ] && return 0
    done
    return 1
}

# Mengisi daftar: semua file .tgz, lalu semua folder ROM, dicari berulang di dalam MENU_DL.
# Folder bernama Android dilewati, sama seperti MiTool.
muat_daftar() {
    local jalur asli
    MENU_NAMA=()
    MENU_JALUR=()
    MENU_JENIS=()
    [ -d "$MENU_DL" ] || return 0
    # ~/storage/shared adalah symlink. find tidak mengikuti symlink di titik awal,
    # jadi alamat aslinya dipakai supaya isi folder ikut terbaca.
    asli=$(readlink -f "$MENU_DL") || asli="$MENU_DL"
    while IFS= read -r -d '' jalur; do
        MENU_NAMA+=("$(basename "$jalur")")
        MENU_JALUR+=("$jalur")
        MENU_JENIS+=("tgz")
    done < <(find "$asli" -path '*/Android' -prune -o -type f -name '*.tgz' -print0 | sort -z)
    while IFS= read -r -d '' jalur; do
        if cek_folder_rom "$jalur"; then
            MENU_NAMA+=("$(basename "$jalur")")
            MENU_JALUR+=("$jalur")
            MENU_JENIS+=("ekstrak")
        fi
    done < <(find "$asli" -path '*/Android' -prune -o -type d -print0 | sort -z)
}

# Layar FLASH ROM FASTBOOT TGZ: daftar file .tgz dan folder ROM yang sudah diekstrak
gambar_menu_rom() {
    local i ada_tgz=0 ada_ekstrak=0
    clear
    cetak ""
    cetak_logo
    cetak ""
    cetak "${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＦＬＡＳＨ ＲＯＭ ＦＡＳＴＢＯＯＴ ＴＧＺ${RESET}"
    cetak ""

    cetak "${ABU_TEKS}[ROM FASTBOOT BELUM DI EKSTRAK]${RESET}"
    for ((i = 0; i < ${#MENU_NAMA[@]}; i++)); do
        if [ "${MENU_JENIS[i]}" = "tgz" ]; then
            ada_tgz=1
            cetak "$(baris_rom $((i + 1)) "${MENU_NAMA[i]}")"
        fi
    done
    if [ "$ada_tgz" -eq 0 ]; then
        cetak "${ABU_GELAP}  (tidak ada file .tgz)${RESET}"
    fi
    cetak ""

    cetak "${ABU_TEKS}[ROM FASTBOOT SUDAH DI EKSTRAK]${RESET}"
    for ((i = 0; i < ${#MENU_NAMA[@]}; i++)); do
        if [ "${MENU_JENIS[i]}" = "ekstrak" ]; then
            ada_ekstrak=1
            cetak "$(baris_rom $((i + 1)) "${MENU_NAMA[i]}")"
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

# Membaca pilihan sampai pengguna memilih 0 (kembali ke menu utama)
menu_rom() {
    local pilihan
    while true; do
        muat_daftar
        gambar_menu_rom
        printf '%s' "${PUTIH}Pilih nomor, lalu Enter: ${RESET}"
        read -r pilihan || return 0
        MENU_PESAN=""
        case "$pilihan" in
            "")
                ;;
            0)
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

menu_rom
