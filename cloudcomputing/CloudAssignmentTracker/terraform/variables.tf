# Defines the settings used to  configure our AWS infrastructure, such as the region and instance type# AWS region where our infrastructure will be created
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "cloud-assignment"
}

