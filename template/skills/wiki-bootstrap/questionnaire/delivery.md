# Questionnaire: delivery

Covers `guides/docker-workflow.md`, `guides/deployment.md`, `guides/ci-cd.md`,
`guides/native-builds.md`, `guides/native-ios-release.md`, `guides/dist-server-portal.md`,
`guides/native-push.md`, `guides/client-monitoring.md`. Prune together: docker-workflow with
nothing Docker-shaped; the four `native-*` / portal pages with no Capacitor app; ci-cd and
deployment only after asking who owns them.

## guides/docker-workflow.md — Docker workflow

**Applies when:** the repo has a Dockerfile or compose file —
`git ls-files '*Dockerfile*' '*compose*.yml' '*compose*.yaml'` returns at least one path.
**Otherwise:** prune — nothing for the page to describe. (Also prune the "Docker" cross-references
that remain in `deployment.md` and `ci-cd.md` if those pages are kept.)

**Detect, don't ask:**
- Compose files and which stacks they define (dev / prod / preview) —
  `git ls-files '*compose*.yml' '*compose*.yaml'`
- Fixed `container_name`s (one stack per machine) — `git grep -n "container_name" -- '*compose*'`
- Dev source mounted, and whether `node_modules` is mounted —
  `git grep -n -A6 "volumes:" -- '*compose*dev*'`
- Per-module `.dockerignore` excluding `node_modules` —
  `git ls-files '*.dockerignore'` vs. the dev Dockerfile directories
- Env wiring: explicit `environment:` list or whole `env_file:` —
  `git grep -c -E "^\s+(environment|env_file):" -- '*compose*'`
- The package-manager built-in collision (`up`, `update`, `install`, `run` as script names) —
  read `scripts` in `package.json`; look for `"up"` when `{{PACKAGE_MANAGER}}` is pnpm
- A sandbox/worktree script (`{{SANDBOX_SCRIPT}}`) — `test -f {{SANDBOX_SCRIPT}}`; also
  `git worktree list`
- A dev-server config that is not hot-reloaded — `git ls-files '*vite.config.*'`

**Decide:**
1. **Where do dev servers run: in containers, or on the host?** — decides the "never run the dev
   server on the host while containers are up" rule.
   - Ours: all dev servers in containers with source bind-mounted; a host dev server beside the
     container is forbidden — it fights for the port or serves stale code.
   - Also common: host-run dev servers with containers only for infrastructure (database, queue)
     (fits small teams, fastest HMR); devcontainer (editor lives inside the container).
   - Evidence: dev compose services list; whether app services appear in it.
   - Lands in: "Forbidden", "Starting, stopping, reading".
2. **May several checkouts (main + worktrees) run the stack at once?** — decides whether fixed
   container names and the sandbox script stay.
   - Ours: no — fixed `container_name`s, one checkout at a time, switched by a sandbox script
     (`where` / `up` / `down` / `link-env`) that asks the containers, never a lock file.
   - Also common: per-worktree compose project names with offset ports (parallel stacks; costs RAM
     and port bookkeeping); no worktrees at all (drop the section).
   - Evidence: `container_name` count, `git worktree list`, sandbox script presence.
   - Lands in: "Which checkout is running the stack".
3. **How does compose receive configuration?** — decides whether "restart does not re-read env"
   and "not every `.env` value is in the container" stay as rules.
   - Ours: an explicit `environment:` list in compose; changed env needs `up -d`, not `restart`.
   - Also common: `env_file:` passing the whole file (nothing to forget to forward, but every
     unrelated secret reaches every container).
   - Evidence: the env-wiring count above.
   - Lands in: "Compose environment".
4. **Rebuild policy for the dev image** — decides when "just save the file" stops being enough.
   - Ours: bind-mount source and tool configs, never `node_modules`; rebuild the image on
     dependency, Dockerfile, compose or build-time-env changes.
   - Also common: named volume for `node_modules` (no rebuild after adding a dependency, drifts
     from the lockfile); `docker compose watch` sync (no bind mounts, works on slow file shares).
   - Evidence: the mount listing above.
   - Lands in: "What is mounted, and `node_modules`".

**Web, on request:** Docker Desktop release notes for the installed version
(`docker version --format '{{.Server.Version}}'`) — file-sharing backend (VirtioFS/gRPC FUSE)
regressions, `compose watch` availability, Linux-vs-macOS bind-mount ownership behaviour.

## guides/deployment.md — Deployment

**Applies when:** the repo holds deploy tooling — deploy scripts, a production compose file, proxy
config or IaC: `git ls-files | grep -Ei 'deploy|nginx|caddy|traefik|\.tf$|helm|k8s|ansible|compose.*prod'`
returns something.
**Otherwise:** ask whether deployment is someone else's (platform team, PaaS, another repo). If
yes — prune, or keep-as-reference only for the config-surface and production-safety sections. If
the user deploys by hand with nothing in the repo, keep the page and fill it from the interview.

**Detect, don't ask:**
- Config surfaces — `git ls-files '*.env*'` (examples only; real `.env` files are gitignored)
- Reverse proxy in the repo — `git ls-files | grep -Ei 'nginx|caddy|traefik'`
- The deploy script and its subcommands — `git ls-files | grep -Ei 'deploy'`; read its `case`
  or `help` block
- Which branch the deploy script pulls — `git grep -n "git pull\|git checkout\|git fetch" -- '*deploy*'`
- Migrations at boot vs a separate step —
  `git grep -n -i "migrat" -- '*compose*' '*entrypoint*' '*deploy*' '*Dockerfile*'`
- Replica count / restart policy — `git grep -n "replicas\|restart:" -- '*compose*'`
- Native WebView origins in CORS (`capacitor://localhost`, `https://localhost`) —
  `git grep -n "capacitor://localhost" -- {{BACKEND_DIR}}`
- Credentials with insecure defaults in compose — `git grep -n -E "(PASSWORD|SECRET|TOKEN)[^=]*[:=].*(:-|admin|change-me)" -- '*compose*'`
- `NODE_ENV` wiring in prod compose — `git grep -n "NODE_ENV" -- '*compose*'`
- Tooling stacks that could live elsewhere (build portal, error tracker) —
  `git ls-files | grep -Ei 'ops/|glitchtip|sentry|dist-server'`

**Decide:**
1. **Downtime window or rolling deploys?** — other rules (in-place migration changes, rollback
   across migrations) lean on this answer.
   - Ours: downtime window — one backend process, `up` is stop, start, migrate at boot, serve;
     a written expand/contract rule must exist *before* moving to rolling.
   - Also common: rolling / blue-green with expand/contract migrations (zero downtime, needs
     discipline on every schema change); PaaS-managed releases (rollout is the platform's).
   - Evidence: replica count, restart policy, `container_name` use, migration step.
   - Lands in: "Deploy shape".
2. **What does the host deploy from?** — decides whether "merged" equals "deployed".
   - Ours: no fixed answer, but whatever branch the deploy script pulls must be written down; a
     long-lived deploy branch means merging to `{{MAIN_BRANCH}}` deploys nothing by itself.
   - Also common: deploy straight from `{{MAIN_BRANCH}}` (simplest); a long-lived deploy branch
     (gated promotion); CI-built images pulled by tag (host holds no source logic).
   - Evidence: the deploy-branch grep above.
   - Lands in: "Deploy branches and the host".
3. **Missing production credentials: refuse to boot, generate, or default?** — decides what a
   forgotten variable does.
   - Ours: refuse to boot, naming the offending variables (never the values); no default, no
     `:?` in compose.
   - Also common: generate a random secret on first boot and print it once (fits single-tenant
     self-hosted installs); inject from a secret manager and fail at the platform.
   - Evidence: insecure-defaults grep above.
   - Lands in: "Production-safety defaults".
4. **Who runs the reverse proxy and TLS?** — decides which nginx lessons are yours.
   - Ours: a host nginx with vhosts symlinked from the checkout, certbot on the host.
   - Also common: a proxy container in the compose stack (config versioned with the image);
     managed ingress / CDN / PaaS TLS (drop the nginx section entirely).
   - Evidence: proxy files in the repo, certbot references in the deploy script.
   - Lands in: "Reverse proxy (nginx) lessons".
5. **Do tooling stacks (build portal, error tracker) share the app host?** — ask only if the
   detect step found such a stack.
   - Ours: each its own compose project and env file, so they can move to another server alone.
   - Also common: hosted SaaS instead (drop the section); same compose as the app (simpler,
     restarts together).
   - Evidence: tooling-stack grep above.
   - Lands in: "Tooling stacks leave the app host".

**Web, on request:** release notes of the detected proxy (nginx/Caddy/Traefik version) for
changed defaults; the TLS-certificate tool's current renewal behaviour; the container runtime's
restart-policy semantics. Skip if deployment belongs to someone else.

## guides/ci-cd.md — CI/CD

**Applies when:** the repo has CI definitions —
`git ls-files .github/workflows .gitlab-ci.yml .circleci Jenkinsfile 'azure-pipelines*' '*pipeline*.yml'`
returns a path — or builds container images for a registry.
**Otherwise:** prune — no pipeline to describe. (If the team plans CI, keep-as-reference: the
build-once and pin-the-version lessons transfer.)

**Detect, don't ask:**
- The CI product — which of the paths above exists
- Whether images are built and pushed in CI —
  `git grep -n -E "docker (build|push)|build-push-action|buildx" -- <ci files>`
- Path filters per pipeline — `git grep -n -E "paths|changes:" -- <ci files>`
- A separate build job before the Docker build — look for `npm|pnpm|yarn` build steps ahead of
  the image step in the same file
- Version/tag scheme — `git grep -n -i -E "Rev:r|run_number|tags:|latest" -- <ci files>`
- Registry host — `{{REGISTRY_HOST}}`; `git grep -n "docker login" -- '*deploy*'`
- Build-time public env baked into images — `git grep -n "ARG VITE_\|VITE_" -- '*Dockerfile*'`
- A runtime-env entrypoint (`envsubst`) — `git grep -ln "envsubst" -- '*Dockerfile*' '*.sh'`
- Image set — `git ls-files '*Dockerfile*'`

**Decide:**
1. **Who builds the images: CI, or the target host?** — decides the whole page.
   - Ours: CI builds and pushes; the host only pulls and runs (a small box that builds fills its
     disk and hangs).
   - Also common: the host builds (one VM, hobby scale, accept the cost); a PaaS builds from git
     (then this page shrinks to path filters and versions).
   - Evidence: image build/push grep; presence of a host-side `build` command in the deploy script.
   - Lands in: "Why builds do not run on the target host", "Deploying".
2. **Image tag scheme** — decides rollback and "what is running".
   - Ours: `1.0.<counter>` from the CI counter, `-dev` on the mainline, suffix dropped on
     `release/*`, plus a moving `latest_<branch>` alias; hosts pin the version.
   - Also common: semver from git tags (releases are deliberate); commit SHA (no counter needed,
     unreadable); CalVer.
   - Evidence: the tag-scheme grep above.
   - Lands in: "Pipeline shape" (Versions), "Deploying" (Pin the version).
3. **Public build-time env: baked per environment, or resolved at container start?** — decides
   whether CI needs any environment at all.
   - Ours: placeholders in an isolated chunk, filled by the entrypoint from the container env; one
     image for any environment, CI holds no variables.
   - Also common: baked at build per environment (simple; one image per environment, CI holds the
     values); fully server-side config (no browser env at all).
   - Evidence: `ARG VITE_` and `envsubst` greps.
   - Lands in: "Environment variables resolve at container start".
4. **Image granularity and pipelines** — decides the rebuild blast radius.
   - Ours: one image per deployable (static front surfaces share one nginx image), one pipeline
     per image with its own path filter and counter.
   - Also common: a single pipeline and image for a small monorepo; one image per surface.
   - Evidence: Dockerfile count; path-filter grep.
   - Lands in: "Image set", "Pipeline shape".
5. **Registry credentials on the host** — decides who a departure or password change breaks.
   - Ours: a scoped, pull-only robot account, never a personal login.
   - Also common: cloud-IAM roles on the host (no stored credential); a shared deploy user.
   - Evidence: `docker login` instructions in the deploy script.
   - Lands in: "`401 Unauthorized` on pull".

**Web, on request:** the detected CI product's current rules for path filters, reusable
workflows/templates and auto-discovery of pipeline files; the registry's behaviour for 401 vs
404 on private projects.

## guides/native-builds.md — Native app builds (Capacitor)

**Applies when:** a Capacitor project exists —
`git ls-files '**/capacitor.config.*'` returns a path, and `@capacitor/core` is in a
`package.json` (`git grep -l "@capacitor/core" -- '**/package.json'`).
**Otherwise:** prune, together with `native-ios-release.md`, `native-push.md` and
`dist-server-portal.md`. For React Native / Flutter / fully native apps offer keep-as-reference
only for the app-id, version-stamp and release-env-guard lessons — the rest is Capacitor-specific.

**Detect, don't ask:**
- Capacitor major version — `package.json` dependency `@capacitor/core`
- Native projects tracked or ignored —
  `git ls-files {{MOBILE_DIR}}/ios {{MOBILE_DIR}}/android` and
  `git check-ignore -v {{MOBILE_DIR}}/ios {{MOBILE_DIR}}/android`
- The app id in each place — `git grep -n -E "appId|applicationId|namespace |PRODUCT_BUNDLE_IDENTIFIER" -- {{MOBILE_DIR}}`
  (all hits must agree)
- JDK pinning in build scripts — `git grep -n "JAVA_HOME" -- '*.sh' '*.mjs' 'package.json'`
- Version stamp script and its arithmetic — `git grep -n -E "versionCode|CFBundleShortVersionString" -- {{MOBILE_DIR}} ':!**/node_modules/**'`
- How Android release is assembled — `git grep -n -E "assembleRelease|assembleDebug|bundleRelease|signingConfig" -- {{MOBILE_DIR}}`
- A release-env precondition check — `git grep -ln -i "release_env\|\.env\.production" -- '*.sh' '*.mjs'`
- A dev-server URL branch in the Capacitor config — `git grep -n "server" -- '**/capacitor.config.*'`
- Source-map upload — `git grep -n -i "sentryVitePlugin\|SENTRY_AUTH_TOKEN" -- {{MOBILE_DIR}}`

**Decide:**
1. **Are `ios/` and `android/` tracked or generated?** — decides whether native settings are
   reviewed files or re-asserted by scripts.
   - Ours: tracked (preferred); `cap add` is a first-time generator only.
   - Also common: gitignored and regenerated, with the build script re-asserting icons,
     permissions, plist keys and the version on every run (fits teams that rarely touch native).
   - Evidence: the tracked/ignored check above.
   - Lands in: "Native projects: tracked or generated".
2. **Version scheme** — decides store acceptance and re-review frequency.
   - Ours: the package manifest is the single source; visible version is `major.minor` only;
     `versionCode = major*10000 + minor*100 + patch` (minor and patch capped at 99); iOS build
     number bumps per upload.
   - Also common: CI run number as `versionCode`/build number (fits when a CI exists; decouples
     from the manifest); full `major.minor.patch` visible (every bump triggers external review).
   - Evidence: the stamp-script grep.
   - Lands in: "Version number is a review decision".
3. **What does the "release" channel ship on Android?** — decides signing and store eligibility.
   - Ours: `dev` = thin shell loading JS from the LAN dev server, `release` = production bundle
     inside; an Android "release" built by `assembleDebug` is debug-signed and says so.
   - Also common: store-signed `bundleRelease` AAB with an upload keystore (needed for Play);
     a signed `assembleRelease` APK for sideloading.
   - Evidence: the Android assembly grep.
   - Lands in: "`dev` and `release` name what is inside the bundle".
4. **Is a release env file a hard precondition?** — decides whether a misconfigured build can
   ship green.
   - Ours: yes — a check, parsed the way Vite parses, called by every consumer; fails closed on a
     missing file, warns (does not fail) on a private LAN host.
   - Also common: env injected by CI with no file on disk (the check reads the process env);
     no check (acceptable only when one person builds).
   - Evidence: the release-env grep.
   - Lands in: "The release env file is a precondition".
5. **How do iOS builds reach testers?** — decides whether iOS has a `dev` channel.
   - Ours: asymmetric — `dev` runs from Xcode on a tethered device and is never published;
     `release` goes to TestFlight and only the join link is published.
   - Also common: ad-hoc / enterprise OTA distribution (needs registered devices or an
     enterprise account); TestFlight internal-only (no public link).
   - Evidence: iOS scripts under the mobile dir; export method.
   - Lands in: "iOS is asymmetric".

**Web, on request:** the JDK, Gradle/AGP, Xcode and CocoaPods versions required by the detected
Capacitor major; Apple's current minimum Xcode/SDK for App Store Connect uploads; the status of
`altool` versus Transporter / `notarytool`-style replacements; Play's current target-SDK and
signing requirements.

## guides/native-ios-release.md — iOS release and TestFlight

**Applies when:** an iOS project ships through TestFlight or the App Store —
`git ls-files '**/ios/**/project.pbxproj'` returns a path and `git grep -n -i "altool\|xcodebuild archive\|fastlane\|testflight" -- '*.sh' '*.mjs' '*.md' package.json`
shows an upload path. Depends on `native-builds.md`.
**Otherwise:** prune (Android-only, or iOS not shipped yet). If iOS is planned, keep-as-reference
and revisit when the first upload is near.

**Detect, don't ask:**
- Bundle id — `git grep -n "PRODUCT_BUNDLE_IDENTIFIER" -- {{MOBILE_DIR}}/ios`
- Entitlements (push, associated domains) — `git ls-files '**/*.entitlements'`
- Signing style — `git grep -n -E "CODE_SIGN_STYLE|allowProvisioningUpdates|provisioningProfile" -- {{MOBILE_DIR}}`
- Export method and upload tool — `git grep -n -E "method|altool|fastlane|Transporter" -- '*.sh' '*.mjs' '*.plist'`
- Profile-expiry warning in the build script — `git grep -n -i "expir" -- '*.sh' '*.mjs'`
- Installed Xcode — `xcodebuild -version`
- Where secrets live (`.p8`, `.mobileprovision`) — `git check-ignore -v` on the secrets folder

**Decide:**
1. **How is the app signed?** — decides who must hold an Admin role and when.
   - Ours: manual signing, set up once on the build machine (CSR generated there, no exported
     `.p12`), because cloud signing needs an Admin-role API key.
   - Also common: cloud signing with an Admin key (least setup, needs permanent Admin);
     fastlane `match` (shared certificates in a private repo; several build machines or CI).
   - Evidence: signing-style grep.
   - Lands in: "Step 3 — Signing".
2. **API key role and kind** — decides what the pipeline silently depends on.
   - Ours: a Team Key with App Manager, used only to upload; never an Individual Key.
   - Also common: an Admin key (needed for cloud signing); an Individual Key (solo developer).
   - Evidence: key id and role in the gitignored `.env`; ask who created it.
   - Lands in: "Step 4 — App Store Connect API key".
3. **Who holds Admin, and until when?** — not detectable; decides the order of Apple-console
   work.
   - Ours: do every Admin-only step (identifier, devices, certificates, profiles) while the
     elevated role lasts; the ordinary build loop needs App Manager only.
   - Also common: permanent Admin (small team, drop the urgency); a separate account holder who
     must be asked per step (write the contact path into the page).
   - Evidence: none — ask.
   - Lands in: "The organising constraint".
4. **Tester model** — decides whether a public join link exists.
   - Ours: an External group with a Public Link, recorded in the env variable the publish script
     reads; internal testers are the fallback.
   - Also common: Internal only (no review, up to 100 testers, no link); email invites.
   - Evidence: a TestFlight-link variable in `.env.example`.
   - Lands in: "Step 6 — TestFlight tester groups".

**Web, on request:** Apple's current App Store Connect API key roles, Beta App Review timing,
certificate / profile validity periods, the `exportOptions` method names for the installed Xcode,
and any upload-tool deprecations.

## guides/dist-server-portal.md — Internal build-distribution portal

**Applies when:** the repo contains its own service that hosts mobile builds for testers — a
package that accepts APK uploads and lists TestFlight links: `git grep -l -i "testflight" -- '*.ts' '*.js' ':!**/node_modules/**'`
hits a server package (not just the mobile scripts), and that package has an upload dependency
(`git grep -l "multer\|busboy\|formidable" -- '**/package.json'`). Depends on `native-builds.md`.
**Otherwise:** prune — testers install through a third-party channel (App Distribution, Play
testing tracks, TestFlight alone) and there is no portal to describe.

**Detect, don't ask:**
- The portal package and its compose service —
  `git grep -n -i "builds\|downloads" -- '*compose*'`; the package's `package.json` name
- Credential variables and their prod handling — `git grep -n -i -E "ADMIN|TOKEN|PASSWORD" -- <portal dir> '*.env.example'`
- Published interface in dev — `git grep -n -B1 -A3 "ports:" -- '*compose*dev*'`
- Proxy vs service upload limits — `git grep -n "client_max_body_size"` and
  `git grep -n -i "fileSize\|limits" -- <portal dir>`
- The publish script — `git grep -ln "api/builds\|publish" -- '*.sh' '*.mjs' package.json`
- Lint/format gate coverage — whether the portal package has an ESLint config and is in the root
  lint script

**Decide:**
1. **Own portal or third-party channel?** — decides whether this page exists at all.
   - Ours: an own small service: APK files plus TestFlight join links, latest build on top.
   - Also common: Firebase App Distribution / Play internal testing (no server to run, account
     required for testers); TestFlight only (iOS-only products).
   - Evidence: portal package presence.
   - Lands in: whole page (prune if third-party).
2. **Who may reach it?** — decides the gate in front of builds.
   - Ours: basic auth for viewers plus a bearer token for publishers, both mandatory in production
     (the service refuses to boot with defaults); the proxy adds no further gate.
   - Also common: VPN / IP allowlist at the proxy (builds never touch the open internet); SSO in
     front; expiring signed download links.
   - Evidence: credential grep; whether the proxy config has `auth_basic` or `allow`.
   - Lands in: "In production the credentials have no defaults".
3. **How exposed is the dev instance?** — decides the weak-default risk on shared networks.
   - Ours: published on every interface in dev so a phone on the same Wi-Fi can install; the
     shipped dev defaults are weak and must be overridden in the root `.env`.
   - Also common: loopback-only plus a tunnel for phones; dev instance not run at all (publish
     only to the shared one).
   - Evidence: the dev `ports:` grep.
   - Lands in: "Operating notes".
4. **Where does it run in production?** — decides what restarts with the app.
   - Ours: the ops/tooling stack, its own compose project and env file, bound to `127.0.0.1`
     behind a proxy; one instance only (the store is in memory and rewritten whole).
   - Also common: beside the app in one compose project (simpler, restarts together); a separate
     small server.
   - Evidence: compose project layout.
   - Lands in: "Operating notes".

**Web, on request:** current Android sideloading rules and Play Protect behaviour for APKs
installed from a browser; iOS install restrictions relevant to your tester audience. Skip
otherwise.

## guides/native-push.md — Native push

**Applies when:** the mobile app implements push — `git grep -l -i -E "push-notifications|PushNotifications|aps-environment|firebase-messaging" -- {{MOBILE_DIR}} ':!**/node_modules/**' ':!**/Pods/**'`
returns a path. Depends on `native-builds.md`.
**Otherwise:** prune — push is not implemented. If planned, keep-as-reference and revisit when
work starts.

**Detect, don't ask:**
- Official plugin or an in-repo one — `package.json` dependency `@capacitor/push-notifications`
  versus `git ls-files | grep -i plugin` and a path pod in `{{MOBILE_DIR}}/ios/App/Podfile`
- Firebase in the Android build — `git grep -n -i "firebase\|google-services" -- {{MOBILE_DIR}}/android`
- `aps-environment` in the entitlements — `git grep -n "aps-environment" -- '*.entitlements'`
- `POST_NOTIFICATIONS` in the manifest — `git grep -n "POST_NOTIFICATIONS" -- {{MOBILE_DIR}}/android`
- Android `minSdkVersion` — `git grep -n "minSdkVersion" -- {{MOBILE_DIR}}/android`
- Tap handling and route validation — `git grep -n -i "pushNotificationActionPerformed\|notification_id\|route" -- {{MOBILE_DIR}}/src`
- Sign-out unregister — `git grep -n -i "unregister" -- {{MOBILE_DIR}}/src`
- Registration listener and retry — `git grep -n "addListener('registration'" -- {{MOBILE_DIR}}/src`

**Decide:**
1. **Official Capacitor plugin or an in-repo plugin?** — decides whether Firebase is in the app.
   - Ours: (none shipped as a default) — official unless the product must not contain Firebase;
     then a small in-repo plugin (APNs directly on iOS, the chosen vendor SDK on Android).
   - Also common: official plugin (least code); a managed push SaaS SDK (extra vendor, own
     dashboard).
   - Evidence: dependency and Firebase greps.
   - Lands in: "Own plugin or the official one".
2. **What happens to push on sign-out?** — decides whether the next holder of the phone receives
   the last user's notifications.
   - Ours: unregister first, while the access token is valid, inside a ~3 s time box that never
     throws; native unregister plus deleting the device row; accepted gaps written down.
   - Also common: server-side revoke only (simpler, a window of misdelivery); block sign-out
     until the unregister completes (strict, bad offline).
   - Evidence: unregister grep.
   - Lands in: "Sign-out detaches the phone".
3. **What does a tap carry, and how is it validated?** — decides what an outside party can make
   the app open.
   - Ours: an address only (`notification_id`, `route`), never content; the route must be an
     absolute in-app path, with a safe-screen fallback.
   - Also common: a full payload for offline rendering (bigger privacy surface); a typed action
     enum instead of a path.
   - Evidence: tap-handler grep.
   - Lands in: "Taps".
4. **Is a failed token POST retried?** — decides how stale device rows get.
   - Ours: no retry; the next launch registers again; the `registration` listener re-posts on any
     token change.
   - Also common: retry with backoff / an offline queue (fewer silent gaps, more code).
   - Evidence: registration grep.
   - Lands in: "Registration is a stream".

**Web, on request:** the Capacitor push plugin changelog for the installed major; Android
notification-permission and background-delivery rules for the targeted API level; APNs
token/entitlement changes; the chosen vendor SDK's minimum SDK and maven coordinates.

## guides/client-monitoring.md — Client monitoring

**Applies when:** the clients use a Sentry-protocol SDK —
`git grep -l "@sentry/" -- '**/package.json'` returns a path, or a DSN variable appears in an
`.env.example` (`git grep -n -i "SENTRY_DSN\|VITE_SENTRY" -- '*.env*'`).
**Otherwise:** prune — or, if the team plans error reporting, keep-as-reference for the
invariants and the scrubber sections.

**Detect, don't ask:**
- SDK packages and versions — `git grep -n "@sentry/" -- '**/package.json'`
- The tracker server (hosted vs self-hosted) — the host in the DSN example; a tracker service in
  a compose file: `git grep -n -i "glitchtip\|sentry" -- '*compose*'`
- Where init runs and the "only one file imports the SDK" rule — `git grep -ln "@sentry/" -- {{MOBILE_DIR}}/src {{FRONTEND_DIR}}/src`
- Scrubbers — `git grep -n "beforeSend\|beforeBreadcrumb" -- {{MOBILE_DIR}}/src {{FRONTEND_DIR}}/src`
- Trace-header propagation — `git grep -n "tracePropagationTargets" -- {{MOBILE_DIR}}/src {{FRONTEND_DIR}}/src`
- Source-map upload — `git grep -n "sentryVitePlugin" -- '*vite.config.*'`; a PWA plugin's own
  source maps — `git grep -n "sourcemap" -- '*vite.config.*'`
- Regex lookbehind in browser code — `git grep -n -E "\(\?<[=!]" -- {{MOBILE_DIR}}/src {{FRONTEND_DIR}}/src`
- A CSP that could block probes — `git grep -n -i "Content-Security-Policy"`
- Whether the tracker shares a host with the API — compare the DSN host with `VITE_API_*` values
- Existing watchdogs / hang detectors — `git grep -n -i "stall\|watchdog\|heartbeat" -- {{MOBILE_DIR}}/src`

**Decide:**
1. **Hosted or self-hosted tracker?** — decides SDK pinning, retention and what leaves your
   network.
   - Ours: either; the rule is to pin the SDKs to what the server can ingest and keep events off
     the same host as the API where practical.
   - Also common: hosted Sentry (no server to run, data leaves your infrastructure); self-hosted
     Sentry-protocol server such as GlitchTip (data stays, ingest lags the SDK).
   - Evidence: tracker-server detection above.
   - Lands in: opening paragraph, "Gotchas" (Pin the SDKs).
2. **Do you need the hang detector?** — it is most of the page's code.
   - Ours: shipped as "if you need one" — registry of in-flight requests, stall episodes opening
     at ~15 s, probes every ~30 s, closing after ~15 s clean, persisted across app kills.
   - Also common: skip it and keep the invariants and scrubber (the usual choice when users have
     not reported freezes that leave no server trace); a lighter long-task / ANR breadcrumb only.
   - Evidence: watchdog grep; support reports of freezes (ask).
   - Lands in: "The hang detector".
3. **What counts as personal data to scrub?** — decides the scrubber's patterns.
   - Ours: phones, emails, card and account numbers, tokens; query strings and fragments dropped;
     no request bodies, headers or cookies; the unmasked remainder listed.
   - Also common: add national-id / passport / address patterns for your jurisdiction; send no
     breadcrumbs at all (strictest).
   - Evidence: scrubber grep; the product's data classes (ask).
   - Lands in: "Scrubbing".
4. **Trace propagation headers?** — decides whether `sentry-trace` / `baggage` reach your API.
   - Ours: off (`tracePropagationTargets: []`) — new request headers break requests if CORS does
     not allow them.
   - Also common: on for your own API origins, after adding both headers to the CORS allow-list
     (distributed traces client to server).
   - Evidence: the propagation grep and the backend's CORS config.
   - Lands in: "Invariants".
5. **Ship a hidden diagnostics panel?** — decides whether testers can self-report.
   - Ours: yes, behind a hidden gesture on the version line (pending requests, probe, report a
     hang, test event); it works without a DSN.
   - Also common: none; visible in a settings screen for beta builds only.
   - Evidence: existing hidden-gesture UI.
   - Lands in: "The diagnostics panel".

**Web, on request:** changelogs of the installed Sentry JS / Capacitor SDK majors (breaking
changes to `init`, router instrumentation, offline transport); the self-hosted server's list of
supported envelope types and SDK versions; the oldest supported iOS WebView's JavaScript feature
gaps (regex lookbehind, newer syntax).
