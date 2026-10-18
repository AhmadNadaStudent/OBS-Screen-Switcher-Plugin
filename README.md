# OBS Auto Screen Switcher (Native Lua)

![OBS Studio](https://img.shields.io/badge/OBS%20Studio-30%2B-blue.svg)
![Language](https://img.shields.io/badge/Language-Lua-000080.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Skrip resmi bawaan **OBS Studio (Lua)** untuk beralih tampilan monitor pada source **Display Capture** secara otomatis mengikuti monitor tempat window yang sedang Anda klik atau fokuskan (`Alt+Tab`).

Contoh kasus penggunaan:
- **Layar 1 (Monitor Utama)**: Gaming / Streaming
- **Layar 2 (Monitor Sekunder)**: Discord / Browser / Chat

Saat Anda mengklik Game di Layar 1 $\rightarrow$ Tampilan Display Capture di OBS seketika menampilkan Layar 1.  
Saat Anda mengklik Discord di Layar 2 $\rightarrow$ Tampilan Display Capture di OBS otomatis beralih menampilkan Layar 2.

---

## ✨ Fitur Unggulan

- **100% Native OBS Studio**: Menggunakan engine LuaJIT bawaan OBS Studio.
- **Zero Dependency**: Tidak memerlukan instalasi Python, compiler, atau package tambahan apapun.
- **Zero Window**: Berjalan senyap di dalam memori OBS tanpa jendela terminal hitam atau file `.bat`.
- **Auto Run**: Otomatis bekerja begitu OBS Studio dibuka, dan otomatis berhenti saat OBS Studio ditutup.
- **Smart Ignore Filter**: Mengabaikan klik pada aplikasi tertentu (seperti `obs64.exe` dan Windows Taskbar) agar tampilan layar tidak berpindah saat Anda sedang mengatur OBS.
- **Beban CPU 0%**: Sangat ringan dengan interval timer 100ms.

---

## 🚀 Cara Pemasangan

1. Unduh file [`obs_screen_switcher.lua`](./obs_screen_switcher.lua).
2. Buka **OBS Studio**.
3. Klik menu **Tools** (Alat) di bilah atas $\rightarrow$ pilih **Scripts**.
4. Di tab **Scripts**, klik tombol **`[+]`** (Tambah) di pojok kiri bawah.
5. Pilih file **`obs_screen_switcher.lua`**.
6. Pada panel sebelah kanan:
   - Pastikan **"Aktifkan Auto Switch"** tercentang.
   - Pilih nama source Display Capture Anda (default: `Display Capture`).
7. **Selesai!** Skrip ini akan tersimpan permanen di OBS Anda dan langsung bekerja secara otomatis.

---

## 🛠️ Persyaratan Sistem

- **Sistem Operasi**: Windows 10 / Windows 11 (64-bit)
- **OBS Studio**: Versi 28.0 ke atas
- Setup multi-monitor (2 monitor atau lebih)

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah [MIT License](./LICENSE).
