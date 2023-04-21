locals {
  Owner = "DFWTeam"
}

data "aws_vpc" "selected" {
  # id = var.vpc_id
  # name = var.vpc_name
  filter {
    name = "Name" #"tag:Name"
    values = ["default vpc"]
  }
}

# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create a default subnet in the first az if one does not exit
resource "aws_default_subnet" "subnet_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]
}

# create a default subnet in the second az if one does not exit
resource "aws_default_subnet" "subnet_az2" {
  availability_zone = data.aws_availability_zones.available_zones.names[1]
}

# Using guide https://awstip.com/managing-secrets-on-terraform-71ed245a455f
data "aws_secretsmanager_secret_version" "creds" {
  # Here goes the name you gave to your secret
  secret_id = "dh_credentials"
}

# Decode from json
locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

# data "aws_security_group" "aurora_sg" {
#   filter {
#     name   = "tag:Owner"
#     values = [local.Owner]
#   }
# }

resource "aws_security_group" "aurora_sg" {
  name = "rds_sg_created"
  description = "enable mysql/aurora access on port 3306"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    security_groups  = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = -1
    security_groups  = ["0.0.0.0/0"]
  }

  tags   = {
    Owner = local.Owner
    Name = "database security group"
  }
}

# create the subnet group for the rds instance
resource "aws_db_subnet_group" "database_subnet_group" {
  name         = "db-subnets"
  subnet_ids   = [aws_default_subnet.subnet_az1.id, aws_default_subnet.subnet_az2.id]
  description  = "Subnets for DB instance"

  tags   = {
    Owner = local.Owner
  }
}

resource "aws_rds_cluster" "hopper_contact" {
  cluster_identifier      = "hopper-contact-${var.environment}"
  engine                  = "aurora-mysql"
  engine_mode             = "provisioned"
  engine_version          = "8.0.mysql_aurora.3.03.0"
  db_subnet_group_name    = aws_db_subnet_group.database_subnet_group.name
  availability_zones      = [data.aws_availability_zones.available_zones.names[0]]
  vpc_security_group_ids  = [data.aws_security_group.aurora_sg.id]

  database_name   = "hopper_contact"
  master_username = local.db_creds.DHContactUser
  master_password = local.db_creds.DHContactPass

  backup_retention_period       = 5
  preferred_backup_window       = "07:00-09:00"
  skip_final_snapshot           = true
  allow_major_version_upgrade   = false
  
  copy_tags_to_snapshot         = false
  deletion_protection           = false

  # final_snapshot_identifier = "skill-control-cluster-backup-${random_id.id.hex}"
  # iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration {
    max_capacity = 2
    min_capacity = 0.5
  }
  tags = {
    Owner = local.Owner
  }
}

resource "aws_rds_cluster_instance" "hopper_contact" {
  identifier = "hopper-contact"
  cluster_identifier = aws_rds_cluster.hopper_contact.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.hopper_contact.engine
  engine_version     = aws_rds_cluster.hopper_contact.engine_version

  publicly_accessible = true
  auto_minor_version_upgrade = false
  tags = {
    Owner = local.Owner
  }
}

# # create the rds instance
# resource "aws_db_instance" "db_instance" {
#   engine                  = "mysql"
#   engine_version          = "8.0.31"
#   multi_az                = false
#   identifier              = "dev-db-instance"
#   username                = "admin"
#   password                = "Control*1234"
#   instance_class          = "db.t2.micro"
#   allocated_storage       = 20
#   db_subnet_group_name    = aws_db_subnet_group.database_subnet_group.name
#   vpc_security_group_ids  = [aws_security_group.database_security_group.id]
#   availability_zone       = data.aws_availability_zones.available_zones.names[0]
#   db_name                 = "applicationdb"
#   skip_final_snapshot     = false
# }
