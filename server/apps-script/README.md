# Duitku OTP backend (Google Apps Script + GmailApp)

No VPS and no third-party email service needed. The OTP runs as a Google Apps Script web app and sends email with `GmailApp`, as the deployer's Google account.

## 1. Create the Apps Script project
1. Open https://script.google.com and click **New project**.
2. Delete the default code, paste the full contents of `Code.gs`, and save.
3. Go to **Project Settings** (gear icon) → **Script properties** → **Add script property**. Add:
   - `APP_KEY`: a long random string you choose (this is the value you later pass as `OTP_APP_KEY`)
4. Click **Deploy** → **New deployment** → type **Web app**.
   - Execute as: **Me**
   - Who has access: **Anyone**
5. Click **Deploy**, authorize the script, and copy the **Web app URL** (ends with `/exec`).

## 2. Limits
- The server enforces a 60-second cooldown per email and a 5-attempt limit per code.

## 3. Build the app with the endpoint
```
flutter build apk --release --no-tree-shake-icons \
  --dart-define=OTP_ENDPOINT=https://script.google.com/macros/s/XXXX/exec \
  --dart-define=OTP_APP_KEY=<APP_KEY>
```

## 4. Quick test (optional)
```
curl -L -X POST "<EXEC_URL>" -H "Content-Type: application/json" \
  -d '{"action":"otp/send","appKey":"<APP_KEY>","email":"you@example.com","purpose":"test"}'
```
Expected: `{"ok":true}` and an email in the inbox. Note: Apps Script redirects POST, so `curl -L` is required.
