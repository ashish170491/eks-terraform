module "bastion_host_sg" {
    source  = "terraform-aws-modules/security-group/aws"
    version = "4.12.0"
    name        = "${var.project}-${var.environment}-bastion-sg"
    description = "Security group for bastion host"
    vpc_id      = module.vpc.vpc_id
}