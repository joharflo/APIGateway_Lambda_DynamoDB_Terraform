#####################################################################
#                 Specify Terraform Version and Providers            #
#####################################################################
terraform {
  required_version = "~> 1.7" # Specifies the required Terraform version (1.7.x)

  required_providers {
    aws = {
      source  = "hashicorp/aws" # Source for the AWS provider
      version = "~> 5.0"        # Specifies the AWS provider version (5.x)
    }
    archive = {
      source  = "hashicorp/archive" # Source for the Archive provider
      version = "~> 2.0"            # Specifies the Archive provider version (2.x)
    }
  }
}

#####################################################################
#                           Configure AWS Provider                   #
#####################################################################
provider "aws" {
  region = "us-east-1" # AWS region where resources will be created
}
