# AWS VPC CIDR Range and Subnet Planning Guide

## Table of Contents
- [CIDR Basics](#cidr-basics)
- [VPC CIDR Selection](#vpc-cidr-selection)
- [Subnet Planning Strategy](#subnet-planning-strategy)
- [EKS-Specific Considerations](#eks-specific-considerations)
- [Common CIDR Patterns](#common-cidr-patterns)
- [Examples by Use Case](#examples-by-use-case)
- [IP Address Calculator](#ip-address-calculator)
- [Best Practices](#best-practices)

## CIDR Basics

### What is CIDR?
**CIDR (Classless Inter-Domain Routing)** notation describes IP address ranges using:
- **Base IP address**: The network address (e.g., 10.0.0.0)
- **Prefix length**: Number of bits for the network portion (e.g., /16)

### CIDR Block Sizes
| CIDR | Subnet Mask | Total IPs | Usable IPs | Use Case |
|------|-------------|-----------|------------|----------|
| /16  | 255.255.0.0 | 65,536    | 65,534     | Large VPC |
| /20  | 255.255.240.0 | 4,096   | 4,094      | Medium VPC |
| /24  | 255.255.255.0 | 256     | 254        | Small subnet |
| /25  | 255.255.255.128 | 128   | 126        | Micro subnet |
| /26  | 255.255.255.192 | 64    | 62         | Minimal subnet |
| /28  | 255.255.255.240 | 16    | 14         | Very small subnet |

## VPC CIDR Selection

### RFC 1918 Private Address Ranges
Use these private IP ranges for your VPC:

| Range | CIDR | Total Addresses | Best For |
|-------|------|-----------------|----------|
| **Class A** | 10.0.0.0/8 | 16,777,216 | Large organizations, multiple VPCs |
| **Class B** | 172.16.0.0/12 | 1,048,576 | Medium organizations |
| **Class C** | 192.168.0.0/16 | 65,536 | Small organizations, home networks |

### VPC Size Recommendations

#### Small VPC (/20 - 4,096 IPs)
```
VPC CIDR: 10.0.0.0/20
- Good for: Small applications, development environments
- Max subnets: 16 x /24 subnets
```

#### Medium VPC (/16 - 65,536 IPs)
```
VPC CIDR: 10.0.0.0/16
- Good for: Production workloads, microservices
- Max subnets: 256 x /24 subnets
```

#### Large VPC (/12 - 1,048,576 IPs)
```
VPC CIDR: 10.0.0.0/12
- Good for: Enterprise, multi-tenant environments
- Max subnets: 4,096 x /24 subnets
```

## Subnet Planning Strategy

### Three-Tier Architecture Pattern

#### 1. Public Subnets (Internet-facing resources)
- **Purpose**: Load balancers, NAT gateways, bastion hosts
- **Size**: /24 (254 IPs) - usually sufficient
- **Pattern**: 10.0.1xx.0/24

#### 2. Private Subnets (Application workloads)
- **Purpose**: EKS worker nodes, application servers
- **Size**: /20-/22 (1,024-4,096 IPs) for EKS
- **Pattern**: 10.0.0xx.0/20

#### 3. Database Subnets (Data persistence)
- **Purpose**: RDS, ElastiCache, managed databases
- **Size**: /24-/26 (64-254 IPs)
- **Pattern**: 10.0.2xx.0/24

### Multi-AZ Distribution
For high availability, distribute subnets across **3 Availability Zones**:

```
Region: us-west-2
├── AZ-a: us-west-2a
├── AZ-b: us-west-2b
└── AZ-c: us-west-2c
```

## EKS-Specific Considerations

### IP Address Requirements

#### Per Worker Node
- **1 Primary IP**: Node's main IP address
- **N Secondary IPs**: For pods (depends on instance type)
- **Example**: t3.medium supports ~17 pods = 18 IPs per node

#### Instance Type Pod Limits
| Instance Type | Max Pods | IPs per Node | Recommended Subnet Size |
|---------------|----------|--------------|------------------------|
| t3.micro      | 4        | 5           | /26 (62 IPs) |
| t3.small      | 11       | 12          | /25 (126 IPs) |
| t3.medium     | 17       | 18          | /24 (254 IPs) |
| t3.large      | 35       | 36          | /23 (510 IPs) |
| m5.large      | 29       | 30          | /24 (254 IPs) |
| m5.xlarge     | 58       | 59          | /22 (1,022 IPs) |

### EKS Subnet Tagging Requirements
```terraform
# Public subnets (for load balancers)
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
  "kubernetes.io/cluster/${cluster_name}" = "shared"
}

# Private subnets (for worker nodes)
private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"
  "kubernetes.io/cluster/${cluster_name}" = "shared"
}
```

## Lambda Function Subnet Considerations

### Lambda VPC Configuration

When Lambda functions need VPC access (databases, private resources), they require:
- **ENI (Elastic Network Interface)** creation in your subnets
- **Dedicated IP addresses** for each concurrent execution
- **NAT Gateway access** for internet connectivity (if needed)

### Lambda IP Requirements

#### Concurrent Execution Planning
```yaml
# Formula: Required IPs = Max Concurrent Executions + Buffer
Concurrent Executions: 100
Buffer (20%): 20
Total IPs needed: 120

Recommended subnet: /25 (126 usable IPs)
```

#### Lambda Subnet Patterns

**Pattern 1: Dedicated Lambda Subnets**
```yaml
# Separate subnets for Lambda functions
Lambda Private Subnets:
- 10.0.10.0/25  (us-west-2a) - 126 IPs
- 10.0.10.128/25 (us-west-2b) - 126 IPs
- 10.0.11.0/25  (us-west-2c) - 126 IPs

Benefits:
+ Isolated network traffic
+ Easy monitoring and troubleshooting
+ Dedicated security groups
```

**Pattern 2: Shared Private Subnets**
```yaml
# Lambda shares subnets with EKS/EC2
Private Subnets (Mixed workloads):
- 10.0.16.0/20  (us-west-2a) - 4,094 IPs
- 10.0.32.0/20  (us-west-2b) - 4,094 IPs
- 10.0.48.0/20  (us-west-2c) - 4,094 IPs

Benefits:
+ Fewer subnets to manage
+ Cost-effective NAT Gateway sharing
+ Simplified routing
```

### Lambda Scaling Considerations

#### Cold Start Impact on IPs
```yaml
# High-traffic Lambda function
Expected RPS: 1,000
Execution duration: 5 seconds
Concurrent executions: 5,000

Required IPs: 5,000 + 20% buffer = 6,000 IPs
Recommended: /19 subnet (8,190 IPs)
```

#### Reserved Concurrency Planning
| Lambda Function Type | Concurrent Limit | Subnet Size | IP Allocation |
|---------------------|------------------|-------------|---------------|
| **Low Traffic** | 10-50 | /26 (62 IPs) | 50-75 IPs |
| **Medium Traffic** | 100-500 | /23 (510 IPs) | 500-600 IPs |
| **High Traffic** | 1,000+ | /20 (4,094 IPs) | 1,200+ IPs |
| **Burst Traffic** | 3,000+ | /19 (8,190 IPs) | 3,600+ IPs |

### Lambda Network Architecture Examples

#### Example 1: Microservices with Lambda
```yaml
VPC: 10.0.0.0/16

# API Gateway + Lambda functions
Lambda Subnets:
- 10.0.20.0/22  (us-west-2a) - 1,022 IPs
- 10.0.24.0/22  (us-west-2b) - 1,022 IPs
- 10.0.28.0/22  (us-west-2c) - 1,022 IPs

# Database access
Database Subnets:
- 10.0.200.0/24 (us-west-2a) - 254 IPs
- 10.0.201.0/24 (us-west-2b) - 254 IPs
- 10.0.202.0/24 (us-west-2c) - 254 IPs

# NAT Gateway for outbound
Public Subnets:
- 10.0.100.0/24 (us-west-2a) - 254 IPs
- 10.0.101.0/24 (us-west-2b) - 254 IPs
- 10.0.102.0/24 (us-west-2c) - 254 IPs
```

#### Example 2: Hybrid EKS + Lambda Architecture
```yaml
VPC: 10.0.0.0/16

# EKS Worker Nodes
EKS Private Subnets:
- 10.0.0.0/20   (us-west-2a) - 4,094 IPs
- 10.0.16.0/20  (us-west-2b) - 4,094 IPs
- 10.0.32.0/20  (us-west-2c) - 4,094 IPs

# Lambda Functions (Event processing)
Lambda Private Subnets:
- 10.0.48.0/22  (us-west-2a) - 1,022 IPs
- 10.0.52.0/22  (us-west-2b) - 1,022 IPs
- 10.0.56.0/22  (us-west-2c) - 1,022 IPs

# Shared Database Layer
Database Subnets:
- 10.0.60.0/24  (us-west-2a) - 254 IPs
- 10.0.61.0/24  (us-west-2b) - 254 IPs
- 10.0.62.0/24  (us-west-2c) - 254 IPs
```

### Lambda-Specific Best Practices

#### ✅ Lambda Networking Do's

1. **Plan for Burst Traffic**
   ```yaml
   # Account for traffic spikes
   Normal load: 100 concurrent
   Peak load: 500 concurrent
   Plan for: 600 concurrent (20% buffer)
   Subnet size: /22 (1,022 IPs)
   ```

2. **Use Multiple AZs**
   ```yaml
   # Distribute Lambda subnets across AZs
   Lambda functions automatically failover
   Place subnets in 2+ availability zones
   ```

3. **Consider NAT Gateway Costs**
   ```yaml
   # Optimize for cost vs performance
   Single NAT: Lower cost, single point of failure
   Multi-AZ NAT: Higher cost, better availability
   ```

4. **Monitor ENI Usage**
   ```bash
   # CloudWatch metrics to track:
   - ENI Creation rate
   - ENI deletion rate  
   - Available IP addresses
   - Lambda concurrent executions
   ```

#### ❌ Lambda Networking Don'ts

1. **Don't Underestimate IP Requirements**
   ```yaml
   # WRONG - Too small for burst traffic
   Expected: 100 concurrent
   Subnet: /26 (62 IPs) ❌
   
   # CORRECT - Account for scaling
   Expected: 100 concurrent  
   Subnet: /24 (254 IPs) ✅
   ```

2. **Don't Put Lambda in Public Subnets**
   ```yaml
   # WRONG - Security risk
   Lambda → Public Subnet ❌
   
   # CORRECT - Private with NAT for outbound
   Lambda → Private Subnet → NAT Gateway ✅
   ```

3. **Don't Forget Cold Start Impacts**
   ```yaml
   # Cold starts can cause IP exhaustion
   Plan for 2-3x normal concurrent executions
   Monitor CloudWatch Lambda metrics
   ```

### Lambda Subnet Sizing Calculator

```bash
# Formula for Lambda subnet sizing
Required_IPs = (Max_Concurrent_Executions × 1.2) + Reserved_AWS_IPs

Examples:
100 concurrent: (100 × 1.2) + 5 = 125 IPs → /25 subnet
500 concurrent: (500 × 1.2) + 5 = 605 IPs → /22 subnet  
1000 concurrent: (1000 × 1.2) + 5 = 1205 IPs → /21 subnet
```

### Terraform Lambda Subnet Example

```hcl
# Lambda-specific subnets
lambda_subnets = [
  "10.0.20.0/22",   # us-west-2a - 1,022 IPs
  "10.0.24.0/22",   # us-west-2b - 1,022 IPs  
  "10.0.28.0/22"    # us-west-2c - 1,022 IPs
]

# Lambda subnet tags
lambda_subnet_tags = {
  Type = "lambda-subnet"
  Purpose = "serverless-workloads"
  "aws:lambda:function-name" = "shared"
}
```

## Cross-Account VPC Peering Considerations

### Why Plan for VPC Peering?

Cross-account VPC peering enables:
- **Multi-account architecture** (Dev/Staging/Prod isolation)
- **Shared services** (Centralized logging, monitoring, DNS)
- **Partner integrations** (Third-party vendor access)
- **Disaster recovery** (Cross-region failover)

### CIDR Planning for Peering

#### Critical Rule: No Overlapping CIDRs
```yaml
# WRONG ❌ - Cannot peer overlapping ranges
Account-A (Dev):  10.0.0.0/16
Account-B (Prod): 10.0.0.0/16  # Same range!

# CORRECT ✅ - Non-overlapping ranges
Account-A (Dev):  10.0.0.0/16   # 10.0.0.0 - 10.0.255.255
Account-B (Prod): 10.1.0.0/16   # 10.1.0.0 - 10.1.255.255
Account-C (Staging): 10.2.0.0/16 # 10.2.0.0 - 10.2.255.255
```

### Multi-Account CIDR Allocation Strategy

#### Strategy 1: Sequential Allocation
```yaml
# Reserve /16 blocks per account
Account Management: 10.0.0.0/16   # Shared services
Account Dev:        10.1.0.0/16   # Development
Account Staging:    10.2.0.0/16   # Pre-production
Account Prod:       10.3.0.0/16   # Production
Account Security:   10.4.0.0/16   # Security tools
Account Logging:    10.5.0.0/16   # Centralized logs
Account Backup:     10.6.0.0/16   # Backup/DR

# Reserve future expansion
Future Accounts:    10.7.0.0/16 - 10.255.0.0/16
```

#### Strategy 2: Environment-Based Allocation
```yaml
# Group by environment with room for growth
Development Block:  10.0.0.0/12   # 10.0.0.0 - 10.15.255.255
├── Dev-Account-1:  10.0.0.0/16
├── Dev-Account-2:  10.1.0.0/16
└── Dev-Future:     10.2.0.0/14   # 10.2.0.0 - 10.5.255.255

Staging Block:      10.16.0.0/12  # 10.16.0.0 - 10.31.255.255
├── Staging-Main:   10.16.0.0/16
└── Staging-Future: 10.17.0.0/15  # 10.17.0.0 - 10.18.255.255

Production Block:   10.32.0.0/12  # 10.32.0.0 - 10.47.255.255
├── Prod-Account-1: 10.32.0.0/16
├── Prod-Account-2: 10.33.0.0/16
└── Prod-Future:    10.34.0.0/14  # 10.34.0.0 - 10.37.255.255

Shared Services:    10.48.0.0/12  # 10.48.0.0 - 10.63.255.255
├── Shared-Network: 10.48.0.0/16  # DNS, NAT, Transit Gateway
├── Shared-Monitor: 10.49.0.0/16  # CloudWatch, logging
└── Shared-Security: 10.50.0.0/16 # Security tools, backup
```

#### Strategy 3: Regional Distribution
```yaml
# Distribute by region for global architecture
us-east-1 (Virginia):
├── Account-Dev:    10.0.0.0/16
├── Account-Prod:   10.1.0.0/16
└── Account-Shared: 10.2.0.0/16

us-west-2 (Oregon):
├── Account-Dev:    10.10.0.0/16
├── Account-Prod:   10.11.0.0/16
└── Account-Shared: 10.12.0.0/16

eu-west-1 (Ireland):
├── Account-Dev:    10.20.0.0/16
├── Account-Prod:   10.21.0.0/16
└── Account-Shared: 10.22.0.0/16

ap-southeast-1 (Singapore):
├── Account-Dev:    10.30.0.0/16
├── Account-Prod:   10.31.0.0/16
└── Account-Shared: 10.32.0.0/16
```

### VPC Peering Architecture Patterns

#### Pattern 1: Hub-and-Spoke (Centralized Shared Services)
```yaml
# Central shared services account
Shared Services VPC: 10.0.0.0/16
├── DNS Resolution: 10.0.1.0/24
├── NAT Gateway:    10.0.2.0/24
├── Monitoring:     10.0.10.0/24
└── Security Tools: 10.0.20.0/24

# Spoke accounts peer to hub
Dev Account VPC:    10.1.0.0/16  ←→ Shared Services
Staging Account:    10.2.0.0/16  ←→ Shared Services  
Prod Account:       10.3.0.0/16  ←→ Shared Services

Benefits:
+ Centralized shared services
+ Simplified routing
+ Cost-effective NAT/Internet Gateway
```

#### Pattern 2: Mesh Peering (Full Connectivity)
```yaml
# All accounts can communicate directly
Dev VPC:     10.1.0.0/16  ←→ Staging VPC:   10.2.0.0/16
Dev VPC:     10.1.0.0/16  ←→ Prod VPC:      10.3.0.0/16
Staging VPC: 10.2.0.0/16  ←→ Prod VPC:      10.3.0.0/16

# Formula: N(N-1)/2 peering connections
3 VPCs = 3(3-1)/2 = 3 connections
5 VPCs = 5(5-1)/2 = 10 connections
10 VPCs = 10(10-1)/2 = 45 connections

Benefits:
+ Direct communication paths
+ Lower latency
Drawbacks:
- Management complexity grows exponentially
- Higher costs with many VPCs
```

#### Pattern 3: Transit Gateway (Scalable Hub)
```yaml
# Single Transit Gateway connects all VPCs
Transit Gateway: Central routing hub

Connected VPCs:
├── Shared Services: 10.0.0.0/16
├── Dev-Account-1:   10.1.0.0/16
├── Dev-Account-2:   10.2.0.0/16
├── Staging:         10.10.0.0/16
├── Prod-Account-1:  10.20.0.0/16
└── Prod-Account-2:  10.21.0.0/16

Benefits:
+ Scales to hundreds of VPCs
+ Centralized routing policies
+ Cross-region connectivity
+ Simpler than mesh peering
```

### Cross-Account VPC Peering Best Practices

#### ✅ Planning Do's

1. **Document CIDR Allocation**
   ```yaml
   # Maintain central CIDR registry
   CIDR Registry:
   ├── Account Name
   ├── Account ID  
   ├── VPC CIDR
   ├── Region
   ├── Environment
   ├── Peering Status
   └── Route Tables
   ```

2. **Reserve CIDR Blocks Early**
   ```yaml
   # Plan for 5-year growth
   Current accounts: 5
   Projected accounts: 20
   Reserve: /12 block (1M IPs) for future expansion
   ```

3. **Use Consistent Naming**
   ```yaml
   # Standard naming convention
   Format: {environment}-{workload}-{region}
   Examples:
   - prod-eks-usw2: 10.3.0.0/16
   - dev-lambda-usw2: 10.1.0.0/16
   - shared-dns-usw2: 10.0.0.0/16
   ```

4. **Plan Route Table Strategy**
   ```yaml
   # Route table planning per account
   Account Route Tables:
   ├── Public RT:    0.0.0.0/0 → IGW
   ├── Private RT:   0.0.0.0/0 → NAT-GW
   ├── Database RT:  10.0.0.0/8 → Peering
   └── Lambda RT:    10.0.0.0/8 → Peering
   ```

#### ❌ Cross-Account Don'ts

1. **Don't Use Overlapping CIDRs**
   ```yaml
   # WRONG - Will fail to peer
   Account-A: 10.0.0.0/16
   Account-B: 10.0.100.0/24  # Overlaps with Account-A!
   
   # CORRECT - Non-overlapping
   Account-A: 10.0.0.0/16
   Account-B: 10.1.0.0/16
   ```

2. **Don't Forget Route Propagation**
   ```yaml
   # Remember to update route tables in BOTH VPCs
   VPC-A Route Table: 10.1.0.0/16 → pcx-12345
   VPC-B Route Table: 10.0.0.0/16 → pcx-12345
   ```

3. **Don't Hardcode Peering IDs**
   ```yaml
   # Use Terraform data sources or variables
   # WRONG - Hardcoded
   route_table_id = "pcx-12345678"
   
   # CORRECT - Dynamic
   route_table_id = aws_vpc_peering_connection.main.id
   ```

### Terraform Cross-Account Peering Example

```hcl
# CIDR allocation for multi-account setup
variable "account_cidrs" {
  description = "CIDR blocks per account"
  type = map(string)
  default = {
    "shared"  = "10.0.0.0/16"   # Shared services
    "dev"     = "10.1.0.0/16"   # Development  
    "staging" = "10.2.0.0/16"   # Staging
    "prod"    = "10.3.0.0/16"   # Production
    "security"= "10.4.0.0/16"   # Security tools
  }
}

# VPC with peering-ready CIDR
resource "aws_vpc" "main" {
  cidr_block           = var.account_cidrs[var.environment]
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.environment}-vpc"
    Environment = var.environment
    PeeringReady = "true"
    CIDRBlock = var.account_cidrs[var.environment]
  }
}

# Route table for cross-account traffic
resource "aws_route_table" "cross_account" {
  vpc_id = aws_vpc.main.id
  
  # Add routes to other account VPCs
  dynamic "route" {
    for_each = var.peering_connections
    content {
      cidr_block                = route.value.cidr
      vpc_peering_connection_id = route.value.pcx_id
    }
  }
  
  tags = {
    Name = "${var.environment}-cross-account-rt"
    Type = "cross-account-routing"
  }
}
```

### CIDR Conflict Detection Tools

```bash
# PowerShell script to check for CIDR overlaps
function Test-CIDROverlap {
    param(
        [string[]]$CIDRBlocks
    )
    
    foreach ($cidr1 in $CIDRBlocks) {
        foreach ($cidr2 in $CIDRBlocks) {
            if ($cidr1 -ne $cidr2) {
                # Check for overlap logic here
                Write-Host "Checking $cidr1 vs $cidr2"
            }
        }
    }
}

# Example usage
$AccountCIDRs = @(
    "10.0.0.0/16",  # Shared
    "10.1.0.0/16",  # Dev
    "10.2.0.0/16",  # Staging
    "10.3.0.0/16"   # Prod
)

Test-CIDROverlap -CIDRBlocks $AccountCIDRs
```

### Future-Proofing Checklist

- [ ] **CIDR Registry**: Maintain centralized documentation
- [ ] **Growth Planning**: Reserve 3x current needs
- [ ] **Regional Strategy**: Plan for multi-region expansion
- [ ] **Peering Limits**: AWS supports 125 peering connections per VPC
- [ ] **Route Table Limits**: 50 routes per route table (consider summarization)
- [ ] **DNS Resolution**: Plan for cross-account DNS queries
- [ ] **Security Groups**: Plan for cross-VPC security group references
- [ ] **Cost Optimization**: Monitor data transfer costs between accounts

## Common CIDR Patterns

### Pattern 1: Small EKS Cluster
```yaml
VPC: 10.0.0.0/16 (65,536 IPs)

Public Subnets:
- 10.0.101.0/24 (us-west-2a) - 254 IPs
- 10.0.102.0/24 (us-west-2b) - 254 IPs
- 10.0.103.0/24 (us-west-2c) - 254 IPs

Private Subnets (EKS Nodes):
- 10.0.1.0/24   (us-west-2a) - 254 IPs
- 10.0.2.0/24   (us-west-2b) - 254 IPs
- 10.0.3.0/24   (us-west-2c) - 254 IPs

Database Subnets:
- 10.0.201.0/24 (us-west-2a) - 254 IPs
- 10.0.202.0/24 (us-west-2b) - 254 IPs
- 10.0.203.0/24 (us-west-2c) - 254 IPs
```

### Pattern 2: Medium EKS Cluster
```yaml
VPC: 10.0.0.0/16 (65,536 IPs)

Public Subnets:
- 10.0.0.0/24   (us-west-2a) - 254 IPs
- 10.0.1.0/24   (us-west-2b) - 254 IPs
- 10.0.2.0/24   (us-west-2c) - 254 IPs

Private Subnets (EKS Nodes):
- 10.0.16.0/20  (us-west-2a) - 4,094 IPs
- 10.0.32.0/20  (us-west-2b) - 4,094 IPs
- 10.0.48.0/20  (us-west-2c) - 4,094 IPs

Database Subnets:
- 10.0.8.0/24   (us-west-2a) - 254 IPs
- 10.0.9.0/24   (us-west-2b) - 254 IPs
- 10.0.10.0/24  (us-west-2c) - 254 IPs
```

### Pattern 3: Large EKS Cluster with Microservices
```yaml
VPC: 10.0.0.0/12 (1,048,576 IPs)

Public Subnets:
- 10.0.0.0/24   (us-west-2a) - 254 IPs
- 10.1.0.0/24   (us-west-2b) - 254 IPs
- 10.2.0.0/24   (us-west-2c) - 254 IPs

Private Subnets (EKS Nodes):
- 10.4.0.0/16   (us-west-2a) - 65,534 IPs
- 10.5.0.0/16   (us-west-2b) - 65,534 IPs
- 10.6.0.0/16   (us-west-2c) - 65,534 IPs

Database Subnets:
- 10.8.0.0/24   (us-west-2a) - 254 IPs
- 10.8.1.0/24   (us-west-2b) - 254 IPs
- 10.8.2.0/24   (us-west-2c) - 254 IPs

Management Subnets:
- 10.9.0.0/24   (us-west-2a) - 254 IPs
- 10.9.1.0/24   (us-west-2b) - 254 IPs
- 10.9.2.0/24   (us-west-2c) - 254 IPs
```

## Examples by Use Case

### Development Environment
```yaml
# Small, cost-optimized setup
VPC: 10.10.0.0/20 (4,096 IPs)
- Public:  10.10.0.0/26  (62 IPs)
- Private: 10.10.1.0/24  (254 IPs)
- Database: 10.10.2.0/26 (62 IPs)
```

### Production Microservices
```yaml
# High-scale, multi-service setup
VPC: 10.0.0.0/16 (65,536 IPs)
- Public:  10.0.{0-2}.0/24    (3 x 254 IPs)
- Private: 10.0.{16,32,48}.0/20 (3 x 4,094 IPs)
- Database: 10.0.{8-10}.0/24   (3 x 254 IPs)
```

### Event-Driven Serverless
```yaml
# Lambda-heavy workload with event processing
VPC: 10.0.0.0/16 (65,536 IPs)
- Public:  10.0.0.0/24      (254 IPs - NAT Gateway)
- Lambda:  10.0.{16,32,48}.0/20 (3 x 4,094 IPs)
- Database: 10.0.8.0/22     (1,022 IPs - RDS/DynamoDB)
- Cache:   10.0.12.0/24     (254 IPs - ElastiCache)
```

### API Gateway + Lambda Backend
```yaml
# Serverless API with high concurrency
VPC: 10.0.0.0/20 (4,096 IPs)
- Public:  10.0.0.0/26      (62 IPs - ALB only)
- Lambda:  10.0.1.0/22      (1,022 IPs - API functions)
- Database: 10.0.8.0/24     (254 IPs - RDS)
```

### Multi-Environment Hub
```yaml
# Shared VPC for multiple environments
VPC: 10.0.0.0/12 (1,048,576 IPs)

Development: 10.0.0.0/16
Staging:     10.1.0.0/16
Production:  10.2.0.0/16
Shared:      10.15.0.0/16
```

### Serverless + Container Hybrid
```yaml
# Lambda + EKS hybrid architecture
VPC: 10.0.0.0/16 (65,536 IPs)

# Container workloads (EKS)
EKS Private: 10.0.0.0/18    (16,382 IPs)
- 10.0.0.0/20   (us-west-2a) - 4,094 IPs
- 10.0.16.0/20  (us-west-2b) - 4,094 IPs
- 10.0.32.0/20  (us-west-2c) - 4,094 IPs

# Serverless workloads (Lambda)
Lambda Private: 10.0.64.0/18  (16,382 IPs)
- 10.0.64.0/20  (us-west-2a) - 4,094 IPs
- 10.0.80.0/20  (us-west-2b) - 4,094 IPs
- 10.0.96.0/20  (us-west-2c) - 4,094 IPs

# Shared infrastructure
Public: 10.0.128.0/20   (4,094 IPs)
Database: 10.0.144.0/20 (4,094 IPs)
```

## IP Address Calculator

### Quick CIDR Calculator

```bash
# Calculate available IPs
Total IPs = 2^(32 - prefix_length)
Usable IPs = Total IPs - 2 (network + broadcast)

Examples:
/16 = 2^(32-16) = 2^16 = 65,536 total (65,534 usable)
/20 = 2^(32-20) = 2^12 = 4,096 total (4,094 usable)
/24 = 2^(32-24) = 2^8 = 256 total (254 usable)
```

### AWS Reserved IPs (Per Subnet)
AWS reserves **5 IP addresses** in each subnet:
- `.0` - Network address
- `.1` - VPC router
- `.2` - DNS server
- `.3` - Future use
- `.255` - Network broadcast

Example for 10.0.1.0/24:
- Reserved: 10.0.1.0, 10.0.1.1, 10.0.1.2, 10.0.1.3, 10.0.1.255
- Usable: 10.0.1.4 through 10.0.1.254 (251 IPs)

## Best Practices

### ✅ Do's

1. **Plan for Growth**
   ```yaml
   # Start with larger subnets than current needs
   Current need: 50 IPs → Use /24 (254 IPs)
   Current need: 500 IPs → Use /20 (4,094 IPs)
   ```

2. **Use Consistent Patterns**
   ```yaml
   # Establish numbering conventions
   Public:    10.x.{0-99}.0/24
   Private:   10.x.{100-199}.0/24
   Database:  10.x.{200-249}.0/24
   ```

3. **Consider Multi-Region**
   ```yaml
   # Allocate different ranges per region
   us-west-2:  10.0.0.0/16
   us-east-1:  10.1.0.0/16
   eu-west-1:  10.2.0.0/16
   ```

4. **Document Your Allocation**
   ```yaml
   # Maintain CIDR inventory
   VPC: 10.0.0.0/16
   ├── Reserved: 10.0.0.0/20    (Future expansion)
   ├── Public:   10.0.16.0/20   (Load balancers)
   ├── Private:  10.0.32.0/18   (EKS nodes)
   └── Database: 10.0.96.0/20   (RDS, Cache)
   ```

### ❌ Don'ts

1. **Don't Use Overlapping CIDRs**
   ```yaml
   # WRONG - Overlapping ranges
   VPC-A: 10.0.0.0/16
   VPC-B: 10.0.1.0/16  # Overlaps with VPC-A
   
   # CORRECT - Non-overlapping ranges
   VPC-A: 10.0.0.0/16
   VPC-B: 10.1.0.0/16
   ```

2. **Don't Make Subnets Too Small**
   ```yaml
   # WRONG - Too restrictive for EKS
   EKS Private: 10.0.1.0/26  # Only 62 IPs
   
   # CORRECT - Room for growth
   EKS Private: 10.0.1.0/22  # 1,022 IPs
   ```

3. **Don't Forget Reserved IPs**
   ```yaml
   # Remember: Each subnet loses 5 IPs to AWS
   /28 subnet = 16 total - 5 reserved = 11 usable
   /26 subnet = 64 total - 5 reserved = 59 usable
   ```

### Terraform Variable Example

```hcl
# terraform.tfvars
vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "us-west-2a",
  "us-west-2b", 
  "us-west-2c"
]

# Small EKS cluster subnets
public_subnets = [
  "10.0.101.0/24",  # us-west-2a
  "10.0.102.0/24",  # us-west-2b
  "10.0.103.0/24"   # us-west-2c
]

private_subnets = [
  "10.0.1.0/24",    # us-west-2a
  "10.0.2.0/24",    # us-west-2b
  "10.0.3.0/24"     # us-west-2c
]

database_subnets = [
  "10.0.201.0/24",  # us-west-2a
  "10.0.202.0/24",  # us-west-2b
  "10.0.203.0/24"   # us-west-2c
]
```

---

## Quick Reference Card

| Use Case | VPC Size | Public | Private | Database | Lambda |
|----------|----------|---------|---------|----------|---------|
| **Dev/Test** | /20 | /26 | /24 | /26 | /25 |
| **Small Prod** | /16 | /24 | /22 | /24 | /22 |
| **Large Prod** | /12 | /24 | /20 | /24 | /20 |
| **Enterprise** | /8 | /24 | /16 | /20 | /18 |
| **Serverless-Heavy** | /16 | /26 | /22 | /24 | /20 |

### Lambda Concurrency Planning

| Traffic Pattern | Concurrent Executions | Subnet Size | Use Case |
|----------------|----------------------|-------------|----------|
| **Low** | 10-50 | /26 (62 IPs) | Background jobs |
| **Medium** | 100-500 | /23 (510 IPs) | API backends |
| **High** | 1,000-3,000 | /20 (4,094 IPs) | Event processing |
| **Burst** | 5,000+ | /19 (8,190 IPs) | Real-time analytics |

### Cross-Account CIDR Allocation

| Account Type | Recommended CIDR | IP Count | Example |
|-------------|------------------|----------|---------|
| **Shared Services** | /16 | 65,536 | 10.0.0.0/16 |
| **Development** | /16 | 65,536 | 10.1.0.0/16 |
| **Staging** | /16 | 65,536 | 10.2.0.0/16 |
| **Production** | /16 | 65,536 | 10.3.0.0/16 |
| **Security/Logging** | /16 | 65,536 | 10.4.0.0/16 |
| **Future Expansion** | /12 | 1,048,576 | 10.5.0.0/12 |

### Peering Architecture Comparison

| Pattern | Max VPCs | Complexity | Cost | Use Case |
|---------|----------|------------|------|----------|
| **Hub-Spoke** | 125 | Low | Low | Centralized services |
| **Mesh** | 10-15 | High | High | Full connectivity |
| **Transit Gateway** | 5,000+ | Medium | Medium | Enterprise scale |

**Remember**: Always plan for 3x current capacity and consider future requirements!