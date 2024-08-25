import boto3
import json
import logging
from custom_encoder import CustomEncoder

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# DynamoDB table name and resource initialization
dynamodbTableName = "product-inventory"
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(dynamodbTableName)

# HTTP methods and paths
getMethod = "GET"
postMethod = "POST"
patchMethod = "PATCH"
deleteMethod = "DELETE"
productPath = "/product"
productsPath = "/products"

def lambda_handler(event, context):
    # Log incoming event
    logger.info(event)
    
    # Extract HTTP method and path from the event
    httpMethod = event["httpMethod"]
    path = event["path"]
    
    # Determine the action based on the HTTP method and path
    if httpMethod == getMethod and path == productPath:
        response = getProduct(event["queryStringParameters"]["productId"])
    elif httpMethod == getMethod and path == productsPath:
        response = getProducts()
    elif httpMethod == postMethod and path == productPath:
        response = saveProduct(json.loads(event["body"]))
    elif httpMethod == patchMethod and path == productPath:
        requestBody = json.loads(event["body"])
        response = modifyProduct(requestBody["productId"], requestBody["updateKey"], requestBody["updateValue"])
    elif httpMethod == deleteMethod and path == productPath:
        requestBody = json.loads(event["body"])
        response = deleteProduct(requestBody["productId"])
    else:
        response = buildResponse(404, "Not Found")
    
    return response

def getProduct(productId):
    # Retrieve a single product by ID from the DynamoDB table
    try:
        response = table.get_item(
            Key={"productId": productId}
        )
        if "Item" in response:
            return buildResponse(200, response["Item"])
        else:
            return buildResponse(404, {"Message": "ProductId: {0} not found".format(productId)})
    except Exception as e:
        logger.exception("Error getting product: %s", str(e))
        return buildResponse(500, "Error getting product")

def getProducts():
    # Retrieve all products from the DynamoDB table
    try:
        response = table.scan()
        result = response["Items"]

        # Handle pagination if there are more items
        while "LastEvaluatedKey" in response:
            response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
            result.extend(response["Items"])

        body = {
            "products": result
        }
        return buildResponse(200, body)
    except Exception as e:
        logger.exception("Error getting products: %s", str(e))
        return buildResponse(500, "Error getting products")

def saveProduct(requestBody):
    # Save a new product to the DynamoDB table
    try:
        table.put_item(Item=requestBody)
        body = {
            "Operation": "SAVE",
            "Message": "SUCCESS",
            "Item": requestBody
        }
        return buildResponse(200, body)
    except Exception as e:
        logger.exception("Error saving product: %s", str(e))
        return buildResponse(500, "Error saving product")

def modifyProduct(productId, updateKey, updateValue):
    # Update an existing product's attribute in the DynamoDB table
    try:
        response = table.update_item(
            Key={"productId": productId},
            UpdateExpression="set {0} = :value".format(updateKey),
            ExpressionAttributeValues={":value": updateValue},
            ReturnValues="UPDATED_NEW"
        )
        body = {
            "Operation": "UPDATE",
            "Message": "SUCCESS",
            "UpdatedAttributes": response["Attributes"]
        }
        return buildResponse(200, body)
    except Exception as e:
        logger.exception("Error modifying product: %s", str(e))
        return buildResponse(500, "Error modifying product")

def deleteProduct(productId):
    # Delete a product from the DynamoDB table
    try:
        response = table.delete_item(
            Key={"productId": productId},
            ReturnValues="ALL_OLD"
        )
        body = {
            "Operation": "DELETE",
            "Message": "SUCCESS",
            "deletedItem": response.get("Attributes")
        }
        return buildResponse(200, body)
    except Exception as e:
        logger.exception("Error deleting product: %s", str(e))
        return buildResponse(500, "Error deleting product")

def buildResponse(statusCode, body=None):
    # Build the HTTP response with status code and body
    response = {
        "statusCode": statusCode,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        }
    }

    if body is not None:
        response["body"] = json.dumps(body, cls=CustomEncoder)
    
    return response
