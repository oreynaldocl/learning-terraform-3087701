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
variable "vpc_id" {
  type        = string
  description = "VPC id used"
  default = "vpc-076d77269ad119f03"
}
