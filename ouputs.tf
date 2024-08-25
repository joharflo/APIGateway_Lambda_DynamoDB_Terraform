#####################################################################
#                  Output the Invoke URL for the Product Resource   #
#####################################################################
output "product_invoke_url" {
  description = "Invoke URL for the product resource"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_resource.product.path}"
}

#####################################################################
#                  Output the Invoke URL for the Products Resource  #
#####################################################################
output "products_invoke_url" {
  description = "Invoke URL for the products resource"
  value       = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_resource.products.path}"
}
