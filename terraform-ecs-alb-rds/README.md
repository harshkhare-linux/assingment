# ECS Fargate + ALB + RDS (Terraform)

Provisions a standard 3-tier setup on AWS:

```
Internet → ALB (public subnets) → ECS/Fargate (private subnets) → RDS (private subnets)
```

## Architecture

- **VPC** — single VPC with 2 public subnets and 2 private subnets across 2 AZs.
- **Public subnets** — host the ALB and the NAT Gateway. Route to Internet Gateway.
- **Private subnets** — host ECS/Fargate tasks and the RDS instance. Route out to internet via NAT Gateway (needed for pulling container images), no inbound path from the internet.
- **ALB** — internet-facing, listens on port 80, forwards to the ECS target group.
- **ECS/Fargate** — cluster + task definition + service running the app container (defaults to `nginx:latest` as a placeholder), tasks run in private subnets with no public IP.
- **RDS** — PostgreSQL (or MySQL, see below), `publicly_accessible = false`, sits in the private subnets.

### Security groups

| SG | Inbound | Purpose |
|---|---|---|
| `alb-sg` | 80 from `0.0.0.0/0` | Public entry point |
| `ecs-sg` | container port from `alb-sg` only | ECS only reachable via ALB |
| `rds-sg` | db port from `ecs-sg` only | RDS only reachable from ECS tasks |

RDS has no route in or out of the VPC to the public internet — it's only reachable from tasks running in the ECS security group.

## Files

| File | Contents |
|---|---|
| `provider.tf` | Terraform + AWS provider config |
| `variables.tf` | All input variables |
| `vpc.tf` | VPC, subnets, IGW, NAT gateway, route tables |
| `security_groups.tf` | ALB / ECS / RDS security groups |
| `alb.tf` | ALB, target group, listener |
| `ecs.tf` | ECS cluster, IAM execution role, task definition, service |
| `rds.tf` | DB subnet group, RDS instance |
| `outputs.tf` | ALB DNS name, cluster name, RDS endpoint, VPC ID |

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with credentials that have permission to create VPC/ECS/ALB/RDS/IAM resources
- An AWS account/region with room for a NAT Gateway + Elastic IP

## Usage

1. Set the DB password (don't commit it to a `.tfvars` file):

   ```bash
   export TF_VAR_db_password="your-strong-password"
   ```

2. Initialize and review the plan:

   ```bash
   terraform init
   terraform plan
   ```

3. Apply:

   ```bash
   terraform apply
   ```

4. Once applied, get the ALB URL:

   ```bash
   terraform output alb_dns_name
   ```

   Open `http://<alb_dns_name>` in a browser — you should see the placeholder container's response (nginx welcome page by default).

## Key variables (`variables.tf`)

| Variable | Default | Notes |
|---|---|---|
| `aws_region` | `ap-south-1` | Change to your target region |
| `project_name` | `demo-app` | Prefix used in resource names/tags |
| `vpc_cidr` | `10.0.0.0/16` | |
| `public_subnet_cidrs` / `private_subnet_cidrs` | 2 each | Adjust for more AZs if needed |
| `container_image` | `nginx:latest` | Point this at your real app image |
| `container_port` | `80` | Must match what your container listens on |
| `db_engine` | `postgres` | Set to `mysql` to switch engines |
| `db_engine_version` | `15.4` | Use a valid version for your chosen engine (e.g. `8.0` for MySQL) |
| `db_port` | `5432` | Use `3306` for MySQL |
| `db_instance_class` | `db.t3.micro` | Bump for production workloads |
| `db_password` | *(required, no default)* | Pass via `TF_VAR_db_password`, never commit |

## Switching to MySQL

In `variables.tf` (or via `-var` flags), set:

```hcl
db_engine         = "mysql"
db_engine_version = "8.0"
db_port           = 3306
```

## Notes / things to adjust before production use

- `skip_final_snapshot = true` is set on the RDS instance for easy teardown in dev — turn this off for production.
- `multi_az = false` — enable for production HA.
- ECS `desired_count = 2` — adjust to your capacity/cost needs; consider adding an autoscaling policy.
- No HTTPS listener is configured — add an ACM certificate and a 443 listener on the ALB if you need TLS.
- The app container currently gets DB connection info via plain environment variables (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`) — the password is not injected into the container; wire up Secrets Manager / SSM Parameter Store for that in a real app.

## Cleanup

```bash
terraform destroy
```

This tears down everything, including the RDS instance (no final snapshot is taken, since `skip_final_snapshot = true`).
