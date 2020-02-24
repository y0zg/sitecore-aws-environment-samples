data "aws_ssm_parameter" "packages_role_arn" {
  name = "/sitecore/iam/sitecore-packages-reader-role-arn"
}

data "aws_ssm_parameter" "sitecore_packages_bucket" {
  name = "/sitecore/s3/sitecore-packages-bucket-name"
}

resource "aws_ecs_task_definition" "this" {
  family                = "dacpac"
  execution_role_arn    = data.aws_ssm_parameter.packages_role_arn.value
  container_definitions = <<EOF
[
	{
    "name": "dacpac",
    "image": "273653477426.dkr.ecr.eu-central-1.amazonaws.com/db-dacpac-init:ltsc2019",
    "memory": 512,
    "cpu": 200,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.sitecore.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "dacpac"
      }
    },
    "environment": [
      {
        "name": "DACPAC_S3_BUCKET",
        "value": "${data.aws_ssm_parameter.sitecore_packages_bucket.value}"
      },
      {
        "name": "DACPAC_S3_PATH",
        "value": "dacpacs/9.3.0"
      },
      {
        "name": "DB_PASSWORD",
        "value": "${random_string.db_password.result}"
      },
      {
        "name": "DB_USERNAME",
        "value": "${module.rds.this_db_instance_username}"
      },
      {
        "name": "DB_HOST",
        "value": "${module.rds.this_db_instance_address}"
      },
      {
        "name": "DB_SUFFIX",
        "value": ""
      }
    ]
  }
]
EOF
}
