##########################
## Terraform Setup
##########################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-3"
  profile = "ecs"
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
    value = "enabled"
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

resource "aws_iam_role_policy_attachment" "carbone_CloudWatchLogsFullAccess_policy" {
  role       = aws_iam_role.carbone_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
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

###################################
## Persistance Data configuration
###################################
resource "aws_efs_file_system" "carbone-shared-storage" {
  creation_token = "carbone-persistant-storage"
  encrypted = true

  tags = {
    Name = "Carbone Persistant Storage"
  }
}

resource "aws_security_group" "carbone_efs" {
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
  file_system_id = aws_efs_file_system.carbone-shared-storage.id
  subnet_id      = aws_subnet.carbone-private-subnet-AZ1.id
  security_groups = [ aws_security_group.carbone_efs.id ]
}

resource "aws_efs_mount_target" "efs-mount-az2" {
  file_system_id = aws_efs_file_system.carbone-shared-storage.id
  subnet_id      = aws_subnet.carbone-private-subnet-AZ2.id
  security_groups = [ aws_security_group.carbone_efs.id ]
}

resource "aws_efs_access_point" "template-access" {
  file_system_id = aws_efs_file_system.carbone-shared-storage.id
  root_directory {
    path = "/template"
    creation_info {
      permissions = 766
      owner_gid = 65534
      owner_uid = 100
    }
  }
  tags = {
    Name = "Carbone-template"
  }
}

resource "aws_efs_access_point" "render-access" {
  file_system_id = aws_efs_file_system.carbone-shared-storage.id
  root_directory {
    path = "/render"
    creation_info {
      permissions = 766
      owner_gid = 65534
      owner_uid = 100
    }
  }
  tags = {
    Name = "Carbone-render"
  }
}

##########################
## Carbone Service 
##########################
resource "aws_ecs_task_definition" "carbone-service" {
  family = "carboneService"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
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
      environment = [
        { 
          name = "CARBONE_EE_STUDIO"
          value = "true"
        }
      ]
      secrets = [
        {
            name = "CARBONE_EE_LICENSE"
            valueFrom = "arn:aws:secretsmanager:eu-west-3:307069698794:secret:carbone-ee/license-G0jIkt"
        }
      ]
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
        }
      ]
      mountPoints = [
        {
          sourceVolume = "template-storage"
          containerPath = "/app/template"
          readOnly = false
        },
        {
          sourceVolume = "render-storage"
          containerPath = "/app/render"
          readOnly = false
        }
      ]
    }
  ])
  volume {
    name = "template-storage"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.carbone-shared-storage.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id       = aws_efs_access_point.template-access.id
      }
    }
  }
  volume {
    name = "render-storage"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.carbone-shared-storage.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id       = aws_efs_access_point.render-access.id
      }
    }
  }
  execution_role_arn = aws_iam_role.carbone_role.arn
  tags = {
    ST = "Carbone"
  }
}

resource "aws_ecs_service" "carbone" {
  name            = "carbone"
  cluster         = aws_ecs_cluster.carbone-cluster.id
  task_definition = aws_ecs_task_definition.carbone-service.arn
  desired_count   = 1
  platform_version = "LATEST"

  load_balancer {
    target_group_arn = aws_lb_target_group.carbone-tg.arn
    container_name   = "Carbone"
    container_port   = 4000
  }

  lifecycle {
    ignore_changes = [
      capacity_provider_strategy
    ]
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
    enabled = "true"
    interval = 60
    matcher = 200
    path = "/status"
  }

  tags = {
    Name = "Carbone Target Group"
    ST = "Carbone-Test"
  }
}

resource "aws_alb" "carbone-alb" {
  name = "carbone-alb"
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
    description      = "HTTP from VPC"
    from_port        = 4000
    to_port          = 4000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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
## Autoscaling
##########################
resource "aws_appautoscaling_target" "ecs_carbone_target" {
  max_capacity       = 6
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.carbone-cluster.name}/${aws_ecs_service.carbone.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
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
    target_value = 40
  }
  depends_on = [aws_appautoscaling_target.ecs_carbone_target]
}
