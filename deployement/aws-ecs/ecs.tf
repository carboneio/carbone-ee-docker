##########################
## Terraform Setup
##########################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
  profile = "ecs"
}

##########################
## Variable
##########################
variable "region" {
  description = "AWS region to use for this deployement"  
  type = string
  default = "us-east-1"
}

variable "template_storage" {
  description = "Save template on persistent place"  
  type = bool
  default = true
}

variable "render_storage" {
  description = "Save render on shared place"  
  type = bool
  default = false
}

variable "efs_storage" {
  description = "Use EFS share for perssistency"  
  type = bool
  default = true
}

variable "s3_storage" {
  description = "Use S3 share for perssistency"
  type = bool
  default = false
}

variable "studio" {
  description = "Enable Carbone Studio web interface"
  type        = bool
  default     = true
}

variable "template_management" {
  description = "Enable Carbone Template Management API"
  type        = bool
  default     = false
}

variable "debug" {
  description = "Enable ECS Exec on tasks (allows docker exec into running containers)"
  type        = bool
  default     = false
}


##########################
## Network configuration
##########################
resource "aws_vpc" "carbone-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "Carbone Network"
  }
}

data "aws_region" "current" {}

resource "aws_subnet" "carbone-private-subnet-AZ1" {
  vpc_id     = aws_vpc.carbone-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "Carbone Private Network AZ1"
    ST = "Carbone"
  }

  depends_on = [ aws_vpc.carbone-vpc ]
}

resource "aws_subnet" "carbone-private-subnet-AZ2" {
  vpc_id     = aws_vpc.carbone-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "${data.aws_region.current.name}b"

  tags = {
    Name = "Carbone Private Network AZ2"
    ST = "Carbone"
  }

  depends_on = [ aws_vpc.carbone-vpc ]
}

resource "aws_subnet" "carbone-public-subnet-AZ1" {
  vpc_id     = aws_vpc.carbone-vpc.id
  cidr_block = "10.0.10.0/24"
  availability_zone = "${data.aws_region.current.name}a"

  tags = {
    Name = "Carbone Public Network AZ1"
    ST = "Carbone"
  }

  depends_on = [ aws_vpc.carbone-vpc ]
}

resource "aws_subnet" "carbone-public-subnet-AZ2" {
  vpc_id     = aws_vpc.carbone-vpc.id
  cidr_block = "10.0.11.0/24"
  availability_zone = "${data.aws_region.current.name}b"

  tags = {
    Name = "Carbone Public Network AZ2"
    ST = "Carbone"
  }

  depends_on = [ aws_vpc.carbone-vpc ]
}

resource "aws_internet_gateway" "cluster-iwg" {
  vpc_id = aws_vpc.carbone-vpc.id

  tags = {
    Name = "Carbone Cluster IWG"
    ST = "Carbone"
  }
}

resource "aws_eip" "gateway-ip" {
  domain = "vpc"

  depends_on = [ aws_internet_gateway.cluster-iwg ]
}

resource "aws_nat_gateway" "carbone-network-nat" {
  allocation_id = aws_eip.gateway-ip.id
  subnet_id     = aws_subnet.carbone-public-subnet-AZ1.id

  tags = {
    Name = "Carbone Cluster NAT"
    ST = "Carbone"
  }

  depends_on = [aws_internet_gateway.cluster-iwg]
}

resource "aws_route_table" "private-route" {
  vpc_id = aws_vpc.carbone-vpc.id
}

resource "aws_route" "private-route-1" {
  route_table_id         = aws_route_table.private-route.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.carbone-network-nat.id
}

resource "aws_route_table_association" "private-AZ1" {
  subnet_id      = aws_subnet.carbone-private-subnet-AZ1.id
  route_table_id = aws_route_table.private-route.id
}

resource "aws_route_table_association" "private-AZ2" {
  subnet_id      = aws_subnet.carbone-private-subnet-AZ2.id
  route_table_id = aws_route_table.private-route.id
}

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.carbone-vpc.id
}

resource "aws_route" "public-route-1" {
  route_table_id         = aws_route_table.public-route.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cluster-iwg.id
}

resource "aws_route_table_association" "public-AZ1" {
  subnet_id      = aws_subnet.carbone-public-subnet-AZ1.id
  route_table_id = aws_route_table.public-route.id
}

resource "aws_route_table_association" "public-AZ2" {
  subnet_id      = aws_subnet.carbone-public-subnet-AZ2.id
  route_table_id = aws_route_table.public-route.id
}

#############################
## ECS Cluster configuration
#############################
resource "aws_ecs_cluster" "carbone-cluster" {
  name = "CarboneCluster"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  configuration {
    execute_command_configuration {
      logging    = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = "CarboneClusterLog"
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "carbone-cluster-provider" {
  cluster_name = aws_ecs_cluster.carbone-cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_service_discovery_http_namespace" "carbone" {
  name = "carbone-internal"
}

##########################
## Carbone Service Role
##########################
resource "aws_iam_role" "carbone_role" {
  name = "carbone_service_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    ST = "Carbone"
  }
}

resource "aws_iam_role_policy_attachment" "carbone_ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.carbone_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "cloudwatch_logs" {
  name = "CarboneCloudWatchLogs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "carbone_CloudWatchLogs_policy" {
  role       = aws_iam_role.carbone_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

resource "aws_iam_policy" "secretAccess" {
  name        = "ReadSecret"
  policy      = jsonencode({
    Version: "2012-10-17",
	Statement: [
      {
	    Effect: "Allow",
	    Action: "secretsmanager:GetSecretValue",
	    Resource: "*"
	  }
	]
  })
}

resource "aws_iam_role_policy_attachment" "carbone_SecretAccess_policy" {
  role       = aws_iam_role.carbone_role.name

  policy_arn = aws_iam_policy.secretAccess.arn
}

##########################
## Carbone Task Role
##########################
resource "aws_iam_role" "carbone_task_role" {
  name = "carbone_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    ST = "Carbone"
  }
}

resource "aws_iam_role_policy" "carbone_task_exec_policy" {
  count = var.debug ? 1 : 0
  name  = "carbone-ecs-exec-policy"
  role  = aws_iam_role.carbone_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

###################################
## Persistance Data configuration
###################################

check "efs_template_management_incompatibility" {
  assert {
    condition     = !(var.efs_storage && var.template_management)
    error_message = "EFS storage is incompatible with template_management when running more than one task. SQLite (used for template metadata) relies on POSIX fcntl locks that NFS/EFS does not guarantee across multiple clients — this causes SQLITE_IOERR errors and risks database corruption. Use s3_storage = true instead."
  }
}

resource "aws_efs_file_system" "carbone-shared-storage" {
  count = var.efs_storage == true ? 1 : 0
  creation_token = "carbone-persistant-storage"
  encrypted = true

  tags = {
    Name = "Carbone Persistant Storage"
  }

  lifecycle {
    precondition {
      condition = var.render_storage || var.template_storage
      error_message = "No need to set efs storage. Please set efs_storage variable to false"
    }
  }
}

resource "aws_security_group" "carbone_efs" {
  count = var.efs_storage == true ? 1 : 0
  name        = "Carbone EFS"
  description = "Allow NFS inbound traffic"
  vpc_id      = aws_vpc.carbone-vpc.id

  ingress {
    description      = "EFS from container"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [ 
      aws_subnet.carbone-private-subnet-AZ1.cidr_block,
      aws_subnet.carbone-private-subnet-AZ2.cidr_block ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EFS access"
    ST = "Carbone"
  }
}

resource "aws_efs_mount_target" "efs-mount-az1" {
  count = var.efs_storage == true ? 1 : 0
  file_system_id = aws_efs_file_system.carbone-shared-storage[0].id
  subnet_id      = aws_subnet.carbone-private-subnet-AZ1.id
  security_groups = [ aws_security_group.carbone_efs[0].id ]
}

resource "aws_efs_mount_target" "efs-mount-az2" {
  count = var.efs_storage == true ? 1 : 0
  file_system_id = aws_efs_file_system.carbone-shared-storage[0].id
  subnet_id      = aws_subnet.carbone-private-subnet-AZ2.id
  security_groups = [ aws_security_group.carbone_efs[0].id ]
}

resource "aws_efs_access_point" "template-access" {
  count = var.efs_storage && var.template_storage  ? 1 : 0
  file_system_id = aws_efs_file_system.carbone-shared-storage[0].id
  posix_user {
    uid = 1000
    gid = 1000
  }
  root_directory {
    path = "/template"
    creation_info {
      permissions = 755
      owner_gid = 1000
      owner_uid = 1000
    }
  }
  tags = {
    Name = "Carbone-template"
  }
}

resource "aws_efs_access_point" "render-access" {
  count = var.efs_storage && var.render_storage ? 1 : 0
  file_system_id = aws_efs_file_system.carbone-shared-storage[0].id
  posix_user {
    uid = 1000
    gid = 1000
  }
  root_directory {
    path = "/render"
    creation_info {
      permissions = 755
      owner_gid = 1000
      owner_uid = 1000
    }
  }
  tags = {
    Name = "Carbone-render"
  }
}

resource "aws_s3_bucket" "template_s3_storage" {
  count = var.s3_storage && var.template_storage ? 1 : 0

  bucket = "carbone-template-${random_id.bucket_suffix.hex}"

  lifecycle {
    precondition {
      condition = (!var.efs_storage && var.s3_storage) || !var.s3_storage
      error_message = "Do not set s3_storage in same time than efs_storage"
    }
  }
  
}

resource "aws_s3_bucket" "render_s3_storage" {
  count = var.s3_storage && var.render_storage ? 1 : 0

  bucket = "carbone-render-${random_id.bucket_suffix.hex}"

  lifecycle {
    precondition {
      condition = (!var.efs_storage && var.s3_storage) || !var.s3_storage
      error_message = "Do not set s3_storage in same time than efs_storage"
    }
  }
}

## Create IAM user
resource "aws_iam_user" "s3_carbone_user" {
  count = var.s3_storage ? 1 : 0
  name = "carbone-s3-user"

  tags = {
    Name        = "carbone-s3-user"
    Description = "User to acces to Carbone buckets"
  }
}

## Get API key
resource "aws_iam_access_key" "s3_user_key" {
  count = var.s3_storage ? 1 : 0
  user = aws_iam_user.s3_carbone_user[0].name
}

resource "aws_secretsmanager_secret" "s3_credentials" {
  count                   = var.s3_storage ? 1 : 0
  name                    = "carbone/s3-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "s3_credentials" {
  count     = var.s3_storage ? 1 : 0
  secret_id = aws_secretsmanager_secret.s3_credentials[0].id
  secret_string = jsonencode({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.s3_user_key[0].id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.s3_user_key[0].secret
  })
}

## Assign policy
resource "aws_iam_user_policy" "s3_readwrite" {
  count = var.s3_storage ? 1 : 0
  name = "carbone-s3-user-policy"
  user = aws_iam_user.s3_carbone_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = concat(
          var.template_storage ? [aws_s3_bucket.template_s3_storage[0].arn] : [],
          var.render_storage ? [aws_s3_bucket.render_s3_storage[0].arn] : [])
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = concat(
          var.template_storage ? ["${aws_s3_bucket.template_s3_storage[0].arn}/*"] : [],
          var.render_storage ? ["${aws_s3_bucket.render_s3_storage[0].arn}/*"] : [])
      }
    ]
  })
}

##########################
## Carbone Service 
##########################
resource "aws_ecs_task_definition" "carbone-service" {
  family = "carboneService"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "ARM64"
  }
  container_definitions = jsonencode([
    {
      name      = "Carbone"
      image     = "carbone/carbone-ee:full"
      essential = true
      stopTimeout = 20
      environment = concat([
        {
          name  = "CARBONE_EE_STUDIO"
          value = tostring(var.studio)
        },
        {
          name  = "CARBONE_EE_FACTORIES"
          value = "2"
        },
        {
          name  = "CARBONE_TEMPLATE_MANAGEMENT"
          value = tostring(var.template_management)
        }],
        var.template_management ? [
          {
            name  = "CARBONE_PEER_PORT"
            value = "5001"
          },
          {
            name  = "CARBONE_PEER_ENDPOINTS"
            value = "ws://carbone"
          },
          {
            name  = "CARBONE_TEMPLATE_METADATA_FLUSH_CRON"
            value = "* * * * *"
          }
        ] : [],
        var.s3_storage ? [
          {
            name  = "AWS_REGION"
            value = var.region
          },
          {
            name  = "AWS_ENDPOINT_URL"
            value = "s3.${var.region}.amazonaws.com"
          }
        ] : [],
        var.template_storage && var.s3_storage ? [
          {
            name  = "BUCKET_TEMPLATES"
            value = aws_s3_bucket.template_s3_storage[0].bucket
          }
        ] : [],
        var.render_storage && var.s3_storage ? [
          {
            name  = "BUCKET_RENDERS"
            value = aws_s3_bucket.render_s3_storage[0].bucket
          }
        ] : [],
        var.debug ? [
          {
            name  = "DEBUG"
            value = "carbone:*"
          }
        ] : []
      )
      secrets = concat(
        [
          {
            name      = "CARBONE_EE_LICENSE"
            valueFrom = "arn:aws:secretsmanager:eu-west-3:307069698794:secret:carbone-ee/license-G0jIkt"
          }
        ],
        var.s3_storage ? [
          {
            name      = "AWS_ACCESS_KEY_ID"
            valueFrom = "${aws_secretsmanager_secret.s3_credentials[0].arn}:AWS_ACCESS_KEY_ID::"
          },
          {
            name      = "AWS_SECRET_ACCESS_KEY"
            valueFrom = "${aws_secretsmanager_secret.s3_credentials[0].arn}:AWS_SECRET_ACCESS_KEY::"
          }
        ] : []
      )
      logConfiguration= {
        logDriver= "awslogs"
        options= {
          awslogs-create-group= "true"
          awslogs-group= "awslog-carbone"
          awslogs-region= "${data.aws_region.current.name}"
          awslogs-stream-prefix= "Carbone"
        }
      }
      portMappings = [
        {
          containerPort = 4000
          hostPort      = 4000
        },
        {
          containerPort = 5001
          hostPort      = 5001
          name          = "carbone-cluster"
          appProtocol   = "http"
        }
      ]
      mountPoints = concat(
        var.render_storage && var.efs_storage ? [{
          sourceVolume  = "render-storage"
          containerPath = "/app/render"
          readOnly      = false
        }] : [],
        var.template_storage && var.efs_storage ? [{
          sourceVolume  = "template-storage"
          containerPath = "/app/template"
          readOnly      = false
        }] : []
      )
    },
    {
      name      = "adot-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = false
      command   = ["--config", "env:AOT_CONFIG_CONTENT"]
      environment = [
        {
          name  = "AOT_CONFIG_CONTENT"
          value = local.adot_config
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "awslog-carbone"
          awslogs-region        = "${data.aws_region.current.name}"
          awslogs-stream-prefix = "adot"
        }
      }
    }
  ])
  dynamic "volume" {
    for_each = var.efs_storage && var.template_storage ? [1] : []
    content {
      name = "template-storage"

      efs_volume_configuration {
        file_system_id          = aws_efs_file_system.carbone-shared-storage[0].id
        transit_encryption      = "ENABLED"
        authorization_config {
          access_point_id       = aws_efs_access_point.template-access[0].id
        }
      }
    }
  }
  dynamic "volume" {
    for_each = var.efs_storage && var.render_storage ? [1] : []
    content {
      name = "render-storage"

      efs_volume_configuration {
        file_system_id          = aws_efs_file_system.carbone-shared-storage[0].id
        transit_encryption      = "ENABLED"
        authorization_config {
          access_point_id       = aws_efs_access_point.render-access[0].id
        }
      }
    }
  }
  execution_role_arn = aws_iam_role.carbone_role.arn
  task_role_arn      = aws_iam_role.carbone_task_role.arn
  tags = {
    ST = "Carbone"
  }
}

resource "aws_ecs_service" "carbone" {
  name                   = "carbone"
  cluster                = aws_ecs_cluster.carbone-cluster.id
  task_definition        = aws_ecs_task_definition.carbone-service.arn
  desired_count          = 2
  platform_version       = "LATEST"
  enable_execute_command = var.debug

  load_balancer {
    target_group_arn = aws_lb_target_group.carbone-tg.arn
    container_name   = "Carbone"
    container_port   = 4000
  }

  lifecycle {
    ignore_changes = [
      capacity_provider_strategy,
      desired_count
    ]
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.carbone.arn
    service {
      port_name      = "carbone-cluster"
      discovery_name = "carbone"
      client_alias {
        port     = 5001
        dns_name = "carbone"
      }
    }
  }

  network_configuration {
    subnets = [
        aws_subnet.carbone-private-subnet-AZ1.id,
        aws_subnet.carbone-private-subnet-AZ2.id]
    security_groups = [ aws_security_group.carbone_service.id ]
  }

  depends_on = [ 
    aws_subnet.carbone-private-subnet-AZ1,
    aws_subnet.carbone-private-subnet-AZ2,
    aws_lb_target_group.carbone-tg ]
}


#################################
## Carbone Service LoadBalancer
#################################
resource "aws_lb_target_group" "carbone-tg" {
  name     = "carbone-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.carbone-vpc.id
  target_type = "ip"

  depends_on = [aws_alb.carbone-alb]

  health_check {
    enabled             = true
    interval            = 20
    matcher             = "200"
    path                = "/status"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "Carbone Target Group"
    ST = "Carbone-Test"
  }
}

resource "aws_alb" "carbone-alb" {
  name         = "carbone-alb"
  idle_timeout = 300
  subnets = [
    aws_subnet.carbone-public-subnet-AZ1.id,
    aws_subnet.carbone-public-subnet-AZ2.id
  ]

  security_groups = [
    aws_security_group.carbone_alb.id
    ]

  tags = {
    Name = "Carbone Load Balancer"
    ST = "Carbone"
  }
}

resource "aws_alb_listener" "carbone-alb-listener"   {
  load_balancer_arn = aws_alb.carbone-alb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.carbone-tg.arn
  }
}

resource "aws_security_group" "carbone_service" {
  name        = "Carbone"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.carbone-vpc.id

  ingress {
    description             = "HTTP from ALB only"
    from_port               = 4000
    to_port                 = 4000
    protocol                = "tcp"
    security_groups         = [aws_security_group.carbone_alb.id]
  }

  ingress {
    description = "Inter-task communication"
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description      = "NFS from VPC"
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = [ 
      aws_subnet.carbone-private-subnet-AZ1.cidr_block,
      aws_subnet.carbone-private-subnet-AZ2.cidr_block
    ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Carbone service"
    ST = "Carbone"
  }
}

resource "aws_security_group" "carbone_alb" {
  name        = "Carbone LoadBalancer"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.carbone-vpc.id

  ingress {
    description      = "HTTP from outside"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Carbone service"
    ST = "Carbone"
  }
}

##########################
## ADOT — Prometheus → CloudWatch
##########################
locals {
  adot_config = <<-EOT
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: carbone
          scrape_interval: 15s
          static_configs:
            - targets: ['localhost:5001']
          metric_relabel_configs:
            - source_labels: [__name__]
              regex: 'queued'
              action: keep
processors:
  batch/metrics:
    timeout: 60s
exporters:
  awsemf:
    namespace: Carbone/ECS
    log_group_name: /carbone/metrics
    dimension_rollup_option: NoDimensionRollup
    metric_declarations:
      - dimensions: [[ClusterName, ServiceName]]
        metric_name_selectors:
          - queued
extensions:
  health_check:
service:
  extensions: [health_check]
  pipelines:
    metrics:
      receivers: [prometheus]
      processors: [batch/metrics]
      exporters: [awsemf]
EOT
}

resource "aws_ssm_parameter" "adot_config" {
  name  = "/carbone/adot-config"
  type  = "String"
  value = local.adot_config
}

resource "aws_iam_role_policy" "carbone_task_cloudwatch_metrics" {
  name = "carbone-cloudwatch-put-metrics"
  role = aws_iam_role.carbone_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/carbone/metrics:*"
      }
    ]
  })
}

##########################
## Autoscaling
##########################
resource "aws_appautoscaling_target" "ecs_carbone_target" {
  max_capacity       = 15
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.carbone-cluster.name}/${aws_ecs_service.carbone.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_carbone_target_queued" {
  name               = "application-scaling-policy-queued"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_carbone_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_carbone_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_carbone_target.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = "queued"
      namespace   = "Carbone/ECS"
      statistic   = "Sum"
      dimensions {
        name  = "ClusterName"
        value = aws_ecs_cluster.carbone-cluster.name
      }
      dimensions {
        name  = "ServiceName"
        value = aws_ecs_service.carbone.name
      }
    }
    target_value       = 5
    scale_out_cooldown = 30
    scale_in_cooldown  = 120
    disable_scale_in   = true
  }
  depends_on = [aws_appautoscaling_target.ecs_carbone_target]
}

resource "aws_appautoscaling_policy" "ecs_carbone_target_cpu" {
  name               = "application-scaling-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_carbone_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_carbone_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_carbone_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 40
    scale_out_cooldown = 30
    scale_in_cooldown  = 120
  }
  depends_on = [aws_appautoscaling_target.ecs_carbone_target]
}

##########################
## Outputs
##########################
output "service_url" {
  description = "Carbone service URL"
  value       = "http://${aws_alb.carbone-alb.dns_name}"
}
