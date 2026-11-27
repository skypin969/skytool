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
# Diisi 1 setelah proses flash selesai: menu berhenti dan hasil tetap terlihat, seperti MiTool
SKYTOOL_SELESAI=""

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
    for skrip in flash_all.sh flash_all_lock.sh flash_all_except_data_storage.sh; do
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
    # Kembali ke posisi kursor yang disimpan, lalu timpa baris progres (tanpa menghapus layar: tidak berkedip)
    printf '%s8' "$ESC"
    cetak "${PUTIH}$(t "MENGEKSTRAK: " "EXTRACTING: ")${ORANYE}${nama}${RESET}"
    # Satu baris kosong antara nama arsip dan bar progres
    cetak ""
    cetak "${PUTIH}[${bar}${PUTIH}]  [  ${ORANYE}${persen}%${PUTIH}  ]  [  ${ORANYE}$(awk -v a="$selesai_b" -v b="$total_b" 'BEGIN{printf "%.1f GB / %.1f GB", a/1073741824, b/1073741824}')${PUTIH}  ]${RESET}"
    cetak "${PUTIH}[  ${ORANYE}$(awk -v k="$kecepatan" 'BEGIN{printf "%.1f MB/s", k/1048576}')${PUTIH}  ]  [  ${ORANYE}$(t "sisa ± ${sisa} detik" "left ± ${sisa} sec")${PUTIH}  ]${RESET}"
    # Satu baris kosong di bawah progres
    cetak ""
}

# Mengekstrak satu file .tgz ke folder <nama>_extracted di lokasi yang sama, seperti MiTool.
# Argumen: lokasi file .tgz.
# Kursor disembunyikan selama ekstrak supaya tidak ada kotak putih yang berkedip di bawah progres
ekstrak_rom() {
    local hasil
    printf '\033[?25l'
    ekstrak_rom_inti "$@"
    hasil=$?
    printf '\033[?25h'
    return $hasil
}

ekstrak_rom_inti() {
    local tgz="$1" dir stem dest total salah list rc_file pid mulai sekarang selesai_b rc
    dir=$(dirname "$tgz")
    stem=$(basename "$tgz" .tgz)
    dest="$dir/${stem}_extracted"

    # Langsung tampilkan status, supaya layar tidak terlihat macet saat arsip diperiksa
    # Satu baris kosong di atas, lalu posisi disimpan di bawahnya supaya progres tidak menimpa baris kosong itu
    cetak ""
    printf '%s7' "$ESC"
    printf '%s[J' "$ESC"
    cetak "${PUTIH}$(t "MENGEKSTRAK: " "EXTRACTING: ")${ORANYE}$(basename "$tgz")${RESET}"
    cetak ""
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
    MENU_PESAN="${PUTIH}[ ${ORANYE}OK${PUTIH} ] [${ORANYE}$(t "ekstrak selesai" "extraction done")${PUTIH}]: ${ORANYE}$(basename "$dest")${RESET}"
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
    cetak "${TEBAL}${ORANYE}$(t "ＰＲＯＳＥＳ ＦＬＡＳＨ ＲＯＭ" "ＰＲＯＣＥＳＳ ＦＬＡＳＨ ＲＯＭ")${RESET}"
    cetak ""
    cetak "${ABU_TEKS}$(t "ROM: " "ROM: ")${PUTIH}$(basename "$folder")${RESET}"
    cetak "${ABU_TEKS}$(t "Pilihan: " "Option: ")${PUTIH}${nama}${RESET}"
    cetak ""
}

# Proses flash seperti MiTool: tunggu perangkat lewat "fastboot devices" (cek tiap 0,5 detik),
# lalu jalankan skrip flash di folder ROM dengan bash. Keluaran skrip langsung tampil di layar.
# Kalau fastboot belum ada, pasang termux-adb (sekali saja), sama seperti MiTool di Termux
pasang_fastboot_otomatis() {
    local prefix="${PREFIX:-/data/data/com.termux/files/usr}"
    if [ ! -f "$prefix/etc/apt/sources.list.d/termux-adb.list" ]; then
        mkdir -p "$prefix/etc/apt/sources.list.d" "$prefix/etc/apt/trusted.gpg.d"
        echo "deb https://nohajc.github.io termux extras" > "$prefix/etc/apt/sources.list.d/termux-adb.list"
        curl -fsSL -o "$prefix/etc/apt/trusted.gpg.d/nohajc.gpg" https://nohajc.github.io/nohajc.gpg || return 1
        yes | apt update > /dev/null 2>&1
    fi
    DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install termux-adb < /dev/null > /dev/null 2>&1 || return 1
    ln -sf "$prefix/bin/termux-fastboot" "$prefix/bin/fastboot"
    ln -sf "$prefix/bin/termux-adb" "$prefix/bin/adb"
}

proses_flash() {
    local folder="$1" skrip="$2" nama="$3" fb keluar_biasa keluar_semua rc
    local -a bingkai=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    fb=$(type -P fastboot) || fb=""
    judul_proses "$folder" "$nama"
    if [ -z "$fb" ]; then
        cetak "$(t "fastboot belum ada, memasang termux-adb..." "fastboot not found, installing termux-adb...")"
        cetak ""
        if pasang_fastboot_otomatis; then
            hash -r
            fb=$(type -P fastboot) || fb=""
        fi
        judul_proses "$folder" "$nama"
    fi
    if [ -z "$fb" ]; then
        MENU_PESAN="${MERAH}$(t "fastboot gagal dipasang. Coba jalankan lagi setup." "fastboot could not be installed. Try running setup again.")${RESET}"
        return 1
    fi
    cetak "${PUTIH}Ensure you're in Fastboot mode${RESET}"
    cetak ""
    printf '%s7' "$ESC"
    while true; do
        printf '%s8%s[J' "$ESC" "$ESC"
        keluar_biasa=$(timeout 5 "$fb" devices 2>/dev/null)
        keluar_semua=$(timeout 5 "$fb" devices 2>&1)
        if [[ "${keluar_semua,,}" == *"no permissions"* ]]; then
            cetak "${ORANYE}${bingkai[i]} ${ABU_TEKS}$(t "Izin USB belum diberikan. Izinkan akses di HP, lalu tunggu." "USB permission not granted. Allow access on the phone, then wait.")${RESET}"
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
    tampil_flash "$folder" "$folder/$skrip" "$fb" "$nama" || rc=$?
    # Seperti MiTool: setelah skrip selesai tidak ada prompt tambahan, hasilnya langsung dicatat
    cetak ""
    if [ "$rc" -eq 0 ]; then
        cetak "${HIJAU_REDUP}Flashing complete${RESET}"
    else
        cetak "${MERAH}Flashing failed (exit code ${rc})${RESET}"
    fi
    # Hasil tetap di layar: menu tidak digambar ulang dan tidak kembali ke daftar
    SKYTOOL_SELESAI=1
    return 0
}

# ===== Tampilan flashing untuk Termux (gaya sama dengan layar ekstrak di flash_rom_fastboot.sh) =====
# Hanya tampilan. Script flash ROM dijalankan apa adanya; outputnya dibaca lalu digambar ulang.
# Daftar tahap dibaca dari script flash (erase, flash, set_active, oem, reboot), jadi berlaku untuk ROM lain juga.

# Membaca tahap dari script: keluarannya "jenis<TAB>nama", satu baris per tahap
_fl_parse() {
    grep -E '^[[:space:]]*fastboot \$\* (flash|erase|set_active|oem|reboot)([[:space:]]|$)' "$1" \
        | grep -v '2>&1' \
        | awk '{
            if ($3 == "flash" || $3 == "erase") print $3 "\t" $4
            else { nm = $3; if ($4 != "") nm = nm " " $4; print "finish\t" nm }
        }' \
        | awk -F'\t' '!seen[$0]++'
}

# Mencari nomor tahap: $1 = jenis, $2 = nama (untuk finish cukup awalan namanya)
_fl_cari() {
    local j
    for ((j = 0; j < _fl_n; j++)); do
        [ "${_fl_jenis[j]}" = "$1" ] || continue
        if [ "$1" = finish ]; then
            [[ "${_fl_nama[j]}" == "$2"* ]] || continue
        else
            [ "${_fl_nama[j]}" = "$2" ] || continue
        fi
        echo "$j"
        return
    done
}

# Tahap bersyarat (misalnya crclist) yang dilewati script tidak akan pernah dicetak fastboot.
# Saat tahap berikutnya mulai, tahap sejenis yang masih "menunggu" di depannya ditandai dilewati.
_fl_lewati_sebelum() {
    local j
    for ((j = 0; j < $2; j++)); do
        if [ "${_fl_jenis[j]}" = "${_fl_jenis[$2]}" ] && [ "${_fl_stat[j]}" = wait ]; then
            _fl_stat[j]=skip
        fi
    done
}

# Membaca satu baris output fastboot/script lalu memperbarui status tahap
_fl_proses() {
    local line="$1" re idx act
    re="^(Erasing|Sending|Writing) (sparse )?'([^']+)'( ([0-9]+)/([0-9]+))?"
    if [[ "$line" =~ $re ]]; then
        act=${BASH_REMATCH[1]}
        _fl_curj=flash
        [ "$act" = Erasing ] && _fl_curj=erase
        _fl_cur=${BASH_REMATCH[3]}
        if [ -n "${BASH_REMATCH[5]}" ]; then
            _fl_chunk="${BASH_REMATCH[5]}/${BASH_REMATCH[6]}"
        fi
        [ "$act" = Erasing ] && _fl_chunk=""
        idx=$(_fl_cari "$_fl_curj" "$_fl_cur")
        if [ -n "$idx" ] && [ "${_fl_stat[idx]}" = wait ]; then
            _fl_lewati_sebelum "$_fl_curj" "$idx"
            _fl_stat[idx]=run
        fi
    elif [[ "$line" == "Setting current slot"* ]]; then
        _fl_curj=finish; _fl_cur=set_active; _fl_chunk=""
    elif [[ "$line" == "Rebooting"* ]]; then
        _fl_curj=finish; _fl_cur=reboot; _fl_chunk=""
    elif [[ "$line" == "Finished."* ]]; then
        if [ -n "$_fl_cur" ]; then
            idx=$(_fl_cari "$_fl_curj" "$_fl_cur")
            if [ -n "$idx" ]; then _fl_stat[idx]=done; fi
        fi
        _fl_cur=""; _fl_chunk=""
    elif [[ "$line" =~ ^No\ partition\ ([^[:space:]]+)\ found ]]; then
        idx=$(_fl_cari erase "${BASH_REMATCH[1]}")
        if [ -n "$idx" ]; then _fl_stat[idx]=skip; fi
    elif [[ "$line" == *FAILED* || "$line" == *error* ]]; then
        _fl_gagal="$line"
        if [ -n "$_fl_cur" ]; then
            idx=$(_fl_cari "$_fl_curj" "$_fl_cur")
            if [ -n "$idx" ]; then _fl_stat[idx]=fail; fi
        fi
    fi
}

# Satu baris status ala menu: [ OK ] [nama]
_fl_baris() {
    local tanda warna
    case "$1" in
        done) tanda="OK"; warna="$HIJAU_REDUP" ;;
        run) tanda=">>"; warna="$ORANYE" ;;
        fail) tanda="!!"; warna="$MERAH" ;;
        skip) tanda="--"; warna="$ABU_GELAP" ;;
        *) tanda="  "; warna="$ABU_GELAP" ;;
    esac
    printf '%s' "${PUTIH}[ ${warna}${tanda}${PUTIH} ] [${warna}$2${PUTIH}]${RESET}"
}

# Menggambar layar flashing. Gaya dan urutan sama dengan layar ekstrak (judul, bar 10 kotak, dua baris info).
_fl_gambar() {
    local j i bar="" persen=0 isi=0 dn=0 nF=0 dF=0 fc=-1 lo hi k sisa=0 detik extra
    _fl_fidx=()
    local nE=0 dE=0 nS=0 dS=0
    for ((j = 0; j < _fl_n; j++)); do
        case "${_fl_stat[j]}" in done|skip) dn=$((dn + 1)) ;; esac
        case "${_fl_jenis[j]}" in
            flash)
                _fl_fidx[nF]=$j
                case "${_fl_stat[j]}" in
                    done|skip) dF=$((dF + 1)) ;;
                    run) fc=$nF ;;
                esac
                nF=$((nF + 1))
                ;;
            erase)
                nE=$((nE + 1))
                case "${_fl_stat[j]}" in done|skip) dE=$((dE + 1)) ;; esac
                ;;
            finish)
                nS=$((nS + 1))
                case "${_fl_stat[j]}" in done|skip) dS=$((dS + 1)) ;; esac
                ;;
        esac
    done
    [ "$fc" -lt 0 ] && fc=$dF
    [ "$fc" -ge "$nF" ] && fc=$((nF - 1))

    if [ "$_fl_n" -gt 0 ]; then persen=$(( dn * 100 / _fl_n )); fi
    isi=$(( persen / 10 ))
    for ((i = 0; i < 10; i++)); do
        if [ "$i" -lt "$isi" ]; then bar="${bar}${ORANYE}#"; else bar="${bar}${ABU_GELAP}-"; fi
    done
    detik=$(( SECONDS - _fl_mulai ))
    if [ "$dn" -gt 0 ] && [ "$_fl_n" -gt "$dn" ]; then
        sisa=$(( detik * (_fl_n - dn) / dn ))
    fi

    # Kembali ke posisi setelah header, lalu timpa bagian bawah (tanpa menghapus layar: tidak berkedip)
    printf '%s8' "$ESC"
    printf '\033[J'
    cetak "${PUTIH}[${bar}${PUTIH}]  [  ${ORANYE}${persen}%${PUTIH}  ]${RESET}"
    cetak "${PUTIH}[  ${ORANYE}$(t "tahap ${dn} dari ${_fl_n}" "step ${dn} of ${_fl_n}")${PUTIH}  ]  [  ${ORANYE}$(t "sisa ± ${sisa} detik" "left ± ${sisa} sec")${PUTIH}  ]${RESET}"
    cetak ""

    if [ -n "$_fl_gagal" ]; then
        cetak "${MERAH}$(t "GAGAL: " "FAILED: ")${_fl_gagal:0:40}${RESET}"
    elif [ "$_fl_selesai" = 1 ]; then
        cetak "${HIJAU_REDUP}$(t "SELESAI" "COMPLETE")${RESET}"
    else
        extra=""
        [ -n "$_fl_chunk" ] && extra="  ${_fl_chunk}"
        if [ -n "$_fl_cur" ]; then
            cetak "${PUTIH}$(t "SEKARANG: " "NOW: ")${ORANYE}${_fl_cur}${ABU_TEKS}${extra}${RESET}"
        else
            cetak ""
        fi
    fi
    cetak ""

    cetak "${KUNING_REDUP}$(t "[HAPUS DATA] ${dE}/${nE}" "[ERASE] ${dE}/${nE}")${RESET}"
    cetak ""
    cetak "${KUNING_REDUP}$(t "[FLASH IMAGE] ${dF}/${nF}" "[FLASH IMAGES] ${dF}/${nF}")${RESET}"
    lo=$((fc - 2)); [ "$lo" -lt 0 ] && lo=0
    hi=$((fc + 2)); [ "$hi" -ge "$nF" ] && hi=$((nF - 1))
    for ((j = lo; j <= hi; j++)); do
        k=${_fl_fidx[j]}
        cetak "  $(_fl_baris "${_fl_stat[k]}" "${_fl_nama[k]}")"
    done
    cetak ""
    cetak "${KUNING_REDUP}$(t "[SELESAI] ${dS}/${nS}" "[FINISH] ${dS}/${nS}")${RESET}"
    cetak ""
    cetak "${ABU_GELAP}$(t "Log: ~/skytool_flash.log" "Log: ~/skytool_flash.log")${RESET}"
    printf '\033[J'
}

# Menjalankan script flash dan menampilkannya. Kode keluar script tetap dikembalikan apa adanya.
tampil_flash() {
    local folder="$1" skrip="$2" fb="$3" pilihan="$4" rc=0 line k nm j
    _fl_rom=$(basename "$folder")
    _fl_mulai=$SECONDS
    : > "$HOME/skytool_flash.log"
    _fl_n=0; _fl_nama=(); _fl_jenis=(); _fl_stat=()
    while IFS=$'\t' read -r k nm; do
        _fl_jenis[_fl_n]=$k
        _fl_nama[_fl_n]=$nm
        _fl_stat[_fl_n]=wait
        _fl_n=$((_fl_n + 1))
    done < <(_fl_parse "$skrip")
    _fl_cur=""; _fl_curj=""; _fl_chunk=""; _fl_gagal=""; _fl_selesai=0
    # Header sama dengan layar proses di atas (logo, versi, PROSES FLASH ROM); posisi setelahnya disimpan
    judul_proses "$folder" "$pilihan"
    printf '%s7' "$ESC"
    _fl_gambar
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%$'\r'}
        if [[ "$line" == __RC=* ]]; then
            rc=${line#__RC=}
            continue
        fi
        printf '%s\n' "$line" >> "$HOME/skytool_flash.log"
        _fl_proses "$line"
        _fl_gambar
    done < <( (cd "$folder" && PATH="$(dirname "$fb"):$PATH" bash "$skrip" 2>&1); echo "__RC=$?" )

    if [ "$rc" -eq 0 ]; then
        _fl_selesai=1
        for ((j = 0; j < _fl_n; j++)); do
            if [ "${_fl_stat[j]}" = wait ]; then
                case "${_fl_jenis[j]}" in
                    finish) _fl_stat[j]=done ;;
                    *) _fl_stat[j]=skip ;;
                esac
            fi
        done
    elif [ -z "$_fl_gagal" ]; then
        _fl_gagal="exit code $rc"
    fi
    _fl_gambar
    return "$rc"
}

pilih_cara_flash() {
    local folder="$1" pilihan i stem
    local -a skrip=() nama=() ket=()
    while true; do
        skrip=(); nama=(); ket=()
        for stem in flash_all flash_all_lock flash_all_except_data_storage; do
            [ -f "$folder/$stem.sh" ] || continue
            skrip+=("$stem.sh")
            case "$stem" in
                flash_all)
                    nama+=("Flash all"); ket+=("$(t "Bootloader tetap terbuka, data terhapus." "Bootloader stays unlocked, data is wiped.")") ;;
                flash_all_lock)
                    nama+=("$(t "Flash semua + kunci bootloader" "Flash all + lock bootloader")"); ket+=("$(t "Bootloader dikunci lagi, data terhapus." "Bootloader locked again, data wiped.")") ;;
                flash_all_except_data_storage)
                    nama+=("$(t "Flash tanpa hapus data" "Flash without wiping data")"); ket+=("$(t "Data tidak terhapus setelah flash." "Data is not wiped after flashing.")") ;;
            esac
        done

        judul_layar
        cetak "${ABU_TEKS}$(t "ROM dipilih: " "ROM selected: ")${ORANYE}$(basename "$folder")${RESET}"
        cetak ""
        cetak "${ABU_TEKS}$(t "Pilih cara flash:" "Choose flash method:")${RESET}"
        cetak ""
        for ((i = 0; i < ${#skrip[@]}; i++)); do
            cetak "$(baris_rom $((i + 1)) "${nama[i]}")"
            printf '%s\n' "${ket[i]}" | while IFS= read -r baris; do
                cetak "      ${ABU_GELAP}${baris}${RESET}"
            done
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
                    [ -n "$SKYTOOL_SELESAI" ] && return 0
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
                    [ -n "$SKYTOOL_SELESAI" ] && return 0
                else
                    MENU_PESAN="${MERAH}$(t "Nomor itu tidak ada di daftar." "That number is not in the list.")${RESET}"
                fi
                ;;
        esac
    done
}

menu_rom
