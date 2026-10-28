---
title: CI/CD — images are built in CI, the target host only runs them
class: compiled
covers: []                 # fill when adopting: the pipeline definitions folder, the deploy script
last-verified: never
verified-by: boilerplate
sources: []
---

# CI/CD: build in CI, run on the host

The pipeline shape, and the lessons that shaped it. Nothing here depends on the CI product (GitHub
Actions, GitLab CI, Azure Pipelines, Jenkins all fit); the one place where a product's behaviour
differs is the short "If you use Azure Pipelines" subsection below. Images go to a container
registry (`{{REGISTRY_HOST}}`). Host-side concerns (proxy, env files, deploy shape) are in
[`deployment.md`](./deployment.md); local Docker is [`docker-workflow.md`](./docker-workflow.md).

## Why builds do not run on the target host

A small staging box that builds its own bundles and images fills its disk, exhausts its memory and
periodically hangs — while the services it produced use almost nothing. So CI builds and pushes
finished images; the host pulls them and starts them. Nothing is compiled on the host: no
`node_modules`, no package-manager store, no build cache. The same shape works for every service
the team runs (a pipeline publishes an image; a separate compose rolls it out).

```
push to {{MAIN_BRANCH}} -> CI (docker build, docker push) -> registry/<project>/<image>:<version>
                                                                   |
                          host: deploy.sh pull-up  (git pull; compose pull; up -d)
                                                                   |
                          host proxy (TLS) -> containers
```

## Image set: split by deployable, merge what shares a commit

Typically: the **static front surfaces** in one nginx image, the **API/mock server** in one Node
image, and **tooling** (build portal) in one. Static surfaces that come out of one commit of one
monorepo share an image: separate images would be several names for the same thing and more
containers on a box whose whole problem is its size (the content is kilobytes; the image weight is
nginx). The routing between surfaces lives in the image's nginx config, so the host proxy needs no
knowledge of how the front end is laid out.

## Environment variables resolve at container start (when the bundle is static)

Public build-time values (`VITE_*`) can be left as literal `${VITE_…}` placeholders in an isolated
chunk and filled by the container's entrypoint from its environment before nginx starts. Reasons,
weakest first so it is not mistaken for the argument:

- Not really secrecy — a public browser key reaches every visitor anyway; keeping it out of the
  image is tidiness.
- **CI needs no environment**: no variable group, no pipeline secrets, no build that fails because
  someone forgot a value. Values stay on the host, in the `.env` already there.
- **One image, any environment**, which is what makes "promote the exact artefact you tested"
  possible once there is more than one environment.

Two traps, both found by measuring:

- **A naive implementation still ships the whole environment.** Vite replaces `import.meta.env`
  with an object literal of every `VITE_*` visible at build time, so a dev fallback doing a dynamic
  `import.meta.env[key]` pulls the entire env into the chunk. Guard it with `if
  (import.meta.env.DEV)` — dead code in production, but only when `NODE_ENV=production`, which a
  dev `.env` may contradict. Set it in the Dockerfile **and fail the build if any value in the
  runtime-env chunk is not a placeholder.** Don't remove that check.
- **`envsubst` over a bundle is demolition.** With no variable list it replaces every `${…}` it
  finds, and an application bundle is full of ordinary template literals. Two defences: placeholders
  live in an isolated chunk (`manualChunks`), and the entrypoint names the variables explicitly.

Adding a variable is therefore three edits: the runtime-env module, the entrypoint's list, and the
compose `environment:` block. Miss the second and the browser receives the literal `${VITE_…}`
string, which is **truthy**.

## Pipeline shape

```
<ci-folder>/
  templates/docker-image-template.yml     # the shared definition (or reusable workflow / include)
  <app>-docker-pipeline.yml               # one per image
```

- **Own the shared definition.** If the organisation's shared template lives in a project you can
  neither read nor review, copy its shape rather than depend on it; switching to the shared one
  later is a few lines per pipeline.
- **No separate build job.** A template that runs `install && build`, publishes an artefact, and
  then builds a Dockerfile that runs the build *again* never lets the artefact reach the image.
  Build once, inside the Dockerfile. In a workspace monorepo that is also the only thing that
  works: `cd <app> && install` resolves neither workspace packages nor the root lockfile.
- **Path filters are not an optimisation.** In a monorepo, without them every commit — a mock
  route, a note in the wiki — rebuilds every image, usually on a runner pool shared with other
  teams. List the app **plus the shared libraries it compiles from source**.
- **One pipeline per image**, not one for all: each has its own path filter (a mock-server change
  doesn't rebuild the front end) and its own version counter (versions don't jump when a sibling
  builds).
- **Versions** `1.0.<counter>`, with `-dev` on the mainline and the suffix dropped on `release/*`.
  The counter belongs to the CI system, not git, so two builds of one commit get two versions —
  which is what makes a tag immutable. Also move a branch alias (`latest_<branch>`) on every build;
  name it after *your* mainline branch.
- **Some CI systems do not auto-discover pipeline files** and need each one registered by hand,
  pointing at a path in the repo; others pick up every file in a conventional folder. Know which
  you have, because a pipeline file that was never registered does not fail — it never runs.
  Registration is one pipeline per file.
- **Run the thing that failed before it failed.** Changes to proxy routing can return 200 for pages
  and break every asset; run a real nginx in front of the real image and request assets, rather
  than reading config:

  ```bash
  docker build -f <path-to>/front/Dockerfile -t <image>:dev .
  docker run --rm -p 8099:80 -e VITE_API_BASE_URL=/api <image>:dev
  # curl each surface's index AND one asset from each
  ```

### If you use Azure Pipelines

- Register each pipeline by hand: New pipeline → repo → *Existing Azure Pipelines YAML file* →
  path. **Rename it afterwards**: the wizard names it after the repository, and the YAML's `name:`
  is the run-number format, not the pipeline's name.
- Path filters are `trigger.paths.include`; the per-pipeline counter is the `$(Rev:r)` in `name:`.
- Reusing a shared template from another project is `extends` / `resources.repositories`; see "Own
  the shared definition" above for when not to.

## Deploying

On the host, once: `docker login {{REGISTRY_HOST}}` and the deploy script's `setup` (link the proxy
config; re-run it when the proxy config changed in the same change). Then every time:

```bash
./tools/deploy.sh pull-up     # git pull + compose pull + up -d
./tools/deploy.sh images      # what is actually running
```

`git pull` still matters — it updates the script, compose file and proxy config — but has nothing
to do with the code that runs.

**Pin the version.** The host's `.env` carries `<IMAGE>_VERSION` for each image. Defaulting to the
moving alias is convenient and wrong for anything you might need to undo: a moving tag can't tell
you what is running and can't be rolled back to. Put the version the pipeline reported; rollback is
one line and `pull-up`.

**Delete the old build commands from the deploy script** rather than keeping them as a fallback —
a command that can refill the disk is the same problem with a longer fuse. Have them answer with a
pointer to `pull-up`.

## `401 Unauthorized` on pull, when `docker login` succeeded

Some registries (e.g. Harbor) answer `401` both for "you may not see this" and for "there is no such
tag" — deliberately, so a private project can't be probed. The status code alone tells you nothing,
and bad credentials, a missing tag and a wrong name are all still open. Tell them apart by pulling
things whose existence is already known, in this order:

| probe | meaning if it FAILS |
|---|---|
| an image from another project this account should reach | the account has no access anywhere, or isn't really logged in |
| an image from **your** project that other deployments already pull | the whole project is closed to this account; your images are irrelevant to it |
| your image with an explicit version | only now is it about *your* image — a missing tag, not a missing permission |

That ordering separates a project-membership fault from a pipeline fault without touching the
pipelines. If it does come down to your image, the authoritative record of what was published is
the **push step's own log** (`docker push …`); a "report what was published" step built from
template parameters says what the pipeline *intended* to push, which is not the same claim.

**Use a scoped, pull-only robot account on the host, not a personal login** — unaffected by a
person's password change or departure. The credentials sit in `~/.docker/config.json` in plain text
either way, acceptable for a pull-only robot and not for someone's account.
