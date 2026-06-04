provider "aws" {
  region = "us-west-2"
}

module "dev_vpc" {
  vpc_name = "dev-vpc"
  source = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
  public_cidr_block = "10.0.0.0/24"
  private_cidr_block = "10.0.1.0/24"

}


module "test_vpc" {
  vpc_name = "test-vpc"
  source = "./modules/vpc"
  cidr_block = "172.16.0.0/16"
  public_cidr_block = "172.16.0.0/24"
  private_cidr_block = "172.16.1.0/24"

}

module "prod_vpc" {
  vpc_name = "prod-vpc"
  source = "./modules/vpc"
  cidr_block = "192.168.0.0/16"
  public_cidr_block = "192.168.0.0/24"
  private_cidr_block = "192.168.1.0/24"

}

