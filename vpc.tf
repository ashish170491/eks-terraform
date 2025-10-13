module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.4.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = length(var.availability_zones) > 0 ? var.availability_zones : ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  database_subnets = var.database_subnets
  #create_database_subnet_group = true
  
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  public_subnet_tags = {
    Type = "public-subnet"
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    Type = "private-subnet"
    "kubernetes.io/role/internal-elb" = "1"
  }
  database_subnet_tags = {
    Type = "database-subnet"
  }

  tags = merge(
    {
      Terraform   = "true"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
    },
    var.additional_tags
  )
  
  vpc_tags = merge(
    {
      Name        = var.vpc_name
      Terraform   = "true"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
    },
    var.additional_tags
  )
}