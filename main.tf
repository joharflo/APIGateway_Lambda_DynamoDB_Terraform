#####################################################################
#          IAM Role for Lambda Function Access to DynamoDB           #
#####################################################################
resource "aws_iam_role" "terraform_serveless_api" {
  name        = "terraform-serveless-api" # Role name
  description = "For API CRUD DynamoDB"   # Description of the role

  # Assume role policy allowing Lambda to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole" # Action to allow
        Effect = "Allow"          # Effect of the action
        Principal = {
          Service = "lambda.amazonaws.com" # Service that can assume this role
        }
      },
    ]
  })
}

#####################################################################
#            Attach DynamoDB Full Access Policy to Role             #
#####################################################################
resource "aws_iam_policy_attachment" "terraform_serveless_api_policy_attachment_dynamodb" {
  name       = "terraform-serveless-api_DynamoDB"                 # Attachment name
  roles      = [aws_iam_role.terraform_serveless_api.name]        # Role to attach policy to
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" # Policy ARN for DynamoDB full access
}

#####################################################################
#            Attach CloudWatch Full Access Policy to Role           #
#####################################################################
resource "aws_iam_policy_attachment" "terraform_serveless_api_policy_attachment_cloudwatch" {
  name       = "terraform-serveless-api_CloudWatch"           # Attachment name
  roles      = [aws_iam_role.terraform_serveless_api.name]    # Role to attach policy to
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess" # Policy ARN for CloudWatch full access
}

#####################################################################
#          Allow API Gateway to Invoke Lambda Function              #
#####################################################################
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"                            # Unique identifier for the statement
  action        = "lambda:InvokeFunction"                                   # Action allowed
  function_name = aws_lambda_function.terraform_serveless_api.function_name # Lambda function to which permission is granted
  principal     = "apigateway.amazonaws.com"                                # Service that is allowed to invoke the function

  # ARN of the API Gateway that can invoke the Lambda function
  source_arn = "${aws_api_gateway_rest_api.terraform-serveless-api_apiGW.execution_arn}/*/*/*"
}



#####################################################################
#       Package Lambda Function Code into a ZIP File                #
#####################################################################
data "archive_file" "lambda_code" {
  type        = "zip"                     # The type of archive to create
  source_dir  = "lambda"                  # Directory containing the Lambda code
  output_path = "${path.root}/lambda/lambda.zip" # Path where the ZIP file will be created
}

#####################################################################
#       Define the Lambda Function and Its Configuration            #
#####################################################################
resource "aws_lambda_function" "terraform_serveless_api" {
  filename      = "${path.root}/lambda/lambda.zip"         # The path to the ZIP file created above
  function_name = "terraform-serveless-api"                # Name of the Lambda function
  handler       = "lambda_function.lambda_handler"         # Entry point in the Lambda function code
  role          = aws_iam_role.terraform_serveless_api.arn # ARN of the IAM role assigned to the Lambda
  runtime       = "python3.10"                             # Runtime environment for the Lambda function
  memory_size   = 500                                      # Memory allocated to the Lambda function
  ephemeral_storage {
    size = 512 # Ephemeral storage allocated to the Lambda function
  }
  source_code_hash = data.archive_file.lambda_code.output_base64sha256 # Hash of the ZIP file for deployment consistency
}


#####################################################################
#                         Create the REST API                       #
#####################################################################
resource "aws_api_gateway_rest_api" "terraform-serveless-api_apiGW" {
  # Create a new REST API in API Gateway
  name = "terraform-serveless-api_apiGW"
  # Provide a description for the API
  description = "For API CRUD DynamoDB API Gateway."
  # Set the endpoint configuration to REGIONAL (regional deployment)
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#####################################################################
#                  Create (/products) resource in the API           #
#####################################################################
resource "aws_api_gateway_resource" "products" {
  # Specify the ID of the REST API this resource belongs to
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the parent resource ID to the root of the API
  parent_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.root_resource_id
  # Define the path part for the resource; this will create the /products endpoint
  path_part = "products"
}


#####################################################################
#            Create GET Method for (/products) resource             #
#####################################################################
resource "aws_api_gateway_method" "products" {
  # Define the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Set the HTTP method for this resource (GET in this case)
  http_method = "GET"
  # Define the authorization type (NONE means no authentication is required)
  authorization = "NONE"
}

# Integration setup for the GET method, connecting it to a Lambda function
resource "aws_api_gateway_integration" "products_integration" {
  # Specify the REST API where this integration will be configured
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Define the HTTP method this integration is for
  http_method = aws_api_gateway_method.products.http_method
  # HTTP method to use for the integration (POST is used for proxy integrations)
  integration_http_method = "POST"
  # Define the type of integration (AWS_PROXY allows the Lambda function to handle requests directly)
  type = "AWS_PROXY"
  # Specify the ARN of the Lambda function that will process the request
  uri = aws_lambda_function.terraform_serveless_api.invoke_arn
}

# Response configuration for the GET method
resource "aws_api_gateway_method_response" "products" {
  # Define the REST API where this method response will be configured
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Define the HTTP method this response configuration is for
  http_method = aws_api_gateway_method.products.http_method
  # Set the HTTP status code to be returned (200 for successful responses)
  status_code = "200"

  # CORS (Cross-Origin Resource Sharing) configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Integration response configuration for the GET method
resource "aws_api_gateway_integration_response" "products" {
  # Define the REST API where this integration response will be configured
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Define the HTTP method this integration response is for
  http_method = aws_api_gateway_method.products.http_method
  # Set the HTTP status code to be returned (matching the method response status code)
  status_code = aws_api_gateway_method_response.products.status_code

  # CORS configuration for the response
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  # Ensure the integration and method resources are created before this resource
  depends_on = [
    aws_api_gateway_method.products,
    aws_api_gateway_integration.products_integration
  ]
}


#####################################################################
#            Create OPTIONS Method for (/products) resource         #
#####################################################################
resource "aws_api_gateway_method" "products_options" {
  # Define the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Set the HTTP method to OPTIONS
  http_method = "OPTIONS"
  # Define the authorization type (NONE means no authentication is required)
  authorization = "NONE"
}

# Integration configuration for the OPTIONS method
resource "aws_api_gateway_integration" "products_options_integration" {
  # Specify the REST API where this integration will be configured
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Define the HTTP method this integration is for
  http_method = aws_api_gateway_method.products_options.http_method
  # HTTP method to use for the integration (OPTIONS in this case)
  integration_http_method = "OPTIONS"
  # Define the type of integration (MOCK is used for handling CORS preflight requests)
  type = "MOCK"
}

# Method response configuration for the OPTIONS method
resource "aws_api_gateway_method_response" "products_options_response" {
  # Define the REST API where this method response will be configured
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Define the HTTP method this response configuration is for
  http_method = aws_api_gateway_method.products_options.http_method
  # Set the HTTP status code to be returned (200 for successful responses)
  status_code = "200"
}

# Integration response configuration for the OPTIONS method
resource "aws_api_gateway_integration_response" "products_options_integration_response" {
  # Define the REST API where this integration response will be configured
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Specify the resource ID for the /products endpoint
  resource_id = aws_api_gateway_resource.products.id
  # Define the HTTP method this integration response is for
  http_method = aws_api_gateway_method.products_options.http_method
  # Set the HTTP status code to be returned (matching the method response status code)
  status_code = aws_api_gateway_method_response.products_options_response.status_code

  # Ensure the method and integration resources are created before this resource
  depends_on = [
    aws_api_gateway_method.products_options,
    aws_api_gateway_integration.products_options_integration
  ]
}



#####################################################################
#                  Create (/product) resource in the API           #
#####################################################################
resource "aws_api_gateway_resource" "product" {
  # Specify the REST API where this resource will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the parent resource ID, which is the root of the API
  parent_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.root_resource_id
  # Define the path part for this resource, which will be appended to the base URL
  path_part = "product"
}


#####################################################################
#            Create GET Method for (/product) resource              #
#####################################################################
resource "aws_api_gateway_method" "product" {
  # Specify the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Define the HTTP method for this endpoint
  http_method = "GET"
  # No authorization required for this method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "product_integration" {
  # Specify the REST API where this integration will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the GET method defined above
  http_method = aws_api_gateway_method.product.http_method
  # Define the integration HTTP method and type
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  # Define the URI for the Lambda function integration
  uri = aws_lambda_function.terraform_serveless_api.invoke_arn
}

resource "aws_api_gateway_method_response" "product" {
  # Specify the REST API where this response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the GET method defined above
  http_method = aws_api_gateway_method.product.http_method
  # Define the status code for the response
  status_code = "200"

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "product" {
  # Specify the REST API where this integration response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the GET method defined above
  http_method = aws_api_gateway_method.product.http_method
  # Set the status code for the integration response
  status_code = aws_api_gateway_method_response.product.status_code

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  # Ensure dependencies are created first
  depends_on = [
    aws_api_gateway_method.product,
    aws_api_gateway_integration.product_integration
  ]
}

#####################################################################
#            Create POST Method for (/product) resource             #
#####################################################################
resource "aws_api_gateway_method" "POST_product" {
  # Specify the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Define the HTTP method for this endpoint
  http_method = "POST"
  # No authorization required for this method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "POST_product_integration" {
  # Specify the REST API where this integration will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the POST method defined above
  http_method = aws_api_gateway_method.POST_product.http_method
  # Define the integration HTTP method and type
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  # Define the URI for the Lambda function integration
  uri = aws_lambda_function.terraform_serveless_api.invoke_arn
}

resource "aws_api_gateway_method_response" "POST_product" {
  # Specify the REST API where this response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the POST method defined above
  http_method = aws_api_gateway_method.POST_product.http_method
  # Define the status code for the response
  status_code = "200"

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "POST_product" {
  # Specify the REST API where this integration response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the POST method defined above
  http_method = aws_api_gateway_method.POST_product.http_method
  # Set the status code for the integration response
  status_code = aws_api_gateway_method_response.POST_product.status_code

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  # Ensure dependencies are created first
  depends_on = [
    aws_api_gateway_method.POST_product,
    aws_api_gateway_integration.POST_product_integration
  ]
}



#####################################################################
#            Create PATCH Method for (/product) resource            #
#####################################################################
resource "aws_api_gateway_method" "PATCH_product" {
  # Specify the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Define the HTTP method for this endpoint
  http_method = "PATCH"
  # No authorization required for this method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "PATCH_product_integration" {
  # Specify the REST API where this integration will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the PATCH method defined above
  http_method = aws_api_gateway_method.PATCH_product.http_method
  # Define the integration HTTP method and type
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  # Define the URI for the Lambda function integration
  uri = aws_lambda_function.terraform_serveless_api.invoke_arn
}

resource "aws_api_gateway_method_response" "PATCH_product" {
  # Specify the REST API where this response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the PATCH method defined above
  http_method = aws_api_gateway_method.PATCH_product.http_method
  # Define the status code for the response
  status_code = "200"

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "PATCH_product" {
  # Specify the REST API where this integration response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the PATCH method defined above
  http_method = aws_api_gateway_method.PATCH_product.http_method
  # Set the status code for the integration response
  status_code = aws_api_gateway_method_response.PATCH_product.status_code

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,PATCH,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  # Ensure dependencies are created first
  depends_on = [
    aws_api_gateway_method.PATCH_product,
    aws_api_gateway_integration.PATCH_product_integration
  ]
}

#####################################################################
#            Create DELETE Method for (/product) resource           #
#####################################################################
resource "aws_api_gateway_method" "DELETE_product" {
  # Specify the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Define the HTTP method for this endpoint
  http_method = "DELETE"
  # No authorization required for this method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "DELETE_product_integration" {
  # Specify the REST API where this integration will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the DELETE method defined above
  http_method = aws_api_gateway_method.DELETE_product.http_method
  # Define the integration HTTP method and type
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  # Define the URI for the Lambda function integration
  uri = aws_lambda_function.terraform_serveless_api.invoke_arn
}

resource "aws_api_gateway_method_response" "DELETE_product" {
  # Specify the REST API where this response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the DELETE method defined above
  http_method = aws_api_gateway_method.DELETE_product.http_method
  # Define the status code for the response
  status_code = "200"

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "DELETE_product" {
  # Specify the REST API where this integration response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the DELETE method defined above
  http_method = aws_api_gateway_method.DELETE_product.http_method
  # Set the status code for the integration response
  status_code = aws_api_gateway_method_response.DELETE_product.status_code

  # CORS configuration
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,PATCH,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  # Ensure dependencies are created first
  depends_on = [
    aws_api_gateway_method.DELETE_product,
    aws_api_gateway_integration.DELETE_product_integration
  ]
}

#####################################################################
#            Create OPTIONS Method for (/product) resource          #
#####################################################################
resource "aws_api_gateway_method" "product_options" {
  # Specify the REST API where this method will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Define the HTTP method for this endpoint
  http_method = "OPTIONS"
  # No authorization required for this method
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "product_options_integration" {
  # Specify the REST API where this integration will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the OPTIONS method defined above
  http_method = aws_api_gateway_method.product_options.http_method
  # Define the integration HTTP method and type
  integration_http_method = "OPTIONS"
  type                    = "MOCK"
}

resource "aws_api_gateway_method_response" "product_options_response" {
  # Specify the REST API where this response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the OPTIONS method defined above
  http_method = aws_api_gateway_method.product_options.http_method
  # Define the status code for the response
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "product_options_integration_response" {
  # Specify the REST API where this integration response will be created
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the resource ID for the /product resource
  resource_id = aws_api_gateway_resource.product.id
  # Use the OPTIONS method defined above
  http_method = aws_api_gateway_method.product_options.http_method
  # Set the status code for the integration response
  status_code = aws_api_gateway_method_response.product_options_response.status_code

  # Ensure dependencies are created first
  depends_on = [
    aws_api_gateway_method.product_options,
    aws_api_gateway_integration.product_options_integration
  ]
}

#####################################################################
#                             Deploy API                            #
#####################################################################
resource "aws_api_gateway_deployment" "deployment" {
  # Ensure all integrations are created before deploying
  depends_on = [
    aws_api_gateway_integration.products_integration,
    aws_api_gateway_integration.products_options_integration,
    aws_api_gateway_integration.product_integration,
    aws_api_gateway_integration.POST_product_integration,
    aws_api_gateway_integration.PATCH_product_integration,
    aws_api_gateway_integration.DELETE_product_integration,
    aws_api_gateway_integration.product_options_integration
  ]

  # Specify the REST API to deploy
  rest_api_id = aws_api_gateway_rest_api.terraform-serveless-api_apiGW.id
  # Set the deployment stage
  stage_name = "dev"
}


#####################################################################
#                 Define the DynamoDB Table for Product Inventory   #
#####################################################################
resource "aws_dynamodb_table" "product_inventory" {
  name           = "product-inventory" # Table name
  billing_mode   = "PROVISIONED"       # Billing mode for provisioned throughput
  read_capacity  = 20                  # Read capacity units
  write_capacity = 20                  # Write capacity units
  hash_key       = "productId"         # Primary key attribute name

  attribute {
    name = "productId" # Attribute name
    type = "S"         # Attribute type (String)
  }

  # Optionally define global secondary indexes or local secondary indexes if needed
  # Optionally define time to live (TTL) settings if applicable
  # Optionally define stream settings if required

  # Example for a global secondary index (if needed):
  # global_secondary_index {
  #   name               = "ProductIndex"
  #   hash_key           = "category"
  #   projection_type    = "ALL"
  #   read_capacity      = 10
  #   write_capacity     = 10
  # }

  # Example for time to live (TTL) settings (if needed):
  # ttl {
  #   attribute_name = "ttl"
  #   enabled        = true
  # }

  # Example for stream settings (if needed):
  # stream_enabled   = true
  # stream_view_type = "NEW_AND_OLD_IMAGES"
}
