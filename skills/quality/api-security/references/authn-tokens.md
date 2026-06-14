# Authentication: OAuth2/OIDC, JWT, Sessions, API Keys (API2)

Authentication establishes identity. Broken authentication (API2) is accepting forged, expired, or unverified credentials — or exposing flows to credential stuffing and brute force.

## OAuth2 / OIDC flows — pick the right grant

| Flow | Use for | Notes |
|------|---------|-------|
| Authorization Code + PKCE | Web apps, SPAs, mobile | The default. PKCE is mandatory now even for confidential clients. |
| Client Credentials | Service-to-service (no user) | Machine identity; scope down per service. |
| Device Code | TVs, CLIs, input-constrained | User authorizes on a second device. |
| Refresh Token (rotation) | Long sessions | Rotate on use; detect reuse → revoke the family. |

**Never use** the Resource Owner Password Credentials grant (deprecated) or the Implicit flow (tokens in the URL fragment). OIDC adds an `id_token` (identity) on top of OAuth2's `access_token` (authorization) — don't use an `id_token` to call APIs.

## JWT validation — the failure checklist

The access token is a bearer credential; validating it incompletely is API2.

```ts
import { jwtVerify, createRemoteJWKSet } from "jose";
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks.json`));

const { payload } = await jwtVerify(token, JWKS, {
  issuer: ISSUER,                 // 1. pin iss
  audience: API_AUDIENCE,         // 2. pin aud — token for another API is invalid here
  algorithms: ["RS256"],          // 3. pin alg — blocks `none` and HS/RS confusion
  clockTolerance: "30s",          // 4. exp/nbf checked automatically by jose
});
// 5. enforce scopes/roles from the claims, server-side, per route (see authz ref)
```

Common JWT pitfalls:

- **`alg: none`** accepted → forged tokens. Always pin `algorithms`.
- **Algorithm confusion** — server verifies an `RS256` token with the public key as an `HS256` *secret*. Pin to asymmetric algs; never let the token pick.
- **Skipping `aud`/`iss`** → a valid token minted for a different service/audience is accepted.
- **No expiry check** or absurd `clockTolerance` → replay of stale tokens.
- **Trusting unsigned claims** for authorization (`role` in a token you didn't verify).
- **Storing secrets in the JWT** — it is signed, not encrypted; anyone can read the payload.

Validate against the issuer's JWKS (cached, key-rotation aware) — do not hardcode a single public key.

## Sessions (cookie-based)

For first-party web apps, opaque server-side sessions are often simpler and safer than JWTs (instant revocation, no token-in-localStorage XSS exposure).

```ts
res.cookie("sid", sessionId, {
  httpOnly: true,   // JS can't read it (XSS mitigation)
  secure: true,     // HTTPS only
  sameSite: "lax",  // CSRF mitigation; "strict" for sensitive apps
  maxAge: 1000 * 60 * 60 * 8,
  path: "/",
});
```

- Store sessions server-side (Redis/DB); the cookie holds only an opaque id.
- Regenerate the session id on login (prevents session fixation).
- Add CSRF protection for cookie-auth state-changing requests (double-submit token or `SameSite=strict` + custom header).
- Idle + absolute timeouts; revoke on logout and password change.

## Token storage (clients)

- **Never** store access/refresh tokens in `localStorage` — XSS reads it. Use `httpOnly` cookies, or keep tokens in memory with a refresh from an `httpOnly` cookie.
- Mobile: platform secure storage (Keychain / Keystore).

## Refresh-token rotation & reuse detection

```text
client → /token (refresh_token R1)
server → issues access + new refresh R2, marks R1 used, links R1→R2 (family)
client → /token (R1 again)   ← reuse of a spent token
server → R1 already used → REVOKE the whole family, force re-auth
```

Rotation + reuse detection turns a stolen refresh token into a detectable, self-limiting incident.

## API keys (service clients)

- High-entropy, prefixed (`sk_live_...`) so they're greppable in leak scans.
- **Store only a hash** (e.g. SHA-256) — verify by hashing the presented key.
- Scope per key (least privilege), support rotation, and rate-limit per key (see [injection-ssrf-ratelimit](injection-ssrf-ratelimit.md)).
- Accept in a header, never the query string (URLs land in logs and history).

## Defending the auth endpoints themselves (API6)

Login, signup, password reset, and OTP are sensitive business flows:

- Rate-limit per IP **and** per account; add exponential backoff / lockout with care (avoid a self-inflicted DoS — prefer throttling over hard lockout).
- Constant-time credential comparison; the same response time/shape for "no such user" and "wrong password" (no user-enumeration oracle).
- Hash passwords with `argon2id` (or `bcrypt` with an appropriate cost); never a fast/general-purpose hash.
- CAPTCHA / proof-of-work on abusive bursts; bot detection on signup.

## Per-stack notes

| Stack | Idiomatic auth |
|-------|----------------|
| Node | `jose` for JWT; Passport/`@nestjs/passport`; `express-session` + Redis |
| Go | `golang-jwt`/`coreos/go-oidc`; `gorilla/sessions` or SCS |
| Spring | Spring Security Resource Server (`oauth2ResourceServer().jwt()`) |
| FastAPI | `fastapi.security` + `python-jose`/`authlib`; OAuth2 schemes |
| Rails | Devise + OmniAuth; `has_secure_password` (bcrypt) |
| ASP.NET Core | `AddAuthentication().AddJwtBearer(...)`; ASP.NET Identity |

Versions: skill [version-feature-matrix](../../../_shared/version-feature-matrix.md).

## Checklist

- [ ] Authorization Code + PKCE (or Client Credentials for m2m); no Implicit/ROPC.
- [ ] JWT validation pins `algorithms`, `issuer`, `audience`, and checks `exp`/`nbf`.
- [ ] Keys fetched from JWKS with rotation; no `alg: none`, no HS/RS confusion.
- [ ] Session cookies are `httpOnly` + `secure` + `sameSite`; id regenerated on login.
- [ ] Refresh tokens rotate with reuse detection; revoke on reuse.
- [ ] API keys stored hashed, scoped, rotatable, sent in a header.
- [ ] Auth endpoints rate-limited per IP and per account; constant-time, no enumeration.
- [ ] Passwords hashed with `argon2id`/`bcrypt`.
