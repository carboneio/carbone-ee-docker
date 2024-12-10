# Carbone enterprise edition official docker container

## Quick reference

- 	**Maintained by**:  [Carbone Team](https://carbone.io)

- 	**Documentation**: [On-premise install, options and plugins](https://carbone.io/on-premise.html)

-	  **Where to get help**:  [Chat with us](https://go.crisp.chat/chat/embed/?website_id=189afeb5-0aef-4ca8-9b66-4f7951fc7d34) or email us : contact@carbone.io

## What is Carbone?

![logo](https://carbone-media.s3.us-east-1.amazonaws.com/20240213_logo_V3_200px.png)

Carbone is a simple and efficient tool that allows you to generate all your documents.
Send a template file and a JSON dataset, and the engine will return the document with all the data inside. Many formats are supported: PDF, ODT, DOCX, XLSX, HTML, XML, PPTX, JPG, PNG, TXT, CSV, EPUB, IDML, ODS, PPTX, ODG, and ODP.

## Build

### Build slim variant

Minimal version of Carbone. This image does not include Libreoffice (no PDF generation possible). You can use this image to run Carbone with the LibreOffice version of your choice.

```bash
export CARBONE_VERSION=4.25.0

docker buildx build --build-arg CARBONE_VERSION=$CARBONE_VERSION --platform linux/arm64/v8,linux/amd64 --tag carbone/carbone-ee:$CARBONE_VERSION-slim --attest type=provenance,mode=max --sbom=true -f ./Dockerfile-slim .
```

### Build full variant

Full version of Carbone including the latest version of LibreOffice

```bash
export CARBONE_VERSION=4.25.0

docker buildx build --build-arg CARBONE_VERSION=$CARBONE_VERSION --build-arg LO_VERSION=24.8.2.1 --platform linux/arm64/v8,linux/amd64 --tag carbone/carbone-ee:full-$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true -f ./Dockerfile .
```

### Build fonts variant

Full version of Carbone including the latest version of LibreOffice. This version also includes all [Google Fonts](https://fonts.google.com) (royalty-free).

```bash
export CARBONE_VERSION=4.25.0

docker buildx build --build-arg CARBONE_VERSION=$CARBONE_VERSION --build-arg LO_VERSION=24.8.2.1 --platform linux/arm64/v8,linux/amd64 --tag carbone/carbone-ee:full-$CARBONE_VERSION-fonts --attest type=provenance,mode=max --sbom=true -f ./Dockerfile-fonts .
```

## How to use this image

### Start Carbone instantly

Carbone Enterprise Edition is commercial software that requires a license for its use.

However, you can launch Carbone without a license and enjoy all its "Community Edition" features free of charge and without limits.
**Please note that advanced functions will not work, and we do not provide support for this version.**

To find out how to obtain a Carbone license, contact us by [chat](https://go.crisp.chat/chat/embed/?website_id=189afeb5-0aef-4ca8-9b66-4f7951fc7d34) or email us: contact@carbone.io

To start Carbone with Community Edition features : 
```console
docker run -t -i --rm --platform linux/amd64 -p 4000:4000 carbone/carbone-ee
```

To start Carbone Enterprise Edition : 
```console
export CARBONE_EE_LICENSE=`cat your_license_file.carbone-license`

docker run -t -i --rm --platform linux/amd64 -p 4000:4000 -e CARBONE_EE_LICENSE carbone/carbone-ee
```

You can then call Carbone API ([Full API documentation](https://carbone.io/api-reference.html#carbone-cloud-api)): 
```console
curl http://host-ip:4000/status
```

### Run Carbone via [`docker-compose`](https://github.com/docker/compose)

Example `docker-compose.yml` for `carbone-ee`:
```yaml
version: "3.9"
services:
  carbone:
    image: carbone/carbone-ee
    platform: linux/amd64
    ports:
      - "4000:4000"
    secrets:
      - source: carbone-license
        target: /app/config/prod.carbone-license
    environment:
      - CARBONE_EE_STUDIO=true
secrets:
  carbone-license:
    file: your_license.carbone-license
```

### Carbone into multi instance environnement SWARM / Kubernetes / ECS / CloudRun / ...

With Docker SWARM and Kubernetes, you can run multiple instances of the Carbone container for load balancing and/or failover. 

By default, our S3-compatible plugins are included. The corresponding code is here : 

All you need to do is configure the following environment variables: 
 - `AWS_SECRET_ACCESS_KEY`=ACCESS_KEY_ID
 - `AWS_ACCESS_KEY_ID`=SECRET_KEY
 - `AWS_ENDPOINT_URL`=s3.api.url
 - `AWS_REGION`=paris
 - `BUCKET_RENDERS`="BUCKET NAME to store your generated documents "
 - `BUCKET_TEMPLATES`="BUCKET NAME to store your templates "

This plugin can be used with all S3-compatible storage services: AWS S3, GCS, Azure Blob Storage, Minio, etc.


You can also save `templates` and `renders` (generated documents), a storage space must be shared among all Carbone instances. This can be a mounted folder or a remote storage (S3, OpenStack Swift). [Click to learn more about file persistence.](https://carbone.io/on-premise.html#server-storage-persistence)


### Port Mapping

Standard port mappings can be used if you'd like to access the instance from the host without the container's IP. Add `-p 4000:4000` to the `docker run` arguments and then access either `http://localhost:4000` or `http://host-ip:4000` in a browser.
