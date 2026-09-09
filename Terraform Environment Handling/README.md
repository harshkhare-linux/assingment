# AWS ECS/Fargate + RDS Terraform Assignment

This repository demonstrates:

- Internet → ALB → ECS/Fargate → RDS
- VPC with public and private subnets
- Separate ALB, ECS, and RDS security groups
- ECS cluster, task definition, and service
- Private PostgreSQL RDS accessible only from ECS
- Reusable Terraform modules
- Separate `dev` and `prod` environments
- Environment-specific tfvars and backend configuration


## Architecture

```text
Internet
   |
   v
Application Load Balancer
(public subnets)
   |
   v
ECS/Fargate Service
(private subnets)
   |
   v
RDS PostgreSQL
(private DB subnets)
```

Security flow:

- Internet → ALB: TCP/80
- ALB → ECS: TCP/80
- ECS → RDS: TCP/5432
- RDS does not allow public access

## Repository Structure

└── infra
    ├── modules
    │   ├── network
    │   ├── ecs
    │   └── rds
    └── envs
        ├── dev
        └── prod
```

## Prerequisites

Install:

- Terraform >= 1.6
- AWS CLI
Configure AWS credentials:

```bash
aws configure
```

## Terraform Backend

The backend files are examples.

Create the S3 state bucket before running Terraform, then update:

```text
infra/envs/dev/backend.hcl
infra/envs/prod/backend.hcl
```

with your real S3 bucket name.

Example backend initialization:

```bash
cd infra/envs/dev
terraform init -backend-config=backend.hcl
```

For production:

```bash
cd infra/envs/prod
terraform init -backend-config=backend.hcl
```

## Database Password

Do not commit database passwords to Git.

Export it before Terraform commands:

```bash
export TF_VAR_db_password='ChangeMe-StrongPassword123!'
```

## Deploy DEV

```bash
cd infra/envs/dev

terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

Get ALB URL:

```bash
terraform output alb_dns_name
```

Open:

```text
http://<alb_dns_name>
```

The default ECS container uses Nginx, so the Nginx welcome page verifies ALB → ECS connectivity.

## Deploy PROD

```bash
cd infra/envs/prod

terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

Production uses:

- Larger ECS task sizing
- Larger RDS instance
- Longer backup retention
- RDS deletion protection enabled