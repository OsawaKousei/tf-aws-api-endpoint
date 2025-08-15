# export AWS_PROFILE="your-sso-profile-name"

provider "aws" {
  region = "ap-northeast-1"
}

# Lambda関数用のIAMロールを作成します
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda関数の基本実行ロールポリシーをアタッチします
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Lambda関数のソースコードをZIPファイルとして作成します
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source {
    content  = "exports.handler = async (event) => {\nreturn {\nstatusCode: 200,\n body: JSON.stringify('Hello from Lambda!')\n};\n};"
    filename = "index.js"
  }
}

# 空のLambda関数を作成します
resource "aws_lambda_function" "app_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "example-lambda-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs22.x"

  tags = {
    Name = "ExampleLambdaFunction"
  }
}

# Lambda関数にAPI Gatewayからの呼び出し権限を付与
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# HTTP API Gateway を作成
resource "aws_apigatewayv2_api" "http_api" {
  name          = "example-http-api"
  protocol_type = "HTTP"
  description   = "Example HTTP API for Lambda integration"

  tags = {
    Name = "ExampleHTTPAPI"
  }
}

# Lambda関数とのインテグレーションを作成
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.app_lambda.invoke_arn
}

# APIのルートを作成
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# APIのステージを作成
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "DefaultStage"
  }
}

# API Gateway のエンドポイントURLを出力
output "api_gateway_url" {
  description = "HTTP API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}
