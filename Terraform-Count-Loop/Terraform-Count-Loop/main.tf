resource "aws_instance" "loop" {
      ami   = "ami-07a00cf47dbbc844c"
     count = 3
  instance_type = "t3.micro"

  tags = {
    Name = "webserver-${var.name}"
  }
}