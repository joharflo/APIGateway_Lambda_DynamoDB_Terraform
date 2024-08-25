# Terraform AWS API CRUD Project

  

## Overview

  

This Terraform project sets up an AWS infrastructure to manage a simple CRUD API using API Gateway and Lambda. The API interacts with a DynamoDB table for storing product information. This project includes:

  

- **API Gateway**: Creates REST APIs with various methods.

- **Lambda Function**: Handles the CRUD operations for the product.

- **DynamoDB Table**: Stores product data.

- **IAM Roles and Policies**: Grants necessary permissions to the Lambda function.

- **Terraform Configuration**: Defines the infrastructure as code.

  

## Project Structure

  

- `main.tf`: Main Terraform configuration file.

- `variables.tf`: Defines variables used in the Terraform configuration.

- `outputs.tf`: Outputs the invocation URLs for the API.

- `lambda/`: Contains the Lambda function code.

- `lambda_function.py`: Python code for the Lambda function.

- `custom_encoder.py`: Custom JSON encoder for handling DynamoDB data types.

  

## Setup

  

### Prerequisites

  

- [Terraform](https://www.terraform.io/downloads.html) (version 1.7 or higher)

- [AWS CLI](https://aws.amazon.com/cli/) (configured with appropriate permissions)

- AWS Account

  

### Configuration

  

1. **Clone the Repository**:

```sh
   git clone https://github.com/joharflo/APIGateway_Lambda_DynamoDB_Terraform.git
   cd APIGateway_Lambda_DynamoDB_Terraform
```

  

2. **Update Variables**:

   Create a `terraform.tfvars` file or set environment variables for your AWS region:

```hcl
   aws_region = "us-east-1"
```

  

3. **Initialize Terraform**:
```sh
   terraform init
```

  

4. **Plan and Apply**:

   Generate an execution plan and apply it:
```sh
   terraform plan
   terraform apply
```

  

5. **Deploy Lambda Function**:

   Ensure that the Lambda function code is in the `lambda/` directory. Terraform will automatically package and deploy the Lambda function as part of the `apply` step.

  

## Outputs

  

After applying the Terraform configuration, you can find the following outputs:

  

- `product_invoke_url`: The URL to access the `/product` resource.

- `products_invoke_url`: The URL to access the `/products` resource.

  

## Lambda Function Code

  

The Lambda function is written in Python and is located in the `lambda/` directory. It handles various HTTP methods for CRUD operations on the DynamoDB table.

  

### Code Files

  

- `lambda_function.py`: Contains the main Lambda function code.

- `custom_encoder.py`: Custom JSON encoder for converting DynamoDB `Decimal` types to floats.

  

  

## Testing

You can use Postman to test the API endpoints.

#### API Endpoints
- **Read product**: `GET /dev/product?productId=<productId>` 
![![[get product]]](/Attachments/GET_PRODUCT.png)

- **Read products**: `GET /dev/products` 
![![[get products]]](/Attachments/GET_PRODUCTS.png) 

- **Create product**: `POST /dev/product`

    - Example Request Body:
```
{
      "productId": "P-300",
      "color": "Red",
      "price": "3500",
      "quantity": "1000"
 }  
```
![![[post product]]](/Attachments/POST_PRODUCT.png)
  



- **Update product**: `PATCH /dev/product`

    - Example Request Body:
```
{
      "productId": "P-300",
      "updateKey": "color",
      "updateValue": "Blue"
 }
```
![![[update product]]](/Attachments/PATCH_PRODUCT.png)

- **Delete product**: `DELETE /dev/product`

    - Example Request Body:
``` 
 {
      "productId": "P-300", 
 } 
```
![![[delete product]]](/Attachments/DELETE_PRODUCT.png)
   
     
## Cleanup

  

To remove all resources created by Terraform, use:

```sh

terraform destroy

```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or features.

  

## License

This project is licensed under the MIT License - see the LICENSE file for details.

