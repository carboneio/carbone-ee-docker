# Docker build instruction


Official build is done by github action

To run it locally : 

```bash
#!/bin/bash
export CARBONE_VERSION=5.15.4
export LO_VERSION=26.2.6.3
export OO_VERSION=9.0.4
export CHROME_VERSION=134.0.6998.166

docker buildx build --platform linux/arm64/v8,linux/amd64 --build-arg CARBONE_VERSION --tag carbone/carbone-ee:slim-$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true -f ./Dockerfile --target slim .
docker buildx build --platform linux/arm64/v8,linux/amd64 --build-arg CARBONE_VERSION --build-arg LO_VERSION --build-arg OO_VERSION --build-arg CHROME_VERSION --tag carbone/carbone-ee:full-$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true -f ./Dockerfile --target full .
docker buildx build --platform linux/arm64/v8,linux/amd64 --build-arg CARBONE_VERSION --build-arg LO_VERSION --build-arg OO_VERSION --build-arg CHROME_VERSION --tag carbone/carbone-ee:full-$CARBONE_VERSION-fonts --attest type=provenance,mode=max --sbom=true -f ./Dockerfile --target full-fonts .

# Other available --target values: no-onlyoffice, no-libreoffice, no-chrome
```

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
