provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "favtech-bucket"
    key    = "techbleat.tfstate"
    region = "us-east-1"
  }
}

resource "aws_lambda_function" "lambda" {
  filename         = "index.zip"
  function_name    = "lambda"
  role             = aws_iam_role.iam_for_lambda_tf.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"
}

resource "aws_iam_role" "iam_for_lambda_tf" {
  name = "iam_for_lambda_tf"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name        = "test-policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sns:Publish",
            "Resource": "arn:aws:sns:us-east-1:697430341089:email"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "test" {
  name       = "sns-attachment"
  roles      = [aws_iam_role.iam_for_lambda_tf.name]
  policy_arn = aws_iam_policy.policy.arn
}


/*
resource "random_id" "id" {
	byte_length = 8
}*/

# HTTP API
resource "aws_apigatewayv2_api" "api" {
	#name          = "api-${random_id.id.hex}"
	name          = "send-email"
	protocol_type = "HTTP"
	target        = aws_lambda_function.lambda.arn
}

# Permission
resource "aws_lambda_permission" "apigw" {
	action        = "lambda:InvokeFunction"
	function_name = aws_lambda_function.lambda.arn
	principal     = "apigateway.amazonaws.com"

	source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "test" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "send-email"
  auto_deploy = true
}

resource "aws_sns_topic" "sns" {
  name = "email"

  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultThrottlePolicy": {
      "maxReceivesPerSecond": 1
    }
  }
}
EOF

  provisioner "local-exec" {
    command = "aws sns subscribe --topic-arn ${aws_sns_topic.sns.arn} --protocol email --notification-endpoint ${var.alarms_email}"
    #command = "aws sns subscribe --topic-arn   arn:aws:sns:eu-west-1:871994821053:my-test-alarms-topic --protocol email --notification-endpoint ${var.alarms_email}"
  }
}

resource "aws_lambda_function_event_invoke_config" "example" {
  function_name = aws_lambda_function.lambda.arn
  destination_config {
    on_success {
      destination = aws_sns_topic.sns.arn
    }
  }
}