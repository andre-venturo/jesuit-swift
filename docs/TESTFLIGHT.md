# TestFlight Deployment

Repeatable archive → export → upload pipeline for the Jesuit iOS app.

## Prerequisites (one-time)

1. **Xcode signed into the developer account.**
   Xcode → Settings → Accounts → add the Apple ID belonging to team `RTJ97ZPCBQ`.
   Automatic signing generates the App Store distribution certificate + provisioning
   profile on the first archive (`-allowProvisioningUpdates` handles this).

2. **App record exists in App Store Connect** for bundle ID `com.jesuit`. (Already created.)

3. **App-specific password.**
   Go to https://appleid.apple.com → Sign-In and Security → App-Specific Passwords →
   generate one (e.g. for "altool"). It looks like `abcd-efgh-ijkl-mnop`.
   This is NOT your Apple ID password.

## Upload

```bash
ASC_APPLE_ID="you@example.com" \
ASC_APP_PASSWORD="abcd-efgh-ijkl-mnop" \
./scripts/testflight.sh
```

The script:
1. Increments the build number in `scripts/build_number.txt` (keep this file committed).
2. Archives the `Jesuit` scheme in Release.
3. Exports a signed `.ipa` to `build/export/`.
4. Uploads via `xcrun altool`.

After "No errors uploading", the build appears in App Store Connect → TestFlight after a
few minutes of processing. Assign it to a test group there to distribute.

## Version vs. build number

- **Marketing version** (`MARKETING_VERSION`, e.g. `1.0`) — the user-facing version, set in
  the Xcode project. Bump it for a new TestFlight/App Store version.
- **Build number** (`CURRENT_PROJECT_VERSION`) — must be unique and increasing for each
  upload of the same version. Managed automatically by `scripts/build_number.txt`; no need
  to touch the project.

## Troubleshooting

- **Signing error / no profile:** open Xcode once, select the `Jesuit` target →
  Signing & Capabilities, confirm "Automatically manage signing" is on and the team is
  `RTJ97ZPCBQ`. Re-run the script.
- **"Redundant binary upload" / build number already used:** the build number wasn't
  unique. The script auto-increments, but if a manual upload reused one, bump
  `scripts/build_number.txt` and re-run.
- **Two-factor prompts from altool:** make sure `ASC_APP_PASSWORD` is the app-specific
  password, not the account password.
