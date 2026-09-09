aws_region   = "ap-south-1"
project_name = "ecs-rds-assignment"
environment  = "dev"

vpc_cidr = "10.10.0.0/16"
azs      = ["ap-south-1a", "ap-south-1b"]

public_subnet_cidrs  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs = ["10.10.11.0/24", "10.10.12.0/24"]

container_image = "nginx:latest"
container_port  = 80
task_cpu        = 256
task_memory     = 512
desired_count   = 1

db_name              = "appdb"
db_username          = "appuser"
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20

backup_retention_period = 1
deletion_protection     = false
skip_final_snapshot     = true
