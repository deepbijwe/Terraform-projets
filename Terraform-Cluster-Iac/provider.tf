terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Uncomment below to enable S3 remote backend (recommended)
  /*
   backend "s3" {
     bucket  = "your-terraform-state-bucket"
     key     = "eks-dev/terraform.tfstate"
     region  = "ap-south-1"
     encrypt = true
   }
}
*/
provider "aws" {
  region = var.region
}
