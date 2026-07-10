# Publishing (CI)

Releases are automated by `.github/workflows/release.yml`. It runs **only on `master`**
(i.e. after a branch is merged) and publishes **only when the addon version is new**
(no matching `vX.Y.Z` git tag yet), so doc-only merges don't republish.

The zip is built by `scripts/package.sh` — the **exact same artifact** as a local build
(dev-only `Tools/Generator.lua` and the `EasyMountFarmerGen` saved var stripped, mount
data baked in). It is then uploaded to **CurseForge** and **Wago**, and attached to a
**GitHub Release** tagged `vX.Y.Z`.

## One-time setup

1. **Create the projects** (first upload usually has to be done by hand):
   - CurseForge: create the addon project, note its numeric **Project ID** (project page sidebar).
   - Wago Addons (wago.io): create the project, note its **Project ID**.

2. **GitHub → Settings → Secrets and variables → Actions**
   - Secrets (New repository secret):
     - `CF_API_KEY` — CurseForge API token (curseforge.com → account → API tokens).
     - `WAGO_API_TOKEN` — Wago API token (wago.io → account → API).
   - Variables (New repository variable):
     - `CF_PROJECT_ID` — the CurseForge numeric project id.
     - `WAGO_PROJECT_ID` — the Wago project id.

3. **GitHub → Settings → Actions → General → Workflow permissions**: set **Read and write**
   (so the workflow can create tags and releases).

If a secret is missing, the matching upload step is skipped (the GitHub Release still runs),
so nothing breaks before the tokens are in place.

## Cutting a release

1. Work on a **branch**; open a PR (the `Validate` workflow checks Lua syntax).
2. Bump `## Version:` in `EasyMountFarmer/EasyMountFarmer.toc` and add a `## [x.y.z]`
   section to `CHANGELOG.md` (its body becomes the release notes).
3. Merge to `master` → `Release` builds, publishes to CurseForge + Wago, and tags `vx.y.z`.

To baseline the current version without republishing it, create its tag once:
`git tag v0.2.1 && git push origin v0.2.1`.
