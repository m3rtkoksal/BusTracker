# AGENTS.md

## Cursor Cloud specific instructions

### Product overview

**Shuttle Live** (Xcode project: `BusTracker`) is an iOS shuttle-tracking app with a Firebase backend. This Linux VM can develop and test the **Firebase Hosting site** and **Cloud Functions**; the **iOS app requires macOS + Xcode 16+** and cannot be built or run here.

### Services

| Service | Command | Port | Notes |
|---------|---------|------|-------|
| Firebase Hosting emulator | `npx firebase emulators:start --only hosting --project bustracker-717a3` | 5000 | Works without `firebase login`; use `emulators:start`, not `firebase serve` (serve requires auth) |
| Functions + Firestore emulators | `npx firebase emulators:start --only functions,firestore --project bustracker-717a3` | 5001 (functions), 8080 (firestore), 4000 (UI) | First start downloads emulator JARs; allow ~2 min |
| iOS app | `open BusTracker.xcodeproj` (macOS only) | — | Not available on Linux |

Run hosting and functions emulators in **separate terminals** if both are needed simultaneously (port 5000 conflict otherwise). Alternatively, start all at once: `npx firebase emulators:start --only hosting,functions,firestore --project bustracker-717a3`.

### Dependency install

```bash
npm install          # root: firebase-tools CLI
cd functions && npm install
```

Node **22** is required for Cloud Functions (`functions/package.json` engines).

### Lint / test

- No ESLint, Prettier, or automated test suite is configured in this repo.
- Validate Cloud Functions with syntax check and module load:
  ```bash
  node --check functions/index.js
  cd functions && node -e "require('./index.js'); console.log('OK')"
  ```

### Deploy (requires `firebase login`)

```bash
npm run firebase:deploy          # Cloud Functions only
npm run firebase:deploy:hosting  # Hosting only
```

### Triggering Cloud Functions locally

Firestore security rules block unauthenticated REST writes. Use the Admin SDK with the emulator:

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node -e "
const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'bustracker-717a3' });
admin.firestore().collection('groups').doc('demo').collection('tripEvents').add({ type: 'started', driverName: 'Test' });
"
```

Check function logs in the emulator terminal or `firebase-debug.log`.

### Key paths

- iOS app: `BusTracker/`, `BusTracker.xcodeproj`
- Cloud Functions: `functions/`
- Hosting static site: `hosting/public/` (join page at `/join`, invite codes via `/join/CODE` or `?code=CODE`)
- Firebase config: `firebase.json`, `.firebaserc` (project: `bustracker-717a3`)
