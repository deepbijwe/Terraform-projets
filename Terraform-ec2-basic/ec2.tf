provider "aws" {
region = "ap-south-1"

}

resource "aws_instance" "my-ec2-instance"  { 
    ami = "ami-07a00cf47dbbc844c"
    instance_type = "t3.micro"
    tags = {
        Name = "MyEC2Instance"
    }
}

resource "aws_instance" "my-ec2-instance1"  { 
    ami = "ami-07a00cf47dbbc844c"
    instance_type = "t3.micro"
    tags = {
        Name = "MyEC2Instance1"
    }
}


output "instance_id" {
    value = aws_instance.my-ec2-instance.id
}
output "instance_id1" {
    value = aws_instance.my-ec2-instance1.id
}




---

#creating multiple instances using count

provider "aws" {
  region = "ap-south-1"

}

resource "aws_instance" "my-ec2-instance" {
  ami           = "ami-07a00cf47dbbc844c"
  count         = var.instance_count
  instance_type = "t3.micro"
  tags = {
    Name = "MyEC2Instance-${count.index + 1}"
  }
}

output "instance_ids" {
  value = aws_instance.my-ec2-instance[*].id
}

variable "instance_count" {
  default = 2
}

var