/**
 * Duitku OTP backend (Google Apps Script web app).
 *
 * Generates a 6-digit OTP, stores it in the script cache, and sends it
 * by email with GmailApp (sent as the deployer account). No VPS is required.
 *
 * Script Properties (Project Settings -> Script properties):
 *   APP_KEY   shared secret the Flutter app sends in the body (required)
 *
 * Request: POST with a JSON body
 *   { action: 'otp/send' | 'otp/verify', appKey, email, purpose?, code? }
 * Response: JSON { ok: true } or { ok: false, error: '<Bahasa Indonesia>' }
 */

var OTP_TTL_SECONDS = 300;      // code valid for 5 minutes
var OTP_COOLDOWN_SECONDS = 60;  // minimum gap between sends per email
var OTP_MAX_ATTEMPTS = 5;       // wrong attempts before the code is burned

/** Entry point for every POST to the /exec URL. */
function doPost(e) {
  try {
    var props = PropertiesService.getScriptProperties();
    var body = parseBody_(e);
    if (!body) {
      return jsonOut_({ ok: false, error: 'Permintaan tidak valid.' });
    }

    var expectedKey = props.getProperty('APP_KEY');
    if (!expectedKey || body.appKey !== expectedKey) {
      return jsonOut_({ ok: false, error: 'Akses ditolak.' });
    }

    var email = String(body.email || '').trim().toLowerCase();
    if (!isValidEmail_(email)) {
      return jsonOut_({ ok: false, error: 'Format email tidak valid.' });
    }

    if (body.action === 'otp/send') {
      return jsonOut_(handleSend_(email, props));
    }
    if (body.action === 'otp/verify') {
      return jsonOut_(handleVerify_(email, String(body.code || '').trim()));
    }
    return jsonOut_({ ok: false, error: 'Permintaan tidak dikenal.' });
  } catch (err) {
    console.error('doPost failed: ' + err);
    return jsonOut_({ ok: false, error: 'Server error.' });
  }
}

/** Creates and emails a new OTP, subject to the per-email cooldown. */
function handleSend_(email, props) {
  var cache = CacheService.getScriptCache();

  if (cache.get('cool:' + email)) {
    return {
      ok: false,
      error: 'Mohon tunggu sebentar sebelum meminta kode baru.',
    };
  }

  var code = generateOtp_();
  var entry = {
    code: code,
    attempts: 0,
    expiresAt: Date.now() + OTP_TTL_SECONDS * 1000,
  };
  cache.put('otp:' + email, JSON.stringify(entry), OTP_TTL_SECONDS);
  cache.put('cool:' + email, '1', OTP_COOLDOWN_SECONDS);

  var sent = sendOtpEmail_(email, code);
  if (!sent) {
    // Do not keep a code the user never received.
    cache.remove('otp:' + email);
    cache.remove('cool:' + email);
    return { ok: false, error: 'Gagal mengirim email. Coba lagi.' };
  }
  return { ok: true };
}

/** Checks the code. Burns it after too many wrong attempts. */
function handleVerify_(email, code) {
  var cache = CacheService.getScriptCache();
  var raw = cache.get('otp:' + email);
  if (!raw) {
    return { ok: false, error: 'Kode sudah kedaluwarsa. Minta kode baru.' };
  }

  var entry = JSON.parse(raw);
  if (entry.code !== code) {
    entry.attempts = (entry.attempts || 0) + 1;
    if (entry.attempts >= OTP_MAX_ATTEMPTS) {
      cache.remove('otp:' + email);
      return {
        ok: false,
        error: 'Terlalu banyak percobaan salah. Minta kode baru.',
      };
    }
    // Keep the original deadline: rewrite with the remaining seconds only.
    var remaining = Math.max(1, Math.ceil((entry.expiresAt - Date.now()) / 1000));
    cache.put('otp:' + email, JSON.stringify(entry), remaining);
    return { ok: false, error: 'Kode salah.' };
  }

  cache.remove('otp:' + email);
  return { ok: true };
}

/**
 * Sends the OTP email with GmailApp (as the deployer account).
 * Returns true on success. Logs only the error name, never the code.
 */
function sendOtpEmail_(email, code) {
  try {
    GmailApp.sendEmail(
      email,
      'Kode verifikasi Duitku',
      buildPlainBody_(code),
      { htmlBody: buildHtml_(code), name: 'Duitku' }
    );
    return true;
  } catch (err) {
    // Do not log the code or the recipient. Log the error type only.
    console.error('GmailApp send failed: ' + (err && err.name ? err.name : 'error'));
    return false;
  }
}

/** Plain-text Bahasa Indonesia body (fallback for clients without HTML). */
function buildPlainBody_(code) {
  return 'Halo,\n\n' +
    'Kode verifikasi Duitku Anda adalah: ' + code + '\n\n' +
    'Kode ini berlaku 5 menit. Jangan bagikan kode ini kepada siapa pun.\n' +
    'Jika Anda tidak merasa meminta kode ini, abaikan email ini.\n';
}

/** Simple Bahasa Indonesia HTML body. */
function buildHtml_(code) {
  return '<div style="font-family:Arial,sans-serif;font-size:16px;">' +
    '<p>Halo,</p>' +
    '<p>Kode verifikasi Duitku Anda adalah:</p>' +
    '<p style="font-size:28px;font-weight:bold;letter-spacing:6px;">' +
    code + '</p>' +
    '<p>Kode ini berlaku 5 menit. Jangan bagikan kode ini kepada siapa pun.</p>' +
    '<p>Jika Anda tidak merasa meminta kode ini, abaikan email ini.</p>' +
    '</div>';
}

/**
 * Random 6-digit code (100000-999999).
 * Uses the first 32 bits of a random UUID (Utilities.getUuid, backed by a
 * CSPRNG). Modulo bias over 900000 values is about 0.02 percent, acceptable here.
 */
function generateOtp_() {
  var hex = Utilities.getUuid().replace(/-/g, '').slice(0, 8);
  var n = parseInt(hex, 16) % 900000;
  return String(100000 + n);
}

/** Parses the JSON body. Returns null if missing or malformed. */
function parseBody_(e) {
  if (!e || !e.postData || !e.postData.contents) return null;
  try {
    var obj = JSON.parse(e.postData.contents);
    return obj && typeof obj === 'object' ? obj : null;
  } catch (err) {
    return null;
  }
}

/**
 * Accepts a single plain address only. Rejects commas, whitespace, angle
 * brackets, quotes, or a second '@' so GmailApp cannot be used as a relay.
 */
function isValidEmail_(email) {
  return /^[^\s@,;<>"']+@[^\s@,;<>"']+\.[^\s@,;<>"']+$/.test(email) &&
    email.length <= 254;
}

function jsonOut_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
