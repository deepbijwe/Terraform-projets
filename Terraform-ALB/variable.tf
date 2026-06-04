variable "region" {
  default = "ap-south-1"   # Mumbai
}

variable "ami_id" {
  description = " Ubuntu 20.04 AMI for Mumbai"
  default     = "ami-07a00cf47dbbc844c"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  description = "Your existing EC2 key pair name"
  default     = "my-mumbai"
}
