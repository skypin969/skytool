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
# Judul daftar ROM: kuning dan hijau yang agak redup
KUNING_REDUP="${ESC}[38;2;201;169;68m"
HIJAU_REDUP="${ESC}[38;2;111;176;124m"

# Folder yang dicari, sama seperti MiTool (termux.py): seluruh penyimpanan bersama HP.
# Dibuat oleh termux-setup-storage pada setup.sh.
MENU_DL="$HOME/storage/shared"
# Pesan singkat di bawah layar, misalnya kalau nomor salah
MENU_PESAN=""
# Isi daftar ROM: nama yang tampil, lokasi, dan jenisnya (tgz atau ekstrak)
MENU_NAMA=()
MENU_JALUR=()
MENU_JENIS=()

# Jumlah baris yang sudah ditulis di layar, dipakai untuk menentukan posisi progres ekstrak
BARIS=0
cetak() {
    printf '%s\033[K\n' "$1"
    BARIS=$((BARIS + 1))
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

# Jeda singkat tanpa perintah luar (sama seperti setup.sh)
jeda() {
    read -r -t "$1" _ <> <(:) 2>/dev/null || true
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
    BARIS=0
    cetak ""
    cetak_logo
    cetak ""
    cetak "${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＦＬＡＳＨ ＲＯＭ ＦＡＳＴＢＯＯＴ ＴＧＺ${RESET}"
    cetak ""

    cetak "${KUNING_REDUP}[ROM FASTBOOT BELUM DI EKSTRAK]${RESET}"
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

    cetak "${HIJAU_REDUP}[ROM FASTBOOT SUDAH DI EKSTRAK]${RESET}"
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

# Menggambar progres ekstrak di bawah daftar ROM (tiga baris, mulai di baris PROGRES_BARIS)
gambar_progres() {
    local nama="$1" selesai_b="$2" total_b="$3" detik="$4"
    local persen=0 isi=0 kecepatan=0 sisa=0 bar="" j
    if [ "$total_b" -gt 0 ]; then
        persen=$(( selesai_b * 100 / total_b ))
    fi
    [ "$persen" -gt 100 ] && persen=100
    isi=$(( persen / 10 ))
    for ((j = 0; j < 10; j++)); do
        if [ "$j" -lt "$isi" ]; then
            bar="${bar}${ORANYE}#"
        else
            bar="${bar}${ABU_GELAP}-"
        fi
    done
    if [ "$detik" -gt 0 ]; then
        kecepatan=$(( selesai_b / detik ))
    fi
    if [ "$kecepatan" -gt 0 ]; then
        sisa=$(( (total_b - selesai_b) / kecepatan ))
    fi
    printf '\033[%d;1H' "$PROGRES_BARIS"
    cetak "${PUTIH}MENGEKSTRAK: ${ORANYE}${nama}${RESET}"
    cetak "${PUTIH}[${bar}${PUTIH}]  [  ${ORANYE}${persen}%${PUTIH}  ]  [  ${ORANYE}$(awk -v a="$selesai_b" -v b="$total_b" 'BEGIN{printf "%.1f GB / %.1f GB", a/1073741824, b/1073741824}')${PUTIH}  ]${RESET}"
    cetak "${PUTIH}[  ${ORANYE}$(awk -v k="$kecepatan" 'BEGIN{printf "%.1f MB/s", k/1048576}')${PUTIH}  ]  [  ${ORANYE}sisa ± ${sisa} detik${PUTIH}  ]${RESET}"
}

# Mengekstrak satu file .tgz ke folder <nama>_extracted di lokasi yang sama, seperti MiTool.
# Argumen: lokasi file .tgz, lalu nomor baris tempat progres ditampilkan.
ekstrak_rom() {
    local tgz="$1" dir stem dest total rc_file pid mulai sekarang selesai_b rc f salah=0
    dir=$(dirname "$tgz")
    stem=$(basename "$tgz" .tgz)
    dest="$dir/${stem}_extracted"
    PROGRES_BARIS="$2"

    if ! tar -tzf "$tgz" > /dev/null 2>&1; then
        MENU_PESAN="${MERAH}File ini tidak bisa dibuka sebagai arsip .tgz.${RESET}"
        return 1
    fi
    # Nama file yang keluar dari folder tujuan (berisi .. atau diawali /) tidak boleh dipakai
    while IFS= read -r f; do
        if [[ "$f" == /* || "$f" == *..* ]]; then
            salah=1
            break
        fi
    done < <(tar -tzf "$tgz" 2>/dev/null)
    if [ "$salah" -eq 1 ]; then
        MENU_PESAN="${MERAH}Arsip ini punya nama file yang tidak aman, ekstrak dibatalkan.${RESET}"
        return 1
    fi

    total=$(tar -tzvf "$tgz" 2>/dev/null | awk '{s+=$3} END{print s+0}')
    rm -rf "$dest"
    mkdir -p "$dest"
    rc_file=$(mktemp)
    rm -f "$rc_file"
    # Ekstrak di latar belakang, kode keluarnya ditulis ke rc_file (sama seperti setup.sh)
    ( tar --strip-components=1 -xzf "$tgz" -C "$dest" > /dev/null 2>&1; echo $? > "$rc_file" ) &
    pid=$!
    disown "$pid" 2>/dev/null
    mulai=$(date +%s)
    while [ ! -s "$rc_file" ]; do
        sekarang=$(date +%s)
        selesai_b=$(du -sb "$dest" 2>/dev/null | cut -f1)
        gambar_progres "$(basename "$tgz")" "${selesai_b:-0}" "${total:-0}" "$(( sekarang - mulai ))"
        jeda 0.5
    done
    rc=$(cat "$rc_file")
    rm -f "$rc_file"
    if [ "$rc" -ne 0 ] || ! cek_folder_rom "$dest"; then
        rm -rf "$dest"
        MENU_PESAN="${MERAH}Ekstrak gagal. Arsip ini bukan ROM fastboot yang valid.${RESET}"
        return 1
    fi
    MENU_PESAN="${PUTIH}[  ${ORANYE}OK${PUTIH}  ] [  ${ORANYE}ekstrak selesai: $(basename "$dest")${PUTIH}  ]${RESET}"
    return 0
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
                    if [ "${MENU_JENIS[pilihan - 1]}" = "tgz" ]; then
                        printf '\033[%d;1H\033[J' "$((BARIS + 1))"
                        ekstrak_rom "${MENU_JALUR[pilihan - 1]}" "$((BARIS + 1))"
                    else
                        MENU_PESAN="${ABU_TEKS}Langkah flash untuk pilihan ini belum dibuat.${RESET}"
                    fi
                else
                    MENU_PESAN="${MERAH}Nomor itu tidak ada di daftar.${RESET}"
                fi
                ;;
        esac
    done
}

menu_rom
