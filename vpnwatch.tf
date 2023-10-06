# Define your EC2 instance IDs using locals
#Filter by tag name to determine the app ids

data "aws_region" "current" {}

resource "null_resource" "generate_lambda_payload" {
  provisioner "local-exec" {
    command = "bash generate_lambda_payload.sh '${aws_instance.app.id}' '${data.aws_region.current.name}' '${aws_cloudwatch_event_rule.ec2_stop_rule.name}'"
  }

  depends_on = [
    aws_instance.app,
  ]

  triggers = {
    always_run = "${timestamp()}"
  }
}


# 1. CloudWatch Event rule to trigger the Lambda after 30 minutes
resource "aws_cloudwatch_event_rule" "ec2_stop_rule" {
  name        = "StopEC2After30Min"
  description = "Trigger the Lambda to stop the EC2 instance after 30 minutes"

  # Run the rule 30 minutes after it's enabled
  schedule_expression = "rate(30 minutes)"
}

# 2. Permission for the CloudWatch Event rule to trigger the Lambda
resource "aws_lambda_permission" "allow_cloudwatch_event" {
  statement_id  = "AllowExecutionFromCloudWatchEvent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_start_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_stop_rule.arn
}

# 3. CloudWatch Event target: The Lambda function that should be triggered
resource "aws_cloudwatch_event_target" "ec2_stop_target" {
  rule      = aws_cloudwatch_event_rule.ec2_stop_rule.name
  target_id = "StopEC2Target"
  arn       = aws_lambda_function.ec2_start_stop.arn
}

# 1. AWS Lambda Function
resource "aws_lambda_function" "ec2_start_stop" {
  filename      = "lambda_function_payload.zip"
  function_name = "ec2_start_stop"
  role          = aws_iam_role.ec2_lambda.arn
  handler       = "index.handler"
  #provider      = aws.region

  #source_code_hash = filebase64sha256("lambda_function_payload.zip")
  # Basicaly We change the payload during the apply process.
  #lifecycle {
  #  ignore_changes = [source_code_hash]
  #}

  runtime = "python3.9"
  depends_on = [
    null_resource.generate_lambda_payload
  ]
}

resource "aws_iam_role" "ec2_lambda" {
  name = "role_lambda_ec2_start_stop"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_lambda_s3" {
  role       = aws_iam_role.ec2_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}


resource "aws_sns_topic" "alarm_action" {
  name = "vpn-usage-alarm-action"
}

# 2. Allow the SNS topic to trigger the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_start_stop.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarm_action.arn
}


# 3. Subscribe the Lambda function to the SNS topic
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.alarm_action.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ec2_start_stop.arn
}


# 2. CloudWatch Metrics and Alarms
resource "aws_cloudwatch_metric_alarm" "vpn_usage" {
  alarm_name          = "vpn-usage-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NetworkPacketsOut" # This is just an example, use appropriate metric
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "400" # Set appropriate threshold for your usage
  alarm_description   = "This metric checks vpn usage"
  alarm_actions       = [aws_sns_topic.alarm_action.arn]

  dimensions = {
    InstanceId = aws_instance.wireguard_server.id
  }

  depends_on = [ 
    aws_lambda_function.ec2_start_stop,
    aws_sns_topic_subscription.lambda_subscription
  ]
}
output "app_instance_id" {
  description = "The ID of the app instance"
  value       = aws_instance.app.id
}