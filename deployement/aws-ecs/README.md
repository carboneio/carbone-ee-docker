# Carbone deployment on Amazon Elastic Container Service

This Terraform configuration deploys [Carbone EE](https://carbone.io) on AWS ECS Fargate behind an Application Load Balancer, with optional EFS or S3 storage for templates and renders.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with a profile named `ecs`
- A valid Carbone EE license key

## First deployment

**1. Store the license in Secrets Manager**

```bash
aws secretsmanager create-secret \
  --name carbone-ee/license \
  --secret-string "<your-license-key>" \
  --profile ecs
```

**2. Configure your deployment**

Edit `terraform.tfvars` to match your environment. See the [Configuration](#configuration) section for all available options.

**3. Deploy**

```bash
terraform init
terraform apply
```

The service URL is printed at the end of the apply.

## Architecture

![Architecture](architecture.svg)

> Port 5001 is restricted to intra-cluster traffic only via a self-referencing security group rule.

## Configuration

Options can be set in a `terraform.tfvars` file or passed via `-var` flags.

### General

| Variable | Type | Default | Description |
|---|---|---|---|
| `region` | `string` | `"us-east-1"` | AWS region to deploy into |
| `studio` | `bool` | `false` | Enable the Carbone Studio web interface |
| `template_management` | `bool` | `false` | Enable the Template Management API |
| `debug` | `bool` | `false` | Enable ECS Exec to open a shell into running containers |
| `job_balancer` | `bool` | `false` | Enable Carbone's job balancer (`CARBONE_JOB_BALANCER`) — spreads document conversion load across the peers of a cluster |

### Runtime limits

These map to Carbone's own configuration environment variables (`CARBONE_*`). Defaults below match Carbone's documented defaults — see the [configuration reference](https://carbone.io/documentation/developer/on-premise-installation/configuration.html) for the full list and units.

| Variable | Type | Default | Env variable | Description |
|---|---|---|---|---|
| `max_data_size` | `number` | `62914560` (60MB) | `CARBONE_MAX_DATA_SIZE` | Maximum size (bytes) of the JSON data sent for rendering |
| `max_generation_time` | `number` | `60000` (60s) | `CARBONE_MAX_GENERATION_TIME` | Maximum time (ms) allowed to generate one document, including conversion |
| `max_download_file_size_total` | `number` | `10485760` (10MB) | `CARBONE_MAX_DOWNLOAD_FILE_SIZE_TOTAL` | Total maximum size (bytes) of all files downloaded from external URLs combined |
| `max_download_file_count` | `number` | `20` | `CARBONE_MAX_DOWNLOAD_FILE_COUNT` | Maximum number of files downloaded from external URLs for a single render |
| `max_download_file_timeout` | `number` | `6000` (6s) | `CARBONE_MAX_DOWNLOAD_FILE_TIMEOUT` | Maximum time (ms) allowed to download a file or image from an external URL |
| `max_download_file_concurrency` | `number` | `15` | `CARBONE_MAX_DOWNLOAD_FILE_CONCURRENCY` | Maximum number of concurrent file downloads from external URLs |

> **Naming note** — Since Carbone v5, environment variables use the `CARBONE_` prefix (e.g. `CARBONE_STUDIO`, `CARBONE_FACTORIES`, `CARBONE_MAX_DATA_SIZE`). This task definition uses the modern names; the older pre-v5 `CARBONE_EE_*` names are still accepted by Carbone but are no longer used here.
>
> These are conservative defaults suited to typical workloads. If you render large templates, generate many documents concurrently, or download many external images/files per render, raise these values in `terraform.tfvars` to match your workload.

### Storage

| Variable | Type | Default | Description |
|---|---|---|---|
| `template_storage` | `bool` | `true` | Persist templates on shared storage |
| `render_storage` | `bool` | `false` | Persist rendered files on shared storage |
| `efs_storage` | `bool` | `true` | Use EFS for persistent storage |
| `s3_storage` | `bool` | `false` | Use S3 for persistent storage |

### Storage modes

`efs_storage` and `s3_storage` are mutually exclusive. `template_storage` and `render_storage` control which directories are persisted, independently of the storage backend.

| `efs_storage` | `s3_storage` | `template_storage` | `render_storage` | Result |
|:---:|:---:|:---:|:---:|---|
| `true` | `false` | `true` | `false` | Templates persisted on EFS |
| `true` | `false` | `true` | `true` | Templates + renders persisted on EFS |
| `false` | `true` | `true` | `false` | Templates persisted on S3 |
| `false` | `true` | `true` | `true` | Templates + renders persisted on S3 |
| `false` | `false` | — | — | No persistent storage |

> **EFS + `template_management` are incompatible when running more than one task.**
> The Template Management API uses a SQLite database for metadata. SQLite relies on POSIX `fcntl` advisory locks that NFS/EFS does not reliably enforce across multiple NFS clients — resulting in `SQLITE_IOERR` errors and risk of database corruption. Terraform will emit a warning if both `efs_storage` and `template_management` are enabled. Use `s3_storage = true` in this case.

### Example `terraform.tfvars`

```hcl
region           = "eu-west-3"
template_storage = true
render_storage   = false
efs_storage      = true
s3_storage       = false
```

## Production best practices

**Remote state** — Store the Terraform state in S3 with a DynamoDB lock table to enable team collaboration and prevent concurrent applies:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "carbone/ecs/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

**HTTPS** — Add an HTTPS listener on the ALB with an ACM certificate and redirect HTTP to HTTPS. Never expose port 80 in production.

**IAM permissions** — The `secretsmanager:GetSecretValue` policy currently allows `Resource: "*"`. Restrict it to the exact ARN of the Carbone license secret.

**Disable Studio** — Studio is disabled by default (`studio = false`). Only set it to `true` if you need the web preview interface.

**Disable debug** — Keep `debug = false` in production. ECS Exec opens a shell into running containers and should only be enabled for troubleshooting.

**Image version** — Pin the container image to a specific version instead of `full` to ensure reproducible deployments:

```hcl
image = "carbone/carbone-ee:5.x.x-full"
```

**Autoscaling thresholds** — The default queue target is 5 queued jobs per task. Adjust `max_capacity` and `target_value` in `ecs.tf` based on your actual load profile.

## Autoscaling

The service scales between 2 and 6 tasks using a `TargetTrackingScaling` policy driven by the `queued` metric exposed by Carbone on its `/metrics` endpoint.

### How it works

An [AWS Distro for OpenTelemetry (ADOT)](https://aws-otel.github.io) sidecar container runs inside each ECS task alongside Carbone. It scrapes `localhost:4000/metrics` every 15 seconds, filters the `queued` metric, and publishes it to CloudWatch under the namespace `Carbone/ECS` with `ClusterName` and `ServiceName` dimensions.

Application Auto Scaling reads the average value of `queued` across all running tasks and adjusts the desired count to keep that average at or below the target.

```
/metrics (Prometheus)        CloudWatch             Auto Scaling
  Carbone :4000 ──────► ADOT sidecar ──────► Carbone/ECS::queued ──────► ECS desired count
```

### Scaling parameters

| Parameter | Value | Description |
|---|---|---|
| `target_value` | `5` | Target average number of queued jobs per task |
| `min_capacity` | `2` | Minimum number of running tasks |
| `max_capacity` | `6` | Maximum number of running tasks |
| `scale_out_cooldown` | `30s` | Minimum time between two scale-out events |
| `scale_in_cooldown` | `120s` | Minimum time before scaling in after a scale-out |

**Scale-out example**: if 2 tasks are running and the average `queued` rises to 12, Auto Scaling adds a third task to bring the average back toward 5 (`12 * 2 / 5 ≈ 5 tasks targeted`).

### Tuning

- **`target_value`** — lower values scale out sooner (lower latency, higher cost); higher values tolerate longer queues.
- **`scale_in_cooldown`** — keep this conservative (≥ 120s) to avoid task churn from transient queue spikes.
- **`max_capacity`** — set an upper bound that matches your Fargate quota and cost budget.

To change parameters, edit the `aws_appautoscaling_target` and `aws_appautoscaling_policy.ecs_carbone_target_queued` resources in `ecs.tf` and run `terraform apply`.

### Viewing the metric in CloudWatch

```bash
aws cloudwatch get-metric-statistics \
  --namespace Carbone/ECS \
  --metric-name queued \
  --dimensions Name=ClusterName,Value=CarboneCluster Name=ServiceName,Value=carbone \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average \
  --profile ecs
```

ADOT logs are available in the same CloudWatch log group as Carbone (`awslog-carbone`), under the stream prefix `adot`.

## FAQ

### How to open a shell into a running task?

Enable debug mode (`debug = true`) then apply. Once deployed, retrieve the task ID from the ECS console or CLI and run:

```bash
# List running tasks
aws ecs list-tasks --cluster CarboneCluster --profile ecs

# Open a shell
aws ecs execute-command \
  --cluster CarboneCluster \
  --task <task-id> \
  --container Carbone \
  --interactive \
  --command "/bin/bash" \
  --profile ecs
```

> Disable `debug` and redeploy once troubleshooting is done.

### How to check the service logs?

Logs are sent to CloudWatch under the log group `awslog-carbone`. View them with:

```bash
aws logs tail awslog-carbone --follow --profile ecs
```

### How to retrieve the service URL after deployment?

The URL is printed at the end of `terraform apply`. To retrieve it later:

```bash
terraform output service_url
```

### How to scale the service manually?

```bash
aws ecs update-service \
  --cluster CarboneCluster \
  --service carbone \
  --desired-count 3 \
  --profile ecs
```

Note that autoscaling will override this value once active. To change the baseline permanently, update `desired_count` in `ecs.tf` and run `terraform apply`.

### How to update the Carbone license?

Update the secret value in Secrets Manager then force a new deployment so the tasks restart and pick up the new value:

```bash
aws secretsmanager put-secret-value \
  --secret-id carbone-ee/license \
  --secret-string "<new-license>" \
  --profile ecs

aws ecs update-service \
  --cluster CarboneCluster \
  --service carbone \
  --force-new-deployment \
  --profile ecs
```
