variable "environment" {
  type        = string
  description = "This is the enviroment on which resource is to be created."
  default     = "do"
}
variable "vpc_name" {
  type        = string
  description = "VPC name used"
  default = "dev-vpc"
}
