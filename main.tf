# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "default vpc"
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

# create security group for the web server
resource "aws_security_group" "webserver_security_group" {
  name        = "webserver security group"
  description = "enable http access on port 80"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description      = "http access"
    from_port        = 80
    to_port          = 80
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
    Name = "webserver security group"
  }
}

# create security group for the database
resource "aws_security_group" "database_security_group" {
  name        = "database security group"
  description = "enable mysql/aurora access on port 3306"
  vpc_id      = aws_default_vpc.default_vpc.id

  ingress {
    description      = "mysql/aurora access"
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
    Name = "database security group"
  }
}


# create the subnet group for the rds instance
resource "aws_db_subnet_group" "database_subnet_group" {
  name         = "db-subnets"
  subnet_ids   = [aws_default_subnet.subnet_az1.id, aws_default_subnet.subnet_az2.id]
  description  = "Subnets for DB instance"

  tags   = {
    Name = "DB-subnets"
  }
}

resource "aws_rds_cluster" "hopper_contact" {
  cluster_identifier      = "hopper-contact-${var.environment}"
  engine                  = "aurora-mysql"
  engine_mode             = "provisioned"
  engine_version          = "8.0.mysql_aurora.3.03.0"
  db_subnet_group_name    = aws_db_subnet_group.database_subnet_group.name
  availability_zone       = data.aws_availability_zones.available_zones.names[0]

  database_name   = "hopper_contact"
  master_username = "postgres"
  master_password = "Control*123"

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
    Owner = "Team"
  }
}

resource "aws_rds_cluster_instance" "hopper_contact" {
  cluster_identifier = aws_rds_cluster.hopper_contact.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.hopper_contact.engine
  engine_version     = aws_rds_cluster.hopper_contact.engine_version
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
