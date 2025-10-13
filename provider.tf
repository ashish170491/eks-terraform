# AWS Provider Configuration
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  # Alternative: Use AWS profile instead of access keys (recommended)
  # profile = var.aws_profile

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}