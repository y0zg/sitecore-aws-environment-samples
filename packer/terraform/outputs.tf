output "vpc_id" {
  value = "${aws_vpc.packer.id}"
}

output "subnet_id" {
  value = "${aws_subnet.packer.id}"
}

