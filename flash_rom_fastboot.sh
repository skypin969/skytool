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
# Folder hasil ekstrak terakhir, dipakai untuk langsung membuka pilihan cara flash
EKSTRAK_HASIL=""

# Jumlah baris yang sudah ditulis di layar, dipakai untuk menentukan posisi progres ekstrak
BARIS=0
# Bahasa tampilan mengikuti bahasa perangkat: Indonesia jika bahasanya Indonesia, selain itu Inggris.
# Untuk tes, bisa dipaksa dengan SKYTOOL_BAHASA=id atau SKYTOOL_BAHASA=en.
deteksi_bahasa() {
    local kode="${SKYTOOL_BAHASA:-}"
    if [ -z "$kode" ]; then
        kode=$(getprop persist.sys.locale 2>/dev/null || true)
        [ -z "$kode" ] && kode=$(getprop ro.product.locale 2>/dev/null || true)
        [ -z "$kode" ] && kode="${LANG:-en}"
    fi
    kode=$(printf '%s' "${kode%%[-_.@]*}" | tr 'A-Z' 'a-z')
    case "$kode" in
        id|in) printf 'id' ;;
        *) printf 'en' ;;
    esac
}
BAHASA=$(deteksi_bahasa)

# t "teks Indonesia" "teks Inggris": pilih sesuai BAHASA
t() {
    if [ "$BAHASA" = id ]; then printf '%s' "$1"; else printf '%s' "$2"; fi
}

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

    cetak "${KUNING_REDUP}$(t "[ROM FASTBOOT BELUM DI EKSTRAK]" "[FASTBOOT ROM NOT EXTRACTED]")${RESET}"
    for ((i = 0; i < ${#MENU_NAMA[@]}; i++)); do
        if [ "${MENU_JENIS[i]}" = "tgz" ]; then
            ada_tgz=1
            cetak "$(baris_rom $((i + 1)) "${MENU_NAMA[i]}")"
        fi
    done
    if [ "$ada_tgz" -eq 0 ]; then
        cetak "${ABU_GELAP}  $(t "(tidak ada file .tgz)" "(no .tgz file)")${RESET}"
    fi
    cetak ""

    cetak "${HIJAU_REDUP}$(t "[ROM FASTBOOT SUDAH DI EKSTRAK]" "[FASTBOOT ROM EXTRACTED]")${RESET}"
    for ((i = 0; i < ${#MENU_NAMA[@]}; i++)); do
        if [ "${MENU_JENIS[i]}" = "ekstrak" ]; then
            ada_ekstrak=1
            cetak "$(baris_rom $((i + 1)) "${MENU_NAMA[i]}")"
        fi
    done
    if [ "$ada_ekstrak" -eq 0 ]; then
        cetak "${ABU_GELAP}  $(t "(belum ada)" "(none yet)")${RESET}"
    fi
    cetak ""

    cetak "${ABU_GELAP}[  0  ] [  $(t "kembali" "back")  ]${RESET}"
    cetak ""
    if [ -n "$MENU_PESAN" ]; then
        cetak "$MENU_PESAN"
        cetak ""
    fi
    printf '\033[J'
}

# Menggambar progres ekstrak di bawah daftar ROM (tiga baris, mulai dari posisi kursor yang disimpan)
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
    # Kembali ke posisi kursor yang disimpan di awal ekstrak, lalu hapus isi di bawahnya
    printf '%s8%s[J' "$ESC" "$ESC"
    cetak "${PUTIH}$(t "MENGEKSTRAK: " "EXTRACTING: ")${ORANYE}${nama}${RESET}"
    cetak "${PUTIH}[${bar}${PUTIH}]  [  ${ORANYE}${persen}%${PUTIH}  ]  [  ${ORANYE}$(awk -v a="$selesai_b" -v b="$total_b" 'BEGIN{printf "%.1f GB / %.1f GB", a/1073741824, b/1073741824}')${PUTIH}  ]${RESET}"
    cetak "${PUTIH}[  ${ORANYE}$(awk -v k="$kecepatan" 'BEGIN{printf "%.1f MB/s", k/1048576}')${PUTIH}  ]  [  ${ORANYE}$(t "sisa ± ${sisa} detik" "left ± ${sisa} sec")${PUTIH}  ]${RESET}"
}

# Mengekstrak satu file .tgz ke folder <nama>_extracted di lokasi yang sama, seperti MiTool.
# Argumen: lokasi file .tgz.
ekstrak_rom() {
    local tgz="$1" dir stem dest total salah list rc_file pid mulai sekarang selesai_b rc
    dir=$(dirname "$tgz")
    stem=$(basename "$tgz" .tgz)
    dest="$dir/${stem}_extracted"

    # Langsung tampilkan status, supaya layar tidak terlihat macet saat arsip diperiksa
    printf '%s7' "$ESC"
    printf '%s8%s[J' "$ESC" "$ESC"
    cetak "${PUTIH}$(t "MENGEKSTRAK: " "EXTRACTING: ")${ORANYE}$(basename "$tgz")${RESET}"
    cetak "${PUTIH}$(t "Memeriksa isi arsip, mohon tunggu..." "Checking archive, please wait...")${RESET}"

    # Daftar isi arsip dibaca satu kali. Sekaligus dicek: nama yang keluar dari folder tujuan
    # (berisi .. atau diawali /) tidak boleh dipakai, sama seperti MiTool.
    list=$(mktemp)
    if ! tar -tzvf "$tgz" > "$list" 2>/dev/null; then
        rm -f "$list"
        MENU_PESAN="${MERAH}$(t "File ini tidak bisa dibuka sebagai arsip .tgz." "This file cannot be opened as a .tgz archive.")${RESET}"
        return 1
    fi
    read -r total salah < <(awk '
        {
            s += $3
            n = $0
            for (i = 0; i < 5; i++) sub(/^[ \t]*[^ \t]+/, "", n)
            sub(/^[ \t]+/, "", n)
            if (n ~ /(^|\/)\.\.(\/|$)/ || n ~ /^\//) bad = 1
            if (n ~ / -> /) {
                t = n
                sub(/.* -> /, "", t)
                if (t ~ /^\// || t ~ /(^|\/)\.\.(\/|$)/) bad = 1
            }
        }
        END { print s + 0, bad + 0 }' "$list")
    rm -f "$list"
    if [ "$salah" -eq 1 ]; then
        MENU_PESAN="${MERAH}$(t "Arsip ini punya nama file yang tidak aman, ekstrak dibatalkan." "This archive has unsafe file names, extraction cancelled.")${RESET}"
        return 1
    fi

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
        MENU_PESAN="${MERAH}$(t "Ekstrak gagal. Arsip ini bukan ROM fastboot yang valid." "Extraction failed. This archive is not a valid fastboot ROM.")${RESET}"
        return 1
    fi
    EKSTRAK_HASIL="$dest"
    MENU_PESAN="${PUTIH}[  ${ORANYE}OK${PUTIH}  ] [  ${ORANYE}$(t "ekstrak selesai: " "extraction done: ")$(basename "$dest")${PUTIH}  ]${RESET}"
    return 0
}

# Menampilkan judul layar yang sama dengan layar ROM
judul_layar() {
    clear
    cetak ""
    cetak_logo
    cetak ""
    cetak "${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＦＬＡＳＨ ＲＯＭ ＦＡＳＴＢＯＯＴ ＴＧＺ${RESET}"
    cetak ""
}

# Pilihan cara flash untuk satu folder ROM yang sudah diekstrak.
# Hanya skrip yang benar-benar ada di folder itu yang ditampilkan, seperti MiTool (flash.py).
# Layar proses flash, sama dengan mockup yang disepakati
judul_proses() {
    local folder="$1" nama="$2"
    clear
    cetak ""
    cetak_logo
    cetak ""
    cetak "${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}$(t "ＰＲＯＳＥＳ ＦＬＡＳＨ ＲＯＭ" "ＦＬＡＳＨ ＲＯＭ ＰＲＯＧＲＥＳＳ")${RESET}"
    cetak ""
    cetak "${ABU_TEKS}$(t "ROM: " "ROM: ")${PUTIH}$(basename "$folder")${RESET}"
    cetak "${ABU_TEKS}$(t "Pilihan: " "Option: ")${PUTIH}${nama}${RESET}"
    cetak ""
}

# Proses flash seperti MiTool: tunggu perangkat lewat "fastboot devices" (cek tiap 0,5 detik),
# lalu jalankan skrip flash di folder ROM dengan bash. Keluaran skrip langsung tampil di layar.
proses_flash() {
    local folder="$1" skrip="$2" nama="$3" fb keluar_biasa keluar_semua rc
    local -a bingkai=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    fb=$(type -P fastboot) || fb=""
    if [ -z "$fb" ]; then
        MENU_PESAN="${MERAH}$(t "fastboot tidak ditemukan. Pasang dulu lewat setup." "fastboot not found. Install it through setup first.")${RESET}"
        return 1
    fi
    judul_proses "$folder" "$nama"
    cetak "${PUTIH}Ensure you're in Fastboot mode${RESET}"
    cetak ""
    printf '%s7' "$ESC"
    while true; do
        printf '%s8%s[J' "$ESC" "$ESC"
        keluar_biasa=$(timeout 5 "$fb" devices 2>/dev/null)
        keluar_semua=$(timeout 5 "$fb" devices 2>&1)
        if [[ "${keluar_semua,,}" == *"no permissions"* ]]; then
            cetak "${ORANYE}${bingkai[i]} ${ABU_TEKS}no permission, check USB access${RESET}"
        elif [ -n "$(printf '%s' "$keluar_biasa" | tr -d '[:space:]')" ]; then
            break
        else
            cetak "${ORANYE}${bingkai[i]} ${ABU_TEKS}device not connected...${RESET}"
        fi
        i=$(( (i + 1) % 10 ))
        sleep 0.5
    done

    judul_proses "$folder" "$nama"
    cetak "${HIJAU_REDUP}device connected${RESET}"
    cetak ""
    cetak "${PUTIH}Flashing process will start now...${RESET}"
    cetak ""
    rc=0
    (cd "$folder" && PATH="$(dirname "$fb"):$PATH" bash "$folder/$skrip") || rc=$?
    # Seperti MiTool: setelah skrip selesai tidak ada prompt tambahan, hasilnya langsung dicatat
    if [ "$rc" -eq 0 ]; then
        MENU_PESAN="${HIJAU_REDUP}Flashing complete${RESET}"
    else
        MENU_PESAN="${MERAH}Flashing failed (exit code ${rc})${RESET}"
    fi
    return 0
}

pilih_cara_flash() {
    local folder="$1" pilihan i stem
    local -a skrip=() nama=() ket=()
    while true; do
        skrip=(); nama=(); ket=()
        for stem in flash_all flash_all_lock flash_all_except_data_storage flash_all_except_storage; do
            [ -f "$folder/$stem.sh" ] || continue
            skrip+=("$stem.sh")
            case "$stem" in
                flash_all)
                    nama+=("Flash all"); ket+=("$(t "Bootloader tetap terbuka." "Bootloader stays unlocked.")") ;;
                flash_all_lock)
                    nama+=("$(t "Flash semua + kunci bootloader" "Flash all + lock bootloader")"); ket+=("$(t "Bootloader dikunci lagi setelah flash." "Bootloader is locked again after flashing.")") ;;
                flash_all_except_data_storage)
                    nama+=("$(t "Flash tanpa hapus data" "Flash without wiping data")"); ket+=("$(t "Foto dan aplikasi tetap ada." "Photos and apps are kept.")") ;;
                flash_all_except_storage)
                    nama+=("$(t "Flash tanpa penyimpanan" "Flash without storage")"); ket+=("$(t "Bagian penyimpanan tidak ditulis." "Storage section is not written.")") ;;
            esac
        done

        judul_layar
        cetak "${ABU_TEKS}$(t "ROM dipilih: " "ROM selected: ")${ORANYE}$(basename "$folder")${RESET}"
        cetak ""
        cetak "${ABU_TEKS}$(t "Pilih cara flash:" "Choose flash method:")${RESET}"
        for ((i = 0; i < ${#skrip[@]}; i++)); do
            cetak "$(baris_rom $((i + 1)) "${nama[i]}")"
            cetak "      ${ABU_GELAP}${ket[i]}${RESET}"
        done
        if [ "${#skrip[@]}" -eq 0 ]; then
            cetak "${MERAH}  $(t "(tidak ada skrip flash di folder ini)" "(no flash script in this folder)")${RESET}"
        fi
        cetak ""
        cetak "${ABU_GELAP}[  0  ] [  $(t "kembali" "back")  ]${RESET}"
        cetak ""
        if [ -n "$MENU_PESAN" ]; then
            cetak "$MENU_PESAN"
            cetak ""
        fi
        printf '\033[J'
        printf '%s' "${PUTIH}$(t "Pilih nomor, lalu Enter: " "Choose a number, then Enter: ")${RESET}"
        read -r pilihan || return 0
        MENU_PESAN=""
        case "$pilihan" in
            "")
                ;;
            0)
                return 0
                ;;
            *[!0-9]*)
                MENU_PESAN="${MERAH}$(t "Ketik angka saja." "Type a number only.")${RESET}"
                ;;
            *)
                if [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#skrip[@]}" ]; then
                    proses_flash "$folder" "${skrip[pilihan - 1]}" "${nama[pilihan - 1]}"
                else
                    MENU_PESAN="${MERAH}$(t "Nomor itu tidak ada di daftar." "That number is not in the list.")${RESET}"
                fi
                ;;
        esac
    done
}

# Membaca pilihan sampai pengguna memilih 0 (kembali ke menu utama)
menu_rom() {
    local pilihan
    while true; do
        muat_daftar
        gambar_menu_rom
        printf '%s' "${PUTIH}$(t "Pilih nomor, lalu Enter: " "Choose a number, then Enter: ")${RESET}"
        read -r pilihan || return 0
        MENU_PESAN=""
        case "$pilihan" in
            "")
                ;;
            0)
                return 0
                ;;
            *[!0-9]*)
                MENU_PESAN="${MERAH}$(t "Ketik angka saja." "Type a number only.")${RESET}"
                ;;
            *)
                if [ "$pilihan" -ge 1 ] && [ "$pilihan" -le "${#MENU_NAMA[@]}" ]; then
                    if [ "${MENU_JENIS[pilihan - 1]}" = "tgz" ]; then
                        # Setelah ekstrak selesai, langsung ke pilihan cara flash
                        if ekstrak_rom "${MENU_JALUR[pilihan - 1]}"; then
                            pilih_cara_flash "$EKSTRAK_HASIL"
                        fi
                    else
                        pilih_cara_flash "${MENU_JALUR[pilihan - 1]}"
                    fi
                else
                    MENU_PESAN="${MERAH}$(t "Nomor itu tidak ada di daftar." "That number is not in the list.")${RESET}"
                fi
                ;;
        esac
    done
}

menu_rom
