terraform {
  backend "s3" {
    bucket       = "my-backend-s3bucket-deep"
    key          = "workspaces/terraform.tfstate" # path to the state file in the S3 bucket
    region       = "ap-south-1"
    use_lockfile = true   # for state locking
    encrypt      = true   # to encrypt the state file at rest
  }
}
#--------------------------------------------------------------


provider "aws" {
region = "ap-south-1"

}

resource "aws_instance" "my-ec2-instance"  {
    ami = "ami-07a00cf47dbbc844c"
    instance_type = "t3.micro"
    tags = {
        Name = "MyEC2Ins"
    }
}

resource "aws_instance" "my-ec2-instance1"  {
    ami = "ami-07a00cf47dbbc844c"
    instance_type = "t3.micro"
    tags = {
        Name = "MyEC2Ins2"
    }
}



output "instance_id" {
    value = aws_instance.my-ec2-instance.id
}
output "instance_id1" {
    value = aws_instance.my-ec2-instance1.id
}