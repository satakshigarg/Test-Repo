# Test-Repo

## Overview

This Terraform configuration sets up an Ethereum Geth node on an AWS EC2 instance with monitoring options using Prometheus and CloudWatch.

## Prerequisites

Before applying this Terraform configuration, ensure you have:

- An AWS account
- AWS CLI configured with appropriate access
- Terraform installed on your local machine
- An existing SSH key pair for connecting to the EC2 instance

## Usage

1. Clone this repository:

    ```bash
    git clone <repository_url>
    cd terraform
    ```

2. Initialize Terraform:

    ```bash
    terraform init
    ```

3. Apply the Terraform configuration:

    ```bash
    terraform apply
    ```

    Enter `yes` when prompted to confirm the changes.

4. Get the public DNS name for the instance

    ```bash
    aws ec2 describe-instances \
    --instance-ids <YOUR_INSTANCE_ID> \
    --query 'Reservations[*].Instances[*].{publicdns: PublicDnsName}'
    ```

5. After the infrastructure is created, you can connect to the EC2 instance using the generated key pair:

    ```bash
    ssh -i path/to/your/private/key.pem ubuntu@<instance_public_dns>
    ```

6. Once connected to the instance, you can check the Geth logs, and Prometheus metrics.

## Cleanup

To destroy the created resources:

```bash
terraform destroy
