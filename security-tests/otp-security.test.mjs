// Security tests for the Duitku OTP backend (Google Apps Script doPost).
// Runs against a live deployment. Every test performs a real HTTP request.
//
// Required environment variables:
//   OTP_ENDPOINT  - full https://script.google.com/macros/s/.../exec URL
//   OTP_APP_KEY   - app key expected by the backend
// Never hardcode these values in this file.
//
// Run: OTP_ENDPOINT=<URL> OTP_APP_KEY=<KEY> node --test security-tests/

import { describe, it, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';

const ENDPOINT = process.env.OTP_ENDPOINT;
const APP_KEY = process.env.OTP_APP_KEY;
const READY = Boolean(ENDPOINT && APP_KEY);
const SKIP_REASON =
  'OTP_ENDPOINT and/or OTP_APP_KEY not set. Set both env vars to run live tests.';
const TIMEOUT_MS = 20_000;

// Test addresses use the reserved example.com domain so no real mailbox is targeted.
function uniqueEmail() {
  return `sec-test-${randomBytes(6).toString('hex')}@example.com`;
}

// Sends a raw request body. Returns status, headers, raw text, and parsed JSON if possible.
async function rawPost(rawBody, contentType = 'application/json') {
  const res = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': contentType },
    body: rawBody,
    redirect: 'follow',
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = null;
  }
  return { status: res.status, headers: res.headers, text, json };
}

// Sends a JSON object. Includes appKey unless `overrides` sets it explicitly.
async function post(payload, { withKey = true } = {}) {
  const body = withKey ? { appKey: APP_KEY, ...payload } : { ...payload };
  return rawPost(JSON.stringify(body));
}

function assertJsonFailure(r, label) {
  assert.ok(r.json !== null, `${label}: response is not JSON (status ${r.status})`);
  assert.equal(r.json.ok, false, `${label}: expected ok:false, got ${r.text.slice(0, 200)}`);
}

describe('OTP security', { skip: READY ? false : SKIP_REASON }, () => {
  before(() => {
    // Shows the target in the log without printing the key.
    console.log(`Target endpoint host: ${new URL(ENDPOINT).host}`);
  });

  describe('authentication', () => {
    it('rejects a send request without appKey', { timeout: TIMEOUT_MS }, async () => {
      const r = await post({ action: 'otp/send', email: uniqueEmail(), purpose: 'test' }, { withKey: false });
      assertJsonFailure(r, 'no appKey');
    });

    it('rejects a request with a wrong appKey', { timeout: TIMEOUT_MS }, async () => {
      const r = await rawPost(
        JSON.stringify({ action: 'otp/send', appKey: `${APP_KEY}-wrong-${randomBytes(4).toString('hex')}`, email: uniqueEmail(), purpose: 'test' }),
      );
      assertJsonFailure(r, 'wrong appKey');
    });

    it('does not echo the appKey back in the response', { timeout: TIMEOUT_MS }, async () => {
      const r = await rawPost(
        JSON.stringify({ action: 'otp/send', appKey: 'echo-probe-key-xyz', email: uniqueEmail(), purpose: 'test' }),
      );
      assert.ok(!r.text.includes('echo-probe-key-xyz'), 'response echoes the submitted appKey');
      assert.ok(!r.text.includes(APP_KEY), 'response contains the configured appKey');
    });
  });

  describe('request handling', () => {
    it('returns ok:false JSON for a malformed JSON body (not a crash page)', { timeout: TIMEOUT_MS }, async () => {
      const r = await rawPost('{"action": "otp/send", "appKey": ', 'application/json');
      assertJsonFailure(r, 'malformed JSON');
      assert.ok(!/<html/i.test(r.text), 'malformed JSON returned an HTML error page');
    });

    it('rejects or safely handles an oversized body (200 KB) without crashing', { timeout: TIMEOUT_MS }, async () => {
      const padding = 'A'.repeat(200 * 1024);
      const r = await rawPost(JSON.stringify({ action: 'otp/send', appKey: APP_KEY, email: uniqueEmail(), purpose: padding }));
      assert.ok(r.status < 500, `oversized body caused server error ${r.status}`);
      if (r.json !== null) {
        assert.equal(r.json.ok, false, 'oversized body was accepted with ok:true');
      }
    });
  });

  describe('email validation', () => {
    const cases = {
      'empty email': '',
      'email without @': 'userexample.com',
      'email longer than 254 chars': `${'a'.repeat(250)}@x.co`,
    };
    for (const [label, email] of Object.entries(cases)) {
      it(`rejects ${label}`, { timeout: TIMEOUT_MS }, async () => {
        const r = await post({ action: 'otp/send', email, purpose: 'test' });
        assertJsonFailure(r, label);
      });
    }
  });

  describe('OTP send and verify', () => {
    it('send response never contains the OTP code (6-digit pattern)', { timeout: TIMEOUT_MS }, async () => {
      const r = await post({ action: 'otp/send', email: uniqueEmail(), purpose: 'test' });
      assert.ok(!/(?<!\d)\d{6}(?!\d)/.test(r.text), `send response contains a 6-digit number: ${r.text.slice(0, 200)}`);
    });

    it('rate limits a second send to the same email within 60 s', { timeout: TIMEOUT_MS * 2 }, async () => {
      const email = uniqueEmail();
      await post({ action: 'otp/send', email, purpose: 'test' });
      const second = await post({ action: 'otp/send', email, purpose: 'test' });
      assertJsonFailure(second, 'second send within cooldown');
    });

    it('wrong codes fail and keep failing after 5 attempts (lockout)', { timeout: TIMEOUT_MS * 3 }, async () => {
      const email = uniqueEmail();
      await post({ action: 'otp/send', email, purpose: 'test' });
      for (let i = 1; i <= 5; i++) {
        const r = await post({ action: 'otp/verify', email, code: '000000' });
        assertJsonFailure(r, `wrong code attempt ${i}`);
      }
      // After the 5th wrong attempt the code must be invalid. This checks that ok:false is
      // returned, not that the true code is rejected. Proving the true code is dead needs
      // inbox access, which these tests do not have.
      const after = await post({ action: 'otp/verify', email, code: '111111' });
      assertJsonFailure(after, 'attempt after lockout');
    });

    it('verify with no prior send is rejected', { timeout: TIMEOUT_MS }, async () => {
      const r = await post({ action: 'otp/verify', email: uniqueEmail(), code: '123456' });
      assertJsonFailure(r, 'verify without send');
    });
  });
});
