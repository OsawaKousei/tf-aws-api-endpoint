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
    content  = "def lambda_handler(event, context):\n    return {'statusCode': 200, 'body': 'Hello from Lambda!'}"
    filename = "lambda_function.py"
  }
}

# 空のLambda関数を作成します
resource "aws_lambda_function" "app_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "example-lambda-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"

  tags = {
    Name = "ExampleLambdaFunction"
  }
}
