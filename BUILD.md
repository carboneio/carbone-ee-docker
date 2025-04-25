# Docker build instruction


Official build is done by github action

To run it locally : 

```bash
#!/bin/bash
export CARBONE_VERSION=4.25.8
export LO_VERSION=25.2.3.1

docker buildx build --platform linux/arm64/v8,linux/amd64 --build-arg CARBONE_VERSION --tag carbone/carbone-ee:slim-$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true -f ./Dockerfile-slim .
docker buildx build --platform linux/arm64/v8,linux/amd64 --build-arg CARBONE_VERSION --build-arg LO_VERSION --tag carbone/carbone-ee:full-$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true -f ./Dockerfile .
docker buildx build --platform linux/arm64/v8,linux/amd64 --build-arg CARBONE_VERSION --build-arg LO_VERSION --tag carbone/carbone-ee:full-$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true -f ./Dockerfile-fonts .
```