variable "aws_region" {
  default = "ap-south-1"
}

variable "project_name" {
  default = "demo-app"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "azs" {
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "container_image" {
  default = "nginx:latest"
}

variable "container_port" {
  default = 80
}

variable "db_engine" {
  default = "postgres"
}

variable "db_engine_version" {
  default = "15.4"
}

variable "db_instance_class" {
  default = "db.t3.micro"
}

variable "db_name" {
  default = "appdb"
}

variable "db_username" {
  default = "dbadmin"
}

variable "db_password" {
  description = "DB password - pass via TF_VAR_db_password or terraform.tfvars, don't commit it"
  sensitive   = true
}

variable "db_port" {
  default = 5432
}
