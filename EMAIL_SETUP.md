# Setup Email OTP untuk Duitku

## 📧 Cara Setup Gmail SMTP

Aplikasi Duitku menggunakan **Gmail SMTP** untuk kirim OTP verifikasi email (saat register & reset PIN).

### Langkah Setup:

#### 1. Buat/Gunakan Akun Gmail
- Bisa pakai Gmail pribadi atau buat akun baru khusus untuk app
- Rekomendasikan buat Gmail baru (misalnya: `duitku.otp@gmail.com`)

#### 2. Aktifkan 2-Step Verification
1. Buka https://myaccount.google.com/security
2. Cari **2-Step Verification** → Klik **Turn On**
3. Ikuti langkah verifikasi (SMS/Phone)

#### 3. Generate App Password
1. Buka https://myaccount.google.com/apppasswords
2. Pilih app: **Mail**
3. Pilih device: **Other (Custom name)** → ketik `Duitku App`
4. Klik **Generate**
5. Copy **16-character password** yang muncul (format: `xxxx xxxx xxxx xxxx`)

#### 4. Update File `email_service.dart`
Buka file `lib/services/email_service.dart` dan edit baris berikut:

```dart
// SEBELUM (default):
static const String _senderEmail = 'your-email@gmail.com';
static const String _appPassword = 'your-16-char-app-password';

// SESUDAH (isi dengan data lo):
static const String _senderEmail = 'duitku.otp@gmail.com';
static const String _appPassword = 'abcd efgh ijkl mnop'; // 16 karakter tanpa spasi
```

**⚠️ PENTING:**
- Jangan commit file ini ke Git public dengan kredensial asli
- App Password ≠ Password Gmail biasa
- Simpan App Password dengan aman

---

## 🔥 Fitur yang Ditambahkan (v1.7.0)

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

## 📱 Testing

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

## 🛠️ Troubleshooting

### Email OTP tidak terkirim?
1. **Cek koneksi internet** — SMTP butuh internet aktif
2. **Cek App Password** — pastikan 16 karakter, tanpa spasi
3. **Cek 2FA Gmail** — harus sudah aktif
4. **Cek Spam folder** — kadang masuk Spam
5. **Test SMTP manual** — pakai tool seperti Postman/curl

### Error "Invalid credentials" di log?
- App Password salah atau expired
- Generate ulang App Password baru

### OTP expired terus?
- Countdown 5 menit mulai dari OTP digenerate
- Pastikan clock HP tidak melenceng jauh

---

## 🔐 Keamanan

- **OTP 6 digit** random secure (100.000 - 999.999)
- **Expired 5 menit** — tidak bisa dipakai setelah countdown habis
- **PIN hashed** — disimpan dengan salted hash, bukan plaintext
- **Email stored** — untuk recovery, tersimpan di database lokal (SQLite)

---

## 📦 Dependencies Baru

```yaml
dependencies:
  mailer: ^6.0.1  # SMTP client untuk kirim email
```

File baru yang dibuat:
- `lib/services/email_service.dart` — logic kirim OTP via SMTP
- `lib/features/auth/otp_verification_screen.dart` — layar input OTP
- `lib/features/auth/forgot_pin_screen.dart` — layar reset PIN

---

Selamat menggunakan Duitku v1.7.0! 🚀💰
