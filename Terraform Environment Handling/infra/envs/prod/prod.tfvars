aws_region   = "ap-south-1"
project_name = "ecs-rds-assignment"
environment  = "prod"

vpc_cidr = "10.20.0.0/16"
azs      = ["ap-south-1a", "ap-south-1b"]

public_subnet_cidrs  = ["10.20.1.0/24", "10.20.2.0/24"]
private_subnet_cidrs = ["10.20.11.0/24", "10.20.12.0/24"]

container_image = "nginx:latest"
container_port  = 80
task_cpu        = 512
task_memory     = 1024
desired_count   = 2

db_name              = "appdb"
db_username          = "appuser"
db_instance_class    = "db.t4g.small"
db_allocated_storage = 50

backup_retention_period = 7
deletion_protection     = true
skip_final_snapshot     = false
