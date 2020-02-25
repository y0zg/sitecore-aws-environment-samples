resource "aws_iam_policy" "cloudwatch" {
  name = "CloudWatchReadAccess"
  path = "/odin/"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowReadingMetricsFromCloudWatch",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:GetMetricData"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingTagsInstancesRegionsFromEC2",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Get*",
        "ec2:List*",
        "autoscaling:Get*",
        "autoscaling:List*",
        "autoscaling:Describe*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowReadingResourcesForTags",
      "Effect": "Allow",
      "Action": "tag:GetResources",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "grafana" {
  name = "GrafanaReadUser"
  path = "/odin/"
}

resource "aws_iam_user_policy_attachment" "grafana_cloudwatch" {
  user       = aws_iam_user.grafana.name
  policy_arn = aws_iam_policy.cloudwatch.arn
}

resource "aws_iam_access_key" "grafana" {
  user = aws_iam_user.grafana.name
}

