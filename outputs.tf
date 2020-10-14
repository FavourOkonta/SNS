output "sns_arn" {
  value = aws_sns_topic.sns.arn
}


output "base_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}