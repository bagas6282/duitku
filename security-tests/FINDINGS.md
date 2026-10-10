# Findings: Duitku OTP client (lib/services/email_service.dart)

Static review, read-only. No live tests were run (backend not deployed).

## High

1. **Plaintext HTTP to the OTP server.** `_baseUrls` uses `http://94.237.78.157` and `:8081`.
   The OTP code, the email address, and the `x-app-key` header all travel unencrypted and can be read or altered by anyone on the network path (public Wi-Fi, ISP, captive portal). Fix: serve over HTTPS, or move the endpoint to the HTTPS Apps Script URL and drop the port 8081 fallback.

2. **App key is not a secret.** `_appKey = 'duitku-otp-2026'` is a `const` in the Dart source. It is compiled into the APK and is readable with `strings`, apktool, or Dart AOT tooling. It is obfuscation, not authentication. Anyone who extracts it can call `otp/send` and `otp/verify` directly. The real protection must be server-side: per-email cooldown, lockout after 5 attempts, IP or device rate limits, and a short code TTL. Do not rely on the key to stop abuse.

## Medium

3. **Fallback to a second host with the same weak transport.** Port 8081 is also HTTP, so the fallback does not improve security. Failover order is a reliability feature, not a trust boundary.

4. **Send path can be used to spam any address.** The client does not limit how often `requestOtp` is called. Only the backend cooldown stops repeated sends. Verify the backend cooldown is per email AND per IP. Also note the `_preferred` retry loop can fire up to two requests per tap.

5. **Server error text shown to the user.** `decoded['error']` is displayed verbatim. If the backend ever returns internal detail, it reaches the UI. Keep server errors to fixed, safe strings.

## Low

6. **Email is PII in transit.** The address is sent in the request body over HTTP (see #1). It is not logged by this file, which is good.

7. **`debugPrint` in release builds.** `debugPrint` also prints in release mode. The error log at line `debugPrint('❌ EmailService error ($baseUrl$path): $e')` includes the exception text. Exceptions here are unlikely to contain the email, but the code relies on that. Guard it with `kDebugMode`, or drop the exception text.

8. **Test hook in production code.** `mockHandler` is a public static field. `@visibleForTesting` is only a lint hint. Anyone with the source can bypass the network path. Low risk, but it can be made private or moved to test-only code.

9. **Timeout worst case.** Each attempt has a 15 s timeout, and two hosts are tried, so one OTP action can block for about 30 s. Consider a lower timeout or a single retry budget, and show progress.

10. **Weak client email check.** `isValidEmail` only checks for `@`, `.`, and length 5. This is fine as UX, but the server must validate too (the security tests cover that).

## Checks not run live

- All server-side tests in `security-tests/otp-security.test.mjs` are pending. They need the deployed endpoint and env vars.
- Only `node --check` was run (passes).
- The test runner was run with no env vars: the suite skips correctly when the file is passed directly. `node --test security-tests/` (directory form) fails on Node v26 with `Cannot find module`, so the README documents the file-path form.
