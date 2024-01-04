terraform {
  backend "s3" {
    bucket = "sod-auctions-deployments"
    key    = "terraform/infrastructure"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_lambda_function" "get_auctions" {
  function_name = "get_auctions_apigw"
}

data "aws_lambda_function" "get_similar_items" {
  function_name = "get_similar_items_apigw"
}

data "aws_lambda_function" "get_price_distributions" {
  function_name = "get_price_distributions_apigw"
}

data "aws_lambda_function" "get_current_auctions" {
  function_name = "get_current_auctions_apigw"
}

data "aws_lambda_function" "get_item" {
  function_name = "get_item_apigw"
}

data "aws_lambda_function" "get_price_forecast" {
  function_name = "get_price_forecast_apigw"
}

data "aws_lambda_function" "athena_aggregation_trigger" {
  function_name = "athena_aggregation_trigger"
}

data "aws_lambda_function" "athena_results_trigger" {
  function_name = "athena_results_trigger"
}

data "aws_lambda_function" "athena_distributions_trigger" {
  function_name = "athena_distributions_trigger"
}

resource "aws_s3_bucket_lifecycle_configuration" "s3-lifecycles" {
  bucket = "sod-auctions"

  rule {
    id = "data-lt"
    filter {
      prefix = "data/"
    }
    transition {
      days = 7
      storage_class = "GLACIER"
    }
    transition {
      days = 97
      storage_class = "DEEP_ARCHIVE"
    }
    status = "Enabled"
  }

  rule {
    id = "results-aggregates-lt"
    filter {
      prefix = "results/aggregates/"
    }
    transition {
      days = 7
      storage_class = "GLACIER_IR"
    }
    transition {
      days = 97
      storage_class = "DEEP_ARCHIVE"
    }
    status = "Enabled"
  }

  rule {
    id = "results-partitioning-lt"
    filter {
      prefix = "results/partitioning/"
    }
    expiration {
      days = 3
    }
    status = "Enabled"
  }

  rule {
    id = "results-price-distributions-lt"
    filter {
      prefix = "results/price-distributions/"
    }
    expiration {
      days = 3
    }
    status = "Enabled"
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.athena_aggregation_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::sod-auctions"
}

resource "aws_lambda_permission" "allow_s3_2" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.athena_results_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::sod-auctions"
}

resource "aws_lambda_permission" "allow_s3_3" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.athena_distributions_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::sod-auctions"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "sod-auctions"

  lambda_function {
    lambda_function_arn = data.aws_lambda_function.athena_aggregation_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "data/"
    filter_suffix       = ".parquet"
  }

  lambda_function {
    lambda_function_arn = data.aws_lambda_function.athena_results_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "results/aggregates"
    filter_suffix       = ".csv"
  }

  lambda_function {
    lambda_function_arn = data.aws_lambda_function.athena_distributions_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "results/price-distributions"
    filter_suffix       = ".csv"
  }
}

variable "redeployment_trigger" {
  description = "A dummy variable used to trigger API Gateway deployment if necessary"
  type        = string
  default     = "10"
}

resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "sod-auctions"
  minimum_compression_size = 1000
  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_request_validator" "validator" {
  name = "request_validator"
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  validate_request_parameters = true
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.integration]
  stage_description = var.redeployment_trigger
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"
}

resource "aws_api_gateway_resource" "items_search_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "item-search"
}

resource "aws_api_gateway_resource" "auctions_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "auctions"
}

resource "aws_api_gateway_resource" "price_distributions_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "price-distributions"
}

resource "aws_api_gateway_resource" "current_auctions_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "current-auctions"
}

resource "aws_api_gateway_resource" "items_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_resource" "price_forecast_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "price-forecast"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.auctions_resource.id
  http_method = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = data.aws_lambda_function.get_auctions.invoke_arn
}

resource "aws_api_gateway_integration" "integration2" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.items_search_resource.id
  http_method = aws_api_gateway_method.method2.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = data.aws_lambda_function.get_similar_items.invoke_arn
}

resource "aws_api_gateway_integration" "integration3" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.price_distributions_resource.id
  http_method = aws_api_gateway_method.method3.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = data.aws_lambda_function.get_price_distributions.invoke_arn
}

resource "aws_api_gateway_integration" "integration4" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.current_auctions_resource.id
  http_method = aws_api_gateway_method.method4.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = data.aws_lambda_function.get_current_auctions.invoke_arn
}

resource "aws_api_gateway_integration" "integration5" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.method5.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = data.aws_lambda_function.get_item.invoke_arn
}

resource "aws_api_gateway_integration" "integration6" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.price_forecast_resource.id
  http_method = aws_api_gateway_method.method6.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri  = data.aws_lambda_function.get_price_forecast.invoke_arn
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.auctions_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.realmId" = true
    "method.request.querystring.auctionHouseId" = true
    "method.request.querystring.itemId" = true
    "method.request.querystring.range" = true
  }
  request_validator_id = aws_api_gateway_request_validator.validator.id
  api_key_required = false

}

resource "aws_api_gateway_method" "method2" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.items_search_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.name" = true
  }
  request_validator_id = aws_api_gateway_request_validator.validator.id
  api_key_required = false
}

resource "aws_api_gateway_method" "method3" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.price_distributions_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.realmId" = true
    "method.request.querystring.auctionHouseId" = true
    "method.request.querystring.itemId" = true
  }
  request_validator_id = aws_api_gateway_request_validator.validator.id
  api_key_required = false
}

resource "aws_api_gateway_method" "method4" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.current_auctions_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.realmId" = true
    "method.request.querystring.auctionHouseId" = true
    "method.request.querystring.page" = true
    "method.request.querystring.sortBy" = false
    "method.request.querystring.direction" = false
  }
  request_validator_id = aws_api_gateway_request_validator.validator.id
  api_key_required = false
}

resource "aws_api_gateway_method" "method5" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.id" = true
  }
  request_validator_id = aws_api_gateway_request_validator.validator.id
  api_key_required = false
}

resource "aws_api_gateway_method" "method6" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.price_forecast_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
  api_key_required = false
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.get_auctions.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda2" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.get_similar_items.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda3" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.get_price_distributions.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda4" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.get_current_auctions.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda5" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.get_item.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_lambda6" {
  statement_id = "AllowAPIGatewayInvoke"
  action = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.get_price_forecast.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}
