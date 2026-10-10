# Duitku OTP security tests

Black-box tests for the OTP backend (Google Apps Script `doPost`).
Every test sends a real HTTP request to the endpoint. Nothing is mocked.

## Requirements

- Node.js 18+ (uses built-in `node:test`, `fetch`, `AbortSignal.timeout`)
- `OTP_ENDPOINT`: full `https://script.google.com/macros/s/.../exec` URL
- `OTP_APP_KEY`: the app key the backend expects

Values come from the environment only. Do not hardcode them or commit them.

## Run

Requested form:

```
OTP_ENDPOINT=<URL> OTP_APP_KEY=<KEY> node --test security-tests/
```

Node 21+ (including v26) does not accept a directory here and fails with
`Cannot find module`. On those versions use the glob form:

```
OTP_ENDPOINT=<URL> OTP_APP_KEY=<KEY> node --test security-tests/otp-security.test.mjs
```

On Windows PowerShell, set the variables first:

```
$env:OTP_ENDPOINT="<URL>"; $env:OTP_APP_KEY="<KEY>"; node --test security-tests/otp-security.test.mjs
```

If either variable is unset, the suite is skipped with a message and no requests are sent.

## What is tested

- Send without `appKey` is rejected; wrong `appKey` is rejected
- Response does not echo the submitted or configured `appKey`
- Malformed JSON returns `ok:false` JSON, not an HTML error page
- 200 KB body is rejected or handled without a 5xx
- Email: empty, no `@`, longer than 254 chars are rejected
- Send response does not contain a 6-digit code
- Second send to the same email within 60 s is rejected
- 5 wrong verify codes, then a further attempt is rejected
- Verify with no prior send is rejected

## Notes

- Test addresses use `example.com` and a random local part.
- Running the suite sends real OTP emails to `example.com` addresses via the backend.
  Run it only against a test deployment.
- The lockout test cannot prove the real code is dead without inbox access.
