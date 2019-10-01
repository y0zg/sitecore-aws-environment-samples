provider "aws" {
    version = "~> 2.0"
    region  = "eu-north-1"
    profile = "nuuday_digital_dev"
}

data "aws_availability_zones" "available" {
    state = "available"
}

data "aws_ami" "windows" {
    most_recent      = true
    owners           = ["amazon"]

    filter {
        name = "name"
        values = ["Windows_Server-2019-English-Core-ContainersLatest-*"]
    }
}

resource "aws_vpc" "packer" {
    cidr_block = "10.1.0.0/16"

    tags = {
        Name = "packer"
    }
}

resource "aws_subnet" "packer" {
    vpc_id     = "${aws_vpc.packer.id}"
    cidr_block = "10.1.0.0/24"

    tags = {
        Name = "packer"
    }
}

resource "aws_vpc" "default" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "sitecore-9-test"
    }
}

resource "aws_subnet" "cd_az_1" {
    vpc_id     = "${aws_vpc.default.id}"
    cidr_block = "10.0.1.0/24"

    availability_zone = "${data.aws_availability_zones.available.names[0]}"

    tags = {
        Name = "cd-az-1"
    }
}

resource "aws_subnet" "cd_az_2" {
    vpc_id     = "${aws_vpc.default.id}"
    cidr_block = "10.0.2.0/24"

    availability_zone = "${data.aws_availability_zones.available.names[1]}"

    tags = {
        Name = "cd-az-1"
    }
}

resource "aws_placement_group" "spread" {
    name = "spread"
    strategy = "spread"
}


resource "aws_launch_configuration" "cd_config" {
    name_prefix = "cd-"
    image_id = "${data.aws_ami.windows.id}"
    instance_type = "t3.small"

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "cd" {
    name = "cd-auto-scaling-group"
    launch_configuration = "${aws_launch_configuration.cd_config.name}"
    placement_group = "${aws_placement_group.spread.id}"

    vpc_zone_identifier = [
        "${aws_subnet.cd_az_1.id}",
        "${aws_subnet.cd_az_2.id}",
    ]

    min_size = 1
    max_size = 2

    lifecycle {
        create_before_destroy = true
    }
}

