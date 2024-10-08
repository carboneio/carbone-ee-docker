# carbone-ee-docker
Carbone enterprise edition official docker container

## Build

### Build slim variant
```bash
export CARBONE_VERSION=4.23.6

docker buildx build --build-arg CARBONE_VERSION=$CARBONE_VERSION --platform linux/arm64/v8,linux/amd64 --tag carbone/carbone-ee:$CARBONE_VERSION-slim --attest type=provenance,mode=max --sbom=true ./DockerFile-slim
```

### Build full variant
```bash
export CARBONE_VERSION=4.23.6

docker buildx build --build-arg CARBONE_VERSION=$CARBONE_VERSION --build-arg LO_VERSION=24.8.2.1 --platform linux/arm64/v8,linux/amd64 --tag carbone/carbone-ee:$CARBONE_VERSION --attest type=provenance,mode=max --sbom=true ./DockerFile-slim
```

## Quick reference

- 	**Maintained by**:  [Carbone Team](https://carbone.io)

- 	**Documentation**: [On-premise install, options and plugins](https://carbone.io/on-premise.html)

-	**Where to get help**:  [Chat with us](https://go.crisp.chat/chat/embed/?website_id=189afeb5-0aef-4ca8-9b66-4f7951fc7d34) or email us : contact@carbone.io

## What is Carbone?

Carbone is a simple and efficient tool that allows you to generate all your documents.
Send a template file and a JSON dataset, and the engine will return the document with all the data inside. Many formats are supported: PDF, ODT, DOCX, XLSX, HTML, XML, PPTX, JPG, PNG, TXT, CSV, EPUB, IDML, ODS, PPTX, ODG, and ODP.

![logo](https://carbone.io/img/carbone_icon_v3_github.png)

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
### Carbone Images Tags and Versions

For each version of Carbone, it exists two image variations
- **carbone/carbone-ee:latest** : Latest version of Carbone containing only standard Debian fonts.
- **carbone/carbone-ee:latest-fonts** : Latest version of Carbone containing standard Debian fonts and all [Google Fonts](https://fonts.google.com) (royalty-free).

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

### Environment Variables

#### `CARBONE_EE_LICENSE `

License as a string, if the option is used, default license path (/app/config/*.carbone-license) is skipped

#### `CARBONE_EE_FACTORIES`

Multithread parameter, number of LibreOffice converter

#### `CARBONE_EE_WORKDIR`

The value must be a path; it defines the place to store resources. Carbone on startup creates six directories:
- `template`: directory that stores templates
- `render`: directory that stores generated documents
- `config`: directory that includes the config file, licenses and ES512 keys for authentication
- `plugin`: directory for custom plugins
- `asset`: internal used only

#### `CARBONE_EE_AUTHENTICATION`

Authentification documentation at the following [link](https://carbone.io/on-premise.html#server-authentication)

#### `CARBONE_EE_STUDIO`

Web interface to preview reports.

#### `CARBONE_EE_STUDIOUSER`

If the authentication option is enabled, the browser requests an authentication to access the web page. Credentials must be formated with the following format: [username]:[password].

#### `CARBONE_EE_MAXDATASIZE`

The maximum JSON data size accepted when rendering a report is bytes. Calcul example: 100 * 1024 * 1024 = 100MB

#### `CARBONE_EE_TEMPLATEPATHRETENTION`

Template path retention in days. 0 means infinite retention.

#### `CARBONE_EE_EN`

Locale language used by Carbone

#### `CARBONE_EE_TIMEZONE`

Timezone for managing dates

#### `CARBONE_EE_CURRENCYSOURCE`

Currency source for money conversion. If empty, it depends on the locale.

#### `CARBONE_EE_CURRENCYTARGET`

Currency target for money conversion. If empty, it depends on the locale.

#### `CARBONE_EE_CONVERTERFACTORYTIMEOUT`

Maximum conversion/socket timeout for one render (unit: ms) (default 60000)

## Image variants

### ```carbone-ee:<version>-fonts```

This version includes all free Google Fonts.
