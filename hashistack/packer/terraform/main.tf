provider "aws" {
  profile = "nuuday_digital_dev"
  region = "eu-north-1"
}

resource "aws_vpc" "packer" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Team = "odin-platform"
    Name = "packer vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.packer.id}"

  tags = {
    Name = "packer igw"
    Team = "odin-platform"
  }
}

resource "aws_route_table" "out" {
  vpc_id = "${aws_vpc.packer.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  
  tags = {
    Name = "packer route table"
    Team = "odin-platform"
  }
}

resource "aws_subnet" "packer" {
  vpc_id = "${aws_vpc.packer.id}"
  cidr_block = "${aws_vpc.packer.cidr_block}"

  map_public_ip_on_launch = true

  tags = {
    Team = "odin-platform"
    Name = "packer subnet"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.packer.id}"
  route_table_id = "${aws_route_table.out.id}"
}

