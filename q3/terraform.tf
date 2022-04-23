resource "aws_vpc" "my_vpc" {
  cidr_block = "172.16.0.0/16"
  tags = {
    Name = "tf-example"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "172.16.10.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name = "tf-example"
  }
}

resource "aws_network_interface" "foo" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["172.16.10.100"]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "foo" {
  ami           = "ami-005e54dee72cc1d00" # us-west-2
  instance_type = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.foo.id
    device_index         = 0
  }

  credit_specification {
    cpu_credits = "unlimited"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["<AWS ACCOUNT NUMBER>"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "importIO"
  }
}

module "ec2" {
  source = "../../modules/ec2"

  resource_tag_name = var.resource_tag_name
  namespace         = var.namespace
  region            = var.region

  ami           = "ami-07ebfd5b3428b6f4d" # Ubuntu Server 18.04 LTS
  key_name      = "${local.resource_name_prefix}-ec2-key"
  instance_type = var.instance_type
  subnet_id     = module.subnet_ec2.ids[0]

  vpc_security_group_ids = [aws_security_group.ec2.id]

  vpc_id = module.vpc.id
}

resource "aws_security_group" "ec2" {
  name = "${local.resource_name_prefix}-ec2-sg"

  description = "EC2 security group (terraform-managed)"
  vpc_id      = module.vpc.id

  ingress {
    from_port   = var.rds_port
    to_port     = var.rds_port
    protocol    = "tcp"
    description = "MySQL"
    cidr_blocks = local.rds_cidr_blocks
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "Telnet"
    cidr_blocks = ["107.22.40.20/XX"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["18.215.226.36/XX"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
