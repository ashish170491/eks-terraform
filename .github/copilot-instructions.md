# Copilot Instructions for EKS Terraform Project

## Project Overview
This repository creates AWS EKS (Elastic Kubernetes Service) clusters using Terraform. The project follows Infrastructure as Code (IaC) principles to provision and manage Kubernetes infrastructure on AWS.

## Architecture Patterns

### Terraform Module Structure
- Use modular approach with separate modules for different AWS resources
- Typical structure: `modules/eks/`, `modules/vpc/`, `modules/security-groups/`
- Main configuration in root directory with environment-specific variable files
- Examples: `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`

### EKS Best Practices
- Always create dedicated VPC with public/private subnets across multiple AZs
- Use managed node groups instead of self-managed nodes when possible
- Implement proper RBAC and security groups for cluster access
- Enable logging and monitoring (CloudWatch, EKS control plane logs)

## Key Development Workflows

### Terraform Commands
```bash
# Initialize and validate
terraform init
terraform validate
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars"

# Destroy resources (be careful!)
terraform destroy -var-file="environments/dev.tfvars"
```

### AWS Configuration
- Ensure AWS CLI is configured with appropriate credentials
- Use AWS profiles for different environments: `aws configure --profile dev`
- Set AWS_PROFILE environment variable or use terraform provider configuration

## Project-Specific Conventions

### Variable Naming
- Use descriptive names: `cluster_name`, `node_group_instance_types`, `vpc_cidr_block`
- Environment prefixes: `dev_cluster_name`, `prod_cluster_name`
- Consistent tagging strategy with `Environment`, `Project`, `Owner` tags

### File Organization
- Environment-specific configurations in `environments/` or `terraform.tfvars` files
- Shared modules in `modules/` directory
- Use consistent naming for similar resources across environments

### Security Considerations
- Never commit `.tfstate` files or `terraform.tfvars` with sensitive data
- Use AWS Secrets Manager or Parameter Store for sensitive values
- Implement least privilege IAM policies
- Enable encryption for EBS volumes and EKS secrets

## Integration Points

### AWS Services
- **VPC**: Custom VPC with NAT gateways for private subnets
- **IAM**: Cluster service role, node group instance role, and OIDC identity provider
- **EC2**: Worker nodes, security groups, and key pairs
- **ELB**: Application Load Balancer for ingress
- **Route53**: DNS management for cluster endpoints

### Kubernetes Integration
- Configure `kubectl` after cluster creation using AWS CLI
- Install AWS Load Balancer Controller for ingress management
- Set up cluster autoscaler for dynamic node scaling
- Configure monitoring with Prometheus/Grafana or CloudWatch Container Insights

## Common Debugging Steps

1. **State Issues**: Check terraform state with `terraform state list`
2. **AWS Permissions**: Verify IAM policies and AWS credentials
3. **Network Connectivity**: Ensure VPC, subnets, and security groups are properly configured
4. **Cluster Access**: Use `aws eks update-kubeconfig --name <cluster-name>` to update kubectl config

## Output Management
- Always output important values like cluster endpoint, security group IDs
- Use outputs for cross-stack references and kubectl configuration
- Example outputs: `cluster_endpoint`, `cluster_security_group_id`, `node_group_role_arn`

## Testing Approach
- Use `terraform plan` to preview changes before applying
- Test in dev environment before promoting to production
- Validate cluster functionality with basic kubectl commands after deployment
- Consider using tools like Terratest for automated infrastructure testing