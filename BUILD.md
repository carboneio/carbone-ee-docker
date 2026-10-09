# Docker build instruction


Official build is done by the `Release Carbone Docker` GitHub Action (`.github/workflows/publish.yml`). Each platform is built natively on a GitHub-hosted runner (`ubuntu-24.04` for amd64, `ubuntu-24.04-arm` for arm64) and pushed by digest; a final job merges both digests of every variant into a multi-platform image and applies the tags from `docker-bake.hcl`.

## Versions

Component versions (Carbone, LibreOffice, OnlyOffice, Chrome) and image tags are defined **only** in [`docker-bake.hcl`](docker-bake.hcl). The Dockerfile has no default versions and the workflow inputs are empty by default.

To release a new version, update the variable in `docker-bake.hcl`, commit, then run the workflow. Filling a version input in the workflow overrides `docker-bake.hcl` for that run only.

## Local build

```bash
# Show the resolved versions, build-args and tags without building
docker buildx bake --print

# Build one variant for the current platform and load it in the local docker
docker buildx bake full --load --set '*.platform='

# Build every published variant (slim, full, no-onlyoffice, full-fonts) for amd64 + arm64
docker buildx bake

# Override a version for one build
CARBONE_VERSION=5.15.5 docker buildx bake full --load --set '*.platform='
```

Other targets: `no-libreoffice`, `no-chrome`. `full-fonts` needs a `carbone-fonts` folder (from `carboneio/carbone-fonts`, without `custom/`).

## Binary signature verification

Artefacts downloaded from `bin.carbone.io` are verified with `cosign verify-blob` against their Sigstore bundle (`<file>.sigstore.json`, keyless signature from GitHub Actions, issuer `https://token.actions.githubusercontent.com`). The build fails if a bundle is missing or the signature does not match the expected release workflow.

| Stage | Artefact | Signing workflow |
|-------|----------|------------------|
| `downloader_carbone` | `carbone/carbone-ee-<version>-linux-<arch>` | `carboneio/carbone-ee/.github/workflows/build.yml` |
| `downloader_libreoffice` | `libreoffice-headless-carbone/LibreOffice_<version>_Linux_<arch>_deb.tar.gz` | `carboneio/libreoffice-headless-builder/.github/workflows/build-x86.yml` (amd64) / `build-arm64.yml` (arm64) |
| `downloader_onlyoffice` | `onlyoffice-converter/onlyoffice-converter-standalone_<version>_<arch>.deb` | `carboneio/onlyoffice-converter-standalone-debian/.github/workflows/publish.yml` |

Only versions released with signing can be built: Carbone 5.15.4+, LibreOffice 26.2.6.3+, OnlyOffice packages republished with a `.sigstore.json`.

To verify a binary downloaded manually:

```bash
FILE=carbone-ee-$CARBONE_VERSION-linux-x64
curl -fO https://bin.carbone.io/carbone/$FILE -fO https://bin.carbone.io/carbone/$FILE.sigstore.json
cosign verify-blob $FILE --bundle $FILE.sigstore.json \
  --certificate-identity-regexp '^https://github\.com/carboneio/carbone-ee/\.github/workflows/build\.yml@refs/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
