# Defines the settings used to  configure our AWS infrastructure, such as the region and instance type# AWS region where our infrastructure will be created
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Prefix used in resource names and tags (for example "cloud-assignment-vpc"),
# so our resources are easy to find in the AWS console.
variable "project_name" {
  type    = string
  default = "cloud-assignment"
}

variable "db_name" {
  type    = string
  default = "cloudassignmenttracker"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_password" {
  type      = string
  sensitive = true
}

