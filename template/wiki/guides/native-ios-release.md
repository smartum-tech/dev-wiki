---
title: iOS release and TestFlight — the Apple-side setup and its decisions
class: compiled
covers: []                 # fill when adopting — e.g. the iOS build and publish scripts
last-verified: never
verified-by: boilerplate
sources: []
---

# iOS release and TestFlight: Apple-side setup

One-time setup needed before the build script can sign and upload to TestFlight. Everything here
happens in Apple's web consoles; the local tooling is described in
[`native-builds.md`](./native-builds.md). This page keeps the **decisions and traps**; the click
path changes with Apple's UI, so keep a dated step-by-step for your team beside the root
`RELEASING-IOS.md` (or equivalent), not in the wiki.

## The organising constraint: who holds which role, and for how long

Certificates, Identifiers & Profiles and the Devices list are **Admin-only**. If your team's role
is, or will be reduced to, App Manager, every Admin-only step must be done while the elevated role
lasts — afterwards each of them needs someone else. Plan the order of work around that, not around
convenience. Step 5 onward (the ordinary build loop) needs nothing beyond App Manager.

Prerequisite: an active Apple Developer Program membership; the Team ID is in App Store Connect →
Membership.

## Step 1 — Register the App Identifier first

The "New App" form lists only **already-registered** bundle IDs, so register the explicit identifier
before creating the app. Registering is independent of building (no archive needed). Tick
**Push Notifications** plus everything plausibly needed later (Associated Domains, App Groups): an
enabled capability the app doesn't claim in its entitlements costs nothing, while enabling one
*later* needs Admin. Do not economise here. The bundle id is set in the Capacitor config and the
Xcode project — it is **not** an env var. Choose the final suffix carefully: an id is bound to an
Apple record by the first uploaded build and can never be registered again, in this team or any
other.

**While still Admin, also register every test device's UDID.** A development profile enumerates
devices; an unregistered phone later means a blocked device *and* no way to unblock it.

## Step 2 — Create the app in App Store Connect

Platform iOS, a store-unique name, primary language, the bundle ID from step 1, a unique SKU (a SKU
can't be reused within the organisation, even from a deleted record), user access Full. TestFlight
uploads attach to this record; without it the upload fails.

## Step 3 — Signing: by hand, once, on the build machine

Cloud signing (`-allowProvisioningUpdates`) creates the certificate and profile through the API, an
**Admin-only** privilege. With a lower role it fails at the *signing* step — after a successful
archive — with `Cloud signing permission error` / `No signing certificate "iOS Distribution"
found`, which reads like a broken build rather than a missing right. So decide: either an Admin-role
API key for cloud signing, or manual signing:

1. **Generate the CSR on the build machine** (Keychain Access → Request a Certificate from a
   Certificate Authority → Saved to disk). Whoever generates the CSR holds the private key; doing it
   on the build machine means the key never travels and nobody exports a `.p12` (which *is* the
   private key, revocable only together with the certificate, taking every build with it).
2. **Issue the Apple Distribution certificate**, download the `.cer`, install it into the login
   keychain. Verify with `security find-identity -v -p codesigning`. It lasts three years; the
   team's allowance is small, so revoke a stale one rather than stacking new ones.
3. **Issue the App Store provisioning profile** (Distribution → App Store Connect → the App ID →
   the certificate) and keep the `.mobileprovision` beside the keys.

⚠️ **The profile expires after one year, and reissuing it needs an Admin.** Have the build script
warn ~30 days out and treat the warning as a request to send, not as noise — the person who can act
on it may sit in another organisation. Neither the `.cer` nor the profile is secret; only the
private key (in the keychain) and the API `.p8` need a careful channel.

## Step 4 — App Store Connect API key (upload only)

With manual signing the key does one thing: upload the IPA. **App Manager is enough** — matching
the role you keep after elevated access ends, so the pipeline doesn't quietly depend on rights you
are not meant to have.

- The Integrations section must first be enabled for the team by the **Account Holder** (a one-time
  request); until then nobody, not even an Admin, sees the Team Keys tab.
- Use **Team Keys, not Individual Keys**: an individual key carries only its creator's rights and
  loses them when that person's role changes.
- The `.p8` can be downloaded **only once**; keep it in a gitignored secrets folder. Note the Key ID
  and the (per-team) Issuer ID, and put team id, key id, issuer id, key path, profile path and
  export method into the gitignored root `.env`. The build copies the `.p8` where `altool` looks
  and installs the profile; the profile's name/UUID are read out of the file, so there is no
  separate variable to keep in step with the portal.

## Step 5 — Build and upload

One command runs: web build → `cap sync ios` → version stamp → preflight (certificate in keychain,
profile readable and not about to expire) → `xcodebuild archive` (manually signed) → export IPA →
`altool --upload-app`. After upload Apple processes the build (minutes to ~1 h) before it shows
under TestFlight.

## Step 6 — TestFlight tester groups

| | Internal | External |
|---|---|---|
| Testers | your App Store Connect users (≤100) | anyone (≤10,000) |
| Access | email invite, via TestFlight app | public join link or email |
| Public link | none | enable per group |
| Apple review | none, instant | Beta App Review (~1 day for the first build) |

Only **External** groups expose a public join link, so publishing a clickable link on the portal
needs one: create the group, add the processed build, fill the Beta App Review fields, and after
approval enable **Public Link**. The link is static per group; record it in the env variable the
publish script reads. If it's still empty, the build is uploaded and the portal step is skipped
with a warning.

## Troubleshooting

- **`Cloud signing permission error`** — the API key role is below Admin (role is fixed at creation).
  Create a new Admin key, or open the project in Xcode once with Automatic signing, let it create
  the Distribution certificate, and re-run.
- **`exportArchive` rejects the export method** — switch between `app-store-connect` (Xcode 16+) and
  `app-store` (Xcode ≤ 15).
- **Duplicate build number** — `CFBundleVersion` must increase per upload of the same marketing
  version; bump the manifest version before re-uploading.
