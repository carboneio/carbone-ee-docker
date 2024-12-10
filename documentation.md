![logo](https://carbone-media.s3.us-east-1.amazonaws.com/20240213_logo_V3_200px.png)

### Quick reference
- 	**Maintained by**:  [Carbone Team](https://carbone.io)

- 	**Full documentation**: [On-premise install, options and plugins](https://carbone.io/on-premise.html)

-   Carbone docker can be used free of charge, but without access to enterprise functions and without support.

-	**Where to get help**:  [Chat with us](https://go.crisp.chat/chat/embed/?website_id=189afeb5-0aef-4ca8-9b66-4f7951fc7d34), [book a time with us](https://carboneio.pipedrive.com/scheduler/5Rzzbxu6/carbone-on-premiseaws-presentation) or email us : contact@carbone.io

## Overview

Carbone is The Most Efficient Universal Future-proof Report Generator. With Carbone, you can generate all the documents you can imagine in just a few minutes.
Send a template file and a JSON dataset, and the engine will return the document with all the data inside. Many formats are supported: PDF, ODT, DOCX, XLSX, HTML, XML, PPTX, JPG, PNG, TXT, CSV, EPUB, IDML, ODS, PPTX, ODG, and ODP.

## Recommended System Requirements

For the Carbone team, optimizing performance is essential. That's why our solution requires very few resources.

You can use this docker image on x86_64 or ARM64 systems.
Recommended configuration is 1CPU with 1024MB memory.

## Running Carbone Community Edition (Forever Free)

Carbone Enterprise Edition is commercial software that requires a license for its use.

However, you can launch Carbone without a license and enjoy all its "Community Edition" features free of charge and without limits.
**Please note that advanced functions will not work, and we do not provide support for this version.**

To find out how to obtain a Carbone license, contact us by [chat](https://go.crisp.chat/chat/embed/?website_id=189afeb5-0aef-4ca8-9b66-4f7951fc7d34), [book a time with us](https://carboneio.pipedrive.com/scheduler/5Rzzbxu6/carbone-on-premiseaws-presentation) or email us: contact@carbone.io

To start Carbone with Community Edition features : 
```console
docker run -t -i --rm -p 4000:4000 carbone/carbone-ee
```

You can then call Carbone API ([Full API documentation](https://carbone.io/api-reference.html#carbone-cloud-api)): 
```console
curl http://host-ip:4000/status
```

## Running Carbone Enterprise Edition

To get started with Carbone Enterprise Edition, you must first contact us to purchase a license. Then simply : 
```console
export CARBONE_EE_LICENSE=`cat your_license_file.carbone-license`

docker run -t -i --rm -p 4000:4000 -e CARBONE_EE_LICENSE carbone/carbone-ee
```

You can then call Carbone API ([Full API documentation](https://carbone.io/api-reference.html#carbone-cloud-api)): 
```console
curl http://host-ip:4000/status
```

## Configuring Docker Image

### Configuring Carbone options

Carbone configuration requires only the passing of an environment variable. 
For example, to activate the Studio, you need to set CARBONE_EE_STUDIO to true: 
```console
docker run -t --rm -e CARBONE_EE_LICENSE -e CARBONE_EE_STUDIO=true carbone/carbone-ee
```

The list of configuration options is [here](https://carbone.io/on-premise.html#server-options)

### Configuring data persistence

#### Minimun configuration (single node)

The minimum configuration we recommend is to configure template persistence.

##### Using S3-compatible storage

By default, our S3-compatible plugins are included. The corresponding code is here : 

All you need to do is configure the following environment variables: 
 - `AWS_SECRET_ACCESS_KEY`=ACCESS_KEY_ID
 - `AWS_ACCESS_KEY_ID`=SECRET_KEY
 - `AWS_ENDPOINT_URL`=s3.api.url
 - `AWS_REGION`=paris
 - `BUCKET_TEMPLATES`="BUCKET NAME to store your templates "

This plugin can be used with all S3-compatible storage services: AWS S3, GCS, Azure Blob Storage, Minio, etc.

##### Mounting a volume for template storage

You can also use a storage space to store `tempaltes`. This can be a mounted folder or a remote storage (S3, OpenStack Swift). [Click to learn more about file persistence.](https://carbone.io/on-premise.html#server-storage-persistence)

#### Multi instance configuration

For multi instance configuration, you also need to store renderings to make them accessible from all Carbone instances.

You can then set the BUCKET_RENDERS environment variable in the same way as for templates, to configure an S3-compatible bucket. 
You can also mount a volume on the /app/render folder of your containers. Note that in this case, the volume must be read/write for all instances.

## Deployment

This image can be deployed in all containerized environments: Docker, Kubernetess, AWS ECS, Azure Container App, CloudRun, ...

## Docker image variant

Three image variants are available: 

- slim, slim-'Carbone Version' : Minimal version of Carbone. This image does not include Libreoffice (no PDF generation possible). You can use this image to run Carbone with the LibreOffice version of your choice.

- latest, full, full-'Carbone Version', full-'Carbone Version'-L'LibreOffice Version' : Full version of Carbone including the latest version of LibreOffice

- latest-fonts, full-fonts, full-'Carbone Version'-fonts, full-'Carbone Version'-L'LibreOffice Version'-fonts : Full version of Carbone including the latest version of LibreOffice. This version also includes all [Google Fonts](https://fonts.google.com) (royalty-free).

## Additional Info

- [Source Code](https://github.com/carboneio/carbone-ee-docker)
- [Licence](https://github.com/carboneio/carbone/blob/master/LICENSE.md)
