# Setup Email OTP untuk Duitku

## Cara Kerja

OTP berjalan di **Google Apps Script + GmailApp** (tanpa VPS):
- Apps Script (`server/apps-script/Code.gs`) membuat kode 6 digit, menyimpannya sementara, dan memverifikasinya.
- Email dikirim lewat **GmailApp** dari akun Gmail deployer (kuota sekitar 100 email/hari).
- Aplikasi hanya memanggil URL `/exec` Apps Script. Tidak ada kredensial email di APK.

Panduan lengkap (buat project Apps Script, Script Properties, izin Gmail, deploy Web app) ada di `server/apps-script/README.md`.

### Build aplikasi dengan endpoint OTP

```
flutter build apk --release --no-tree-shake-icons --dart-define=OTP_ENDPOINT=<URL_EXEC> --dart-define=OTP_APP_KEY=<KEY>
```

- `OTP_ENDPOINT`: URL Web app Apps Script (berakhiran `/exec`)
- `OTP_APP_KEY`: nilai yang sama dengan Script Property `APP_KEY`

Jika `OTP_ENDPOINT` tidak diisi, fitur OTP menampilkan "Layanan OTP belum dikonfigurasi." dan tidak melakukan request jaringan.

**PENTING:**
- Jangan commit `OTP_APP_KEY` atau URL berkredensial ke repo publik.
- `APP_KEY` hanya disimpan di Script Properties Apps Script, bukan di kode.

---

## Fitur yang Ditambahkan (v1.7.0)

### 1. **Verifikasi Email saat Register**
- Input nama, email, password
- Sistem kirim OTP 6 digit ke email
- User input OTP (berlaku 5 menit)
- Setelah verifikasi sukses → akun dibuat

### 2. **Reset PIN via Email (Lupa PIN)**
- Di lock screen, tap **"Forgot passcode?"**
- Input email yang terdaftar
- Sistem kirim OTP 6 digit
- Verifikasi OTP → bisa set PIN baru (4-6 digit)

### 3. **OTP Screen**
- Countdown timer 5 menit
- Tombol "Kirim Ulang" setelah timer habis
- Auto-submit saat digit ke-6 diisi
- Desain modern dengan animasi

---

## Testing

### Test Email Verification:
1. Register akun baru dengan email valid
2. Cek inbox email (termasuk folder Spam)
3. Input OTP 6 digit yang dikirim
4. Akun berhasil dibuat

### Test Forgot PIN:
1. Di lock screen, tap "Forgot passcode?"
2. Input email yang sudah terdaftar
3. Cek inbox untuk OTP
4. Input OTP → set PIN baru
5. Login dengan PIN baru

---

## Troubleshooting

### Email OTP tidak terkirim?
1. **Cek koneksi internet**: request butuh internet aktif
2. **Cek Script Properties**: `APP_KEY` harus terisi
3. **Cek izin Gmail**: jalankan `doPost` sekali di editor dan klik Allow
4. **Cek Spam folder**: kadang email masuk Spam
5. **Cek kuota**: GmailApp sekitar 100 email/hari; lihat log Executions di Apps Script

### "Akses ditolak." di aplikasi?
- `OTP_APP_KEY` saat build tidak sama dengan Script Property `APP_KEY`

### "Gagal mengirim email. Coba lagi."?
- Cek log Executions di Apps Script (`GmailApp send failed: ...`) dan izin Gmail

### OTP expired terus?
- Countdown 5 menit mulai dari OTP dibuat
- Pastikan clock HP tidak melenceng jauh

---

## Keamanan

- **OTP 6 digit** random (100.000 - 999.999), dibuat di server
- **Expired 5 menit**: tidak bisa dipakai setelah countdown habis
- **Cooldown 60 detik** per email untuk mencegah spam
- **Maksimal 5 percobaan salah** per kode
- **PIN hashed**: disimpan dengan salted hash, bukan plaintext
- **Email stored**: untuk recovery, tersimpan di database lokal (SQLite)

---

Selamat menggunakan Duitku v1.7.0!
