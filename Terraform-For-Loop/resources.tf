resource "aws_s3_bucket" "aws_bucket" {
    for_each = toset(var.bucket_s3)

    bucket = "s3(each.key)"

}