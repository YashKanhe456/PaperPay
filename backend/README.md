# PaperPay

PaperPay is a full-stack newspaper agency management application. The backend is a Node.js/Express API backed by PostgreSQL, and the mobile app is a Flutter client built with Riverpod and Hive for offline-first storage.

This is an **intentionally incomplete student project**. It has a functioning backend skeleton, a working Flutter app shell, and a handful of implemented feature surfaces, but several pieces (payments, push notifications, cross-platform Firebase setup, end-to-end OTP flows) are unfinished or untested. See the **Known limitations** section for details.

## Where the cleaned submission copy lives

- **Backend**: `backend/`
- **Mobile app**: `app/`

The original, untouched project is preserved separately as `PaperPayCodex/`. Everything below applies to the cleaned copy in `PaperPay-Submission/`.

## Quick start

### Backend

The backend is at `backend/`.

1. Install dependencies:
   ```bash
   cd backend
   npm install
   ```

2. Create a local `.env` from the template and fill in real values:
   ```bash
   cp .env.example .env
   ```

3. Start the server:
   ```bash
   npm start
   ```

   The server listens on `PORT` from the environment (default `3000`).

### Database

The backend uses PostgreSQL via the `pg` driver. Connection and TLS settings are read from the environment; see **Environment variables** below.

1. Set `DATABASE_URL` to a valid PostgreSQL connection string in `.env`.
2. Apply `backend/src/db/schema.sql` to create the tables.
   - The schema includes tables for users, agencies, customers, newspapers, subscriptions, bills, payments, deliveries, delivery boys, attendance, cash collections, complaints, loyalty points, notifications, and audit logs, among others.
3. Optionally run `backend/src/db/seed.sql` if you need sample data for manual exploration.

#### TLS and local development

By default the app verifies the server certificate. This is configured by environment variables rather than hidden inside the connection string:

- `DB_SSL=true` (default when unset) enables TLS.
- `DB_SSL_REJECT_UNAUTHORIZED` controls certificate verification. It defaults to `true`. Set it to `false` only for local development against a self-signed certificate, and never in production.

The `.env.example` file documents these settings. Do not put `sslmode` in `DATABASE_URL`; the app is the single source of truth for TLS behavior.

#### Test database access

When the database is not reachable, the server still starts. The `/api/health` endpoint will return a 500 until the connection succeeds, which lets you confirm the server is running even in environments without a database.

### Environment variables

See `backend/.env.example` for the full template. The important variables are:

- `DATABASE_URL` — PostgreSQL connection string.
- `DB_SSL` — set to `false` to disable TLS for local Postgres without SSL.
- `DB_SSL_REJECT_UNAUTHORIZED` — `true` (verify certificates) or `false` (skip verification). Defaults to `true`.
- `PORT` — HTTP port (default `3000`).
- `CORS_ALLOWED_ORIGINS` — comma-separated browser origins allowed to call the API. Requests without an `Origin` header (curl, the mobile app, server-to-server calls) are always allowed.
- `JWT_SECRET` — signing secret for the app's own session tokens issued by `/api/auth/verify-token`.
- Firebase Admin variables: `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`.
- Cloudinary variables: `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`.
- Razorpay variables: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`.

All real values live in `.env`, which is git-ignored. Only `.env.example` with placeholder values is tracked.

### CORS

CORS is now restricted to the origins listed in `CORS_ALLOWED_ORIGINS`. When that variable is unset or empty, CORS is effectively disabled and only requests that do not trigger a browser CORS check will work. This matches how the Flutter mobile app and curl call the API.

### Running the backend locally

A minimal local setup is:

1. `DATABASE_URL` pointing at a local or hosted Postgres instance.
2. `.env` with placeholder or real service credentials as needed.
3. `npm start`.

Cloudinary, Razorpay, and Firebase-dependent routes will fail at runtime unless the corresponding variables are configured. Those failures are surfaced as clear error responses rather than silent placeholders.

## Mobile app

The mobile app is at `app/`. It is built with Flutter.

1. Install dependencies:
   ```bash
   cd app
   flutter pub get
   ```

2. Build or run:
   ```bash
   flutter run --dart-define=API_URL=http://<your-host>:3000
   ```

   The app expects `API_URL` to point at a running backend.

Flutter web support exists at `app/web/`, but cross-platform Firebase configuration for iOS, macOS, and Windows is **not** complete. See **Incomplete features**.

## State of the features

### Implemented

- Backend API skeleton with Express, helmet, rate limiting, and a configurable CORS allowlist.
- Authentication flow through Firebase phone OTP verification and an app-side JWT session token issued by `/api/auth/verify-token`.
- Agency registration and agency-scoped user workflows.
- Customer, newspaper, subscription, bill, payment, delivery, delivery-boy, attendance, cash-collection, complaint, notification, and settings routes with agency ownership checks.
- Role-based authorization: sensitive administrative paths are gated behind `agency_admin`, and agency-owned resources are restricted to the owning agency.
- Offline-first support in the mobile app through Hive for local storage and sync queues.
- Dashboard and reporting routes for agency-level metrics.
- FCM token registration endpoint that stores the token against the authenticated user.
- File upload support through Cloudinary with MIME-type and filename sanitization.

### Incomplete

- **Razorpay checkout is not fully integrated.** The backend has Razorpay order creation, verification, and refund helpers, and the app has payment screens, but the actual checkout integration is unfinished. Do not treat live online payments as supported.
- **Push notifications are not end-to-end verified.** The backend has FCM token registration and notification send endpoints, but FCM delivery has not been verified as working end to end.
- **OTP login, automated billing, and payment processing have not been fully tested end to end.** They exist on paper but are not verified in the submission.
- **Cross-platform Firebase support is incomplete.** iOS, macOS, and Windows Firebase setup is not completed; do not assume the app works on those platforms.
- **Some database columns and migrations may be missing.** Certain notification-related fields and enumerated statuses in the schema may require migrations that are not included in this submission.

### Security posture

The backend has been hardened for submission, but it is **not production-ready secure**:

- Credentials are not committed; `.env` is git-ignored and `.env.example` contains only placeholders.
- CORS is restricted to a configurable allowlist.
- TLS verification is enabled by default.
- Authorization checks were added to notification send endpoints, token registration, and agency-scoped resources.
- However, many endpoints still rely on Firebase token verification at runtime, and a full penetration test has not been performed.

## Tests

### Backend tests

Backend tests live in `backend/tests/`. They can be run with:

```bash
cd backend
npm test
```

This project ships a small authorization smoke test in `backend/tests/authorization.test.js` that verifies:

- `/api/health` is reachable without authentication.
- `/api/customer-app/me` and `/api/bills` return 401 without a token.
- `/api/customer-app/me` returns 401 with a tampered token.

These tests are smoke tests only. They do not require a real database and are not a substitute for full integration or end-to-end testing, which has not been completed.

### Backend verification

You can also run:

```bash
cd backend
node --check src/app.js src/db/pool.js src/routes/*.js src/services/*.js src/config/*.js src/server.js
```

...to syntax-check the backend source files.

### Mobile app tests

The mobile app has a rewritten widget test suite at `app/test/widget_test.dart`. It covers:

- Validator behavior for Indian mobile numbers.
- Formatter behavior for currency and dates.
- Basic widget rendering for the loader and phone login screen.
- Splash-screen routing for signed-out users, agency admins with and without an agency, and customers.
- An end-to-end smoke test that the app boots on the splash screen and reaches the login screen.

Run them with:

```bash
cd app
flutter test
```

These tests are run in an environment without Firebase, so they intentionally avoid network calls and platform plugins.

## Known limitations and things a reviewer should know

- The project is deliberately incomplete and is not suitable for production use.
- Razorpay checkout, push notifications, OTP login, automated billing, and payment processing are not verified end to end.
- Cross-platform Firebase support for iOS, macOS, and Windows is not complete.
- Some database schema elements may be incomplete or require migrations.
- Security has been improved for submission, but the app is not production-hardened.
- End-to-end integration tests, performance tests, and accessibility reviews have not been done.

## Credential rotation checklist

Because the original project contained a `.env` with real credentials, you should assume those credentials may have been exposed and rotate them manually. This submission copy does not include `.env`, but rotation is still required if the original was ever committed or shared.

Rotate the following if they were present in the original `.env`:

- `JWT_SECRET`
- `DATABASE_URL` (database credentials)
- `FIREBASE_PRIVATE_KEY` (Firebase service account private key)
- `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET`
- `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET`

Do not rotate these automatically. Update each service's credentials in its own console, then update the new `.env` locally.

## Files changed in this submission copy

Relative to the untouched `PaperPayCodex/` project, the following were modified or added in the cleaned copy:

- `backend/.gitignore`
- `backend/.env.example`
- `backend/src/db/pool.js`
- `backend/src/app.js`
- `backend/src/middleware/auth.js`
- `backend/src/middleware/requireRole.js` (new)
- `backend/src/routes/notifications.js`
- `backend/src/services/razorpay.js`
- `backend/tests/authorization.test.js`
- `app/test/widget_test.dart`
- `app/lib/main.dart`
- `app/lib/core/utils/validators.dart`
- `README.md`

## Files removed from the submission copy

The following were removed or excluded for hygiene:

- `backend/.env` (real credentials)
- `backend/node_modules/` (dependency directory)
- Browser profiles, scratch Playwright scripts, IDE metadata, and machine-specific generated files where present

These removals preserve source code, manifests, lockfiles, and configuration needed to rebuild the project.

## License

This is a student project submission. It does not include a custom license. Third-party components retain their own licenses, and the project does not claim ownership of them.

## Final classification

READY WITH DISCLOSED LIMITATIONS

The submission copy is safer and cleaner than the original, and it includes honest documentation of what is and is not implemented. It is not production-ready, and it explicitly does not claim that payments, notifications, OTP login, or cross-platform Firebase support are verified working.
