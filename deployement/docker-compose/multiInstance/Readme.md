# Sample multi instance deployement

Cet example illustre un deployement Carbone sur docker avec 3 instances, un noeud nginx et un stockage des templates sur un bucket S3.

## Setup

Creez le ficher `.env` avec le contenu suivant : 
```bash
AWS_ACCESS_KEY_ID=<Your S3 Acces Key>
AWS_SECRET_ACCESS_KEY=<Your S3 Secret Acces Key>
AWS_ENDPOINT_URL=<S3 endpoint, for ex : s3.eu-west-1.amazonaws.com>
AWS_REGION=<S3 region, ex : eu-west-1>
BUCKET_TEMPLATES=<S3 bucket to store Templates>
BUCKET_RENDERS=<S3 bucket to store Renders>
```

## Start

```bash
docker compose up -d
```