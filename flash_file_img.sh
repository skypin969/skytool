#!/data/data/com.termux/files/usr/bin/bash
# SKYTOOL FLASH FILE IMG v9.6.9
# Dibuka dari menu.sh (pilihan 2). Flash satu file .img dari folder Download ke partisi yang dipilih.
# Pilihan partisi: 1 = slot aktif, 1a / 1b = slot tertentu (misalnya boot_b).
# Dijalankan lewat `source`, jadi tidak memakai set -e, exit, atau trap.
VERSI="v9.6.9"
ESC=$'\033'
RESET="${ESC}[0m"
TEBAL="${ESC}[1m"
PUTIH="${ESC}[38;2;255;255;255m"
ORANYE="${ESC}[38;2;255;105;0m"
ABU_TEKS="${ESC}[38;2;170;176;190m"
ABU_GELAP="${ESC}[38;2;122;128;144m"
MERAH="${ESC}[38;2;226;75;74m"
HIJAU_REDUP="${ESC}[38;2;111;176;124m"
# Folder tempat file .img dicari, dan log hasil flash (tidak ditampilkan di layar)
FI_DL="$HOME/storage/shared/Download"
FI_LOG="$HOME/skytool_flash_img.log"
# Pesan singkat di bawah layar, misalnya kalau pilihan salah
FI_PESAN=""
# Slot aktif yang terakhir terbaca dari HP
FI_SLOT=""
# Daftar nama partisi yang dilaporkan HP (satu per baris), dipakai untuk cek slot a/b pada pilihan 5
FI_DAFTAR_PARTISI=""

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
t() {
    if [ "$BAHASA" = id ]; then printf '%s' "$1"; else printf '%s' "$2"; fi
}
cetak() {
    printf '%s\033[K\n' "$1"
}
cetak_logo() {
    cetak "${TEBAL}${PUTIH}░█▀▀░█░█░█░█${ORANYE}░▀█▀░█▀█░█▀█░█░░${RESET}"
    cetak "${TEBAL}${PUTIH}░▀▀█░█▀▄░░█░${ORANYE}░░█░░█░█░█░█░█░░${RESET}"
    cetak "${TEBAL}${PUTIH}░▀▀▀░▀░▀░░▀░${ORANYE}░░▀░░▀▀▀░▀▀▀░▀▀▀${RESET}"
}

# Header layar: logo, versi, judul, dan slot aktif
fi_judul() {
    clear
    cetak ""
    cetak_logo
    cetak ""
    cetak "${ABU_TEKS}${VERSI}${RESET}"
    cetak ""
    cetak "${TEBAL}${ORANYE}ＰＡＲＴＩＳＩ ＦＩＬＥ ＩＭＧ${RESET}"
    cetak ""
    if [ -n "$FI_SLOT" ]; then
        cetak "${ABU_TEKS}$(t "Slot aktif: " "Active slot: ")${PUTIH}${FI_SLOT}${RESET}"
    else
        cetak "${ABU_GELAP}$(t "Slot aktif: tidak terbaca" "Active slot: not readable")${RESET}"
    fi
    cetak ""
}

# Membaca slot aktif lewat "fastboot getvar current-slot". Hanya membaca, tidak mengubah HP.
fi_baca_slot() {
    local fb="$1" keluar
    keluar=$(timeout 5 "$fb" getvar current-slot 2>&1)
    printf '%s' "$keluar" | grep -oP 'current-slot: \K[^ \r]+' | head -n 1
}

# Membaca daftar nama partisi dari "fastboot getvar all". Hanya membaca, tidak mengubah HP.
fi_baca_partisi() {
    local fb="$1" keluar
    keluar=$(timeout 10 "$fb" getvar all 2>&1)
    printf '%s' "$keluar" | grep -oP 'partition-size:\K[^: \r]+' | sort -u
}

# Menunggu HP dalam mode fastboot, lalu membaca slot aktifnya. Layar ditimpa tanpa berkedip.
fi_tunggu_slot() {
    local fb="$1" slot="" i=0
    local -a bingkai=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    fi_judul
    printf '%s7' "$ESC"
    while true; do
        printf '%s8%s[J' "$ESC" "$ESC"
        slot=$(fi_baca_slot "$fb")
        if [ -n "$slot" ]; then
            FI_SLOT="$slot"
            return 0
        fi
        cetak "${ORANYE}${bingkai[i]} ${ABU_TEKS}$(t "menunggu HP dalam mode fastboot..." "waiting for phone in fastboot mode...")${RESET}"
        i=$(( (i + 1) % 10 ))
        sleep 0.5
    done
}

# Satu baris menu dengan lebar tetap, supaya tanda ] di setiap baris sejajar
fi_baris() {
    local warna="$1" nomor="$2" nama="$3"
    cetak "${warna}$(printf '[ %2s ] [ %-16s ]' "$nomor" "$nama")${RESET}"
}

# Daftar partisi, lalu pilihan dibaca. Hasil: target (misalnya boot atau boot_b) lewat FI_TARGET
fi_gambar_partisi() {
    fi_judul
    fi_baris "$PUTIH" 1 boot
    fi_baris "$PUTIH" 2 init_boot
    fi_baris "$PUTIH" 3 vendor_boot
    fi_baris "$PUTIH" 4 recovery
    fi_baris "$PUTIH" 5 "$(t "lainnya" "other")"
    cetak ""
    fi_baris "$ABU_GELAP" 0 "$(t "kembali" "back")"
    cetak ""
    cetak "${ABU_GELAP}$(t "Tambah a atau b untuk slot tertentu, misalnya 1b" "Add a or b for a specific slot, for example 1b")${RESET}"
    cetak "${ABU_GELAP}$(t "Partisi lain: ketik 5 lalu namanya, misalnya 5super" "Other partition: type 5 then its name, for example 5super")${RESET}"
    cetak ""
    if [ -n "$FI_PESAN" ]; then
        cetak "$FI_PESAN"
        cetak ""
    fi
    printf '%s' "${PUTIH}$(t "Pilih nomor, lalu Enter: " "Choose a number, then Enter: ")${RESET}"
}

# Mengubah pilihan seperti 1, 1a, atau 1b menjadi nama partisi. Gagal kalau bentuknya salah.
fi_ubah_pilihan() {
    local pil="${1,,}" nomor akhiran bagian
    # 5 diikuti nama partisi, misalnya 5super -> partisi "super" (nama harus huruf, angka, atau _)
    if [[ "$pil" == 5?* ]]; then
        local nama="${pil:1}" dasar
        [[ "$nama" =~ ^[a-z0-9_]+$ ]] || return 1
        # Akhiran _a atau _b hanya boleh kalau partisi dasarnya punya kedua slot di HP
        if [[ "$nama" == *_a || "$nama" == *_b ]]; then
            dasar="${nama%_?}"
            if [ -n "$FI_DAFTAR_PARTISI" ] && ! { grep -qx "${dasar}_a" <<<"$FI_DAFTAR_PARTISI" && grep -qx "${dasar}_b" <<<"$FI_DAFTAR_PARTISI"; }; then
                FI_PESAN="${MERAH}$(t "Partisi ${dasar} tidak punya slot a/b. Ketik 5${dasar} saja." "Partition ${dasar} has no a/b slots. Type 5${dasar} only.")${RESET}"
                return 1
            fi
        fi
        FI_TARGET="$nama"
        return 0
    fi
    nomor="${pil:0:1}"
    akhiran="${pil:1}"
    case "$nomor" in
        1) bagian=boot ;;
        2) bagian=init_boot ;;
        3) bagian=vendor_boot ;;
        4) bagian=recovery ;;
        *) return 1 ;;
    esac
    case "$akhiran" in
        "") FI_TARGET="$bagian" ;;
        a|b) FI_TARGET="${bagian}_${akhiran}" ;;
        *) return 1 ;;
    esac
    return 0
}

# Daftar file .img di folder Download, lalu nama file diketik. Hasil: FI_FILE (nama) dan FI_PATH
fi_pilih_file() {
    local target="$1" nama f
    local -a daftar=()
    fi_judul
    cetak "${ABU_TEKS}Folder: ${PUTIH}Download${RESET}"
    cetak ""
    if [ ! -d "$FI_DL" ]; then
        cetak "${MERAH}$(t "Folder Download belum bisa dibaca. Jalankan termux-setup-storage dulu." "Download folder cannot be read yet. Run termux-setup-storage first.")${RESET}"
    else
        while IFS= read -r f; do
            daftar+=("$f")
        done < <( ( shopt -s nullglob nocaseglob; for f in "$FI_DL"/*.img; do basename "$f"; done ) | sort )
        if [ "${#daftar[@]}" -eq 0 ]; then
            cetak "${ABU_GELAP}$(t "(tidak ada file .img di folder Download)" "(no .img file in Download folder)")${RESET}"
        else
            cetak "${ABU_TEKS}$(t "File .img yang ada:" "Available .img files:")${RESET}"
            for f in "${daftar[@]}"; do
                cetak "${PUTIH}  ${f}${RESET}"
            done
        fi
    fi
    cetak ""
    fi_baris "$ABU_GELAP" 0 "$(t "kembali" "back")"
    cetak ""
    printf '%s' "${PUTIH}$(t "Ketik nama file, lalu Enter: " "Type the file name, then Enter: ")${RESET}"
    read -r nama || return 1
    case "$nama" in
        ""|0) return 1 ;;
        */*) FI_PESAN="${MERAH}$(t "Ketik nama file saja, tanpa folder." "Type the file name only, without a folder.")${RESET}"; return 1 ;;
    esac
    if [ ! -f "$FI_DL/$nama" ] || [[ "${nama,,}" != *.img ]]; then
        FI_PESAN="${MERAH}$(t "File itu tidak ada di folder Download." "That file is not in the Download folder.")${RESET}"
        return 1
    fi
    FI_FILE="$nama"
    FI_PATH="$FI_DL/$nama"
    return 0
}

# Menjalankan flash. Perintah dan keluarannya disimpan di log, tidak ditampilkan di layar.
fi_flash() {
    local fb="$1" target="$2" path="$3" nama="$4" rc=0 keluar
    keluar=$("$fb" flash "$target" "$path" 2>&1) || rc=$?
    {
        echo "== fastboot flash $target $path (kode $rc)"
        printf '%s\n' "$keluar"
    } >> "$FI_LOG"
    FI_SLOT_BARU=$(fi_baca_slot "$fb")
    fi_judul
    cetak "${TEBAL}${ORANYE}$(t "HASIL FLASH" "FLASH RESULT")${RESET}"
    cetak ""
    cetak "${ABU_TEKS}$(t "Partisi : " "Partition: ")${PUTIH}${target}${RESET}"
    cetak "${ABU_TEKS}File    : ${PUTIH}${nama}${RESET}"
    cetak ""
    if [ "$rc" -eq 0 ]; then
        cetak "${HIJAU_REDUP}[ OK ] $(t "berhasil di-flash" "flashed successfully")${RESET}"
    else
        cetak "${MERAH}[ !! ] $(t "gagal (kode ${rc})" "failed (code ${rc})")${RESET}"
        printf '%s\n' "$keluar" | grep -i -E 'fail|error' | head -n 2 | while IFS= read -r baris; do
            cetak "${MERAH}${baris}${RESET}"
        done
    fi
    cetak ""
    if [ -n "$FI_SLOT_BARU" ]; then
        FI_SLOT="$FI_SLOT_BARU"
    fi
    # Kalau partisi memakai akhiran _a/_b, slot tujuannya itu; kalau tidak, slot aktif
    local slot_flash
    if [[ "$target" == *_a || "$target" == *_b ]]; then
        slot_flash="${target: -1}"
    else
        slot_flash="${FI_SLOT:-?}"
    fi
    cetak "${ABU_TEKS}Flash file slot: ${PUTIH}${slot_flash}${RESET}"
    cetak ""
    cetak "${ABU_GELAP}Log: ~/skytool_flash_img.log${RESET}"
    cetak ""
    if [ "$rc" -ne 0 ]; then
        printf '%s' "${PUTIH}$(t "Tekan Enter untuk kembali." "Press Enter to go back.")${RESET}"
        read -r _ || true
        return 1
    fi
    fi_menu_setelah_flash "$fb"
}

# Menu setelah flash berhasil. Return 0 kalau perangkat di-reboot (keluar ke menu utama),
# 1 kalau kembali ke daftar partisi (pilihan 0 atau Enter).
fi_menu_setelah_flash() {
    local fb="$1" pil
    cetak ""
    fi_baris "$PUTIH" 1 "$(t "Reboot perangkat" "Reboot device")"
    fi_baris "$PUTIH" 2 "$(t "Reboot recovery" "Reboot recovery")"
    cetak ""
    fi_baris "$ABU_GELAP" 0 "$(t "kembali" "back")"
    cetak ""
    while true; do
        printf '%s' "${PUTIH}$(t "Pilih nomor, lalu Enter: " "Choose a number, then Enter: ")${RESET}"
        read -r pil || return 1
        case "$pil" in
            1) "$fb" reboot >> "$FI_LOG" 2>&1; return 0 ;;
            2) "$fb" reboot recovery >> "$FI_LOG" 2>&1; return 0 ;;
            0|"") return 1 ;;
            *) cetak "${MERAH}$(t "Pilihan itu tidak ada. Ketik 1, 2, atau 0." "That choice does not exist. Type 1, 2, or 0.")${RESET}" ;;
        esac
    done
}

buka_flash_img() {
    local fb pilihan
    fb=$(type -P fastboot) || fb=""
    if [ -z "$fb" ]; then
        fi_judul
        cetak "${MERAH}$(t "fastboot belum ada. Jalankan setup dulu." "fastboot is not installed. Run setup first.")${RESET}"
        cetak ""
        printf '%s' "${PUTIH}$(t "Tekan Enter untuk kembali." "Press Enter to go back.")${RESET}"
        read -r _ || true
        return 0
    fi
    fi_tunggu_slot "$fb"
    FI_DAFTAR_PARTISI=$(fi_baca_partisi "$fb")
    while true; do
        fi_gambar_partisi
        read -r pilihan || return 0
        FI_PESAN=""
        case "$pilihan" in
            ""|0) return 0 ;;
        esac
        if ! fi_ubah_pilihan "$pilihan"; then
            [ -z "$FI_PESAN" ] && FI_PESAN="${MERAH}$(t "Pilihan itu tidak ada. Contoh: 1, 1a, 1b, atau 5super." "That choice does not exist. Examples: 1, 1a, 1b, or 5super.")${RESET}"
            continue
        fi
        if fi_pilih_file "$FI_TARGET"; then
            # Setelah reboot, keluar ke menu utama. Kalau tidak, kembali ke daftar partisi.
            fi_flash "$fb" "$FI_TARGET" "$FI_PATH" "$FI_FILE" && return 0
            fi_tunggu_slot "$fb"
        fi
    done
}

buka_flash_img
