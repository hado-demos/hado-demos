provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# Public Subnets
resource "aws_subnet" "public" {
  count = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index * 128)
  map_public_ip_on_launch = true
  availability_zone = element(var.availability_zones, count.index)
}

# Private Subnets in AZ 1a
resource "aws_subnet" "private_1a" {
  count = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = var.availability_zones[0]
}

# Private Subnets in AZ 1b
resource "aws_subnet" "private_1b" {
  count = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 129)
  availability_zone = var.availability_zones[1]
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    #cidr_blocks = [ local.vpc_cidr ]
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #cidr_blocks = [ local.vpc_cidr ]
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Data source to get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "instance" {
  ami               = data.aws_ami.amazon_linux_2.id # Amazon Linux 2 AMI
  instance_type     = "t2.micro"
  subnet_id         = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  tags = {
    Name = "${var.vpc_cidr}-instance"
  }
}
