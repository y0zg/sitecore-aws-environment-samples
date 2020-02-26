locals {
  license = "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"
}

module "cd" {
  source = "./modules/service"

  name                    = "cd"
  ecs_cluster_id          = aws_ecs_cluster.this.id
  vpc_id                  = module.vpc.vpc_id
  route53_zone_name       = "aws.nuuday.nu."
  dns_prefix              = "cd-dev"
  lb_arn                  = aws_lb.lb_external.id
  lb_listener_arn         = aws_lb_listener.frontend.id
  task_execution_role_arn = aws_iam_role.task_execution_role.arn
  desired_task_count      = 1

  container_definitions_json = <<EOF
[
	{
    "name": "cd",
    "image": "273653477426.dkr.ecr.eu-central-1.amazonaws.com/odin-sitecore-xm-cd:9.3.0-4f6f5703",
    "memory": 2048,
    "cpu": 1000,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.sitecore.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "cd"
      }
    },
    "environment":  [
      {
        "name": "SITECORE_CONFIGURATION",
        "value": "TestCD"
      },
      {
        "name": "SITECORE_LICENSE",
        "value": "${local.license}"
      },
      {
        "name": "SITECORE_AppSettings_role:define",
        "value": "ContentDelivery"
      },
      {
        "name": "SITECORE_ConnectionStrings_Security",
        "value": "Server=asore-sc-dev-db.clq1s5ruoulz.eu-central-1.rds.amazonaws.com;User=dbuser;Password=r!VHJ!iGY6bIIxKq;Database=Sitecore.Core"
      },
      {
        "name": "SITECORE_ConnectionStrings_Web",
        "value": "Server=asore-sc-dev-db.clq1s5ruoulz.eu-central-1.rds.amazonaws.com;User=dbuser;Password=r!VHJ!iGY6bIIxKq;Database=Sitecore.Web"
      },
      {
        "name": "A",
        "value": "B"
      }
    ],
		"portMappings": [
      {
        "containerPort": 80
      }
    ]
  }
]
EOF
}

module "cm" {
  source = "./modules/service"

  name                    = "cm"
  ecs_cluster_id          = aws_ecs_cluster.this.id
  vpc_id                  = module.vpc.vpc_id
  route53_zone_name       = "aws.nuuday.nu."
  dns_prefix              = "cm-dev"
  lb_arn                  = aws_lb.lb_external.id
  lb_listener_arn         = aws_lb_listener.frontend.id
  task_execution_role_arn = aws_iam_role.task_execution_role.arn
  desired_task_count      = 1

  container_definitions_json = <<EOF
[
	{
    "name": "cm",
    "image": "273653477426.dkr.ecr.eu-central-1.amazonaws.com/odin-sitecore-xm-cm:9.3.0-4f6f5703",
    "memory": 2048,
    "cpu": 500,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.sitecore.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "cm"
      }
    },
    "secrets": [
      {
        "name": "SITECORE_ConnectionStrings_Security",
        "valueFrom": "${aws_secretsmanager_secret.security_connection_string.arn}"
      },
      {
        "name": "SITECORE_ConnectionStrings_Core",
        "valueFrom": "${aws_secretsmanager_secret.core_connection_string.arn}"
      },
      {
        "name": "SITECORE_ConnectionStrings_Web",
        "valueFrom": "${aws_secretsmanager_secret.web_connection_string.arn}"
      },
      {
        "name": "SITECORE_ConnectionStrings_ExperienceForms",
        "valueFrom": "${aws_secretsmanager_secret.forms_connection_string.arn}"
      },
      {
        "name": "SITECORE_ConnectionStrings_Master",
        "valueFrom": "${aws_secretsmanager_secret.master_connection_string.arn}"
      },
      {
        "name": "SITECORE_ConnectionStrings_Session",
        "valueFrom": "${aws_secretsmanager_secret.sessions_connection_string.arn}"
      }
    ],
    "environment":  [
      {
        "name": "SITECORE_CONFIGURATION",
        "value": "TestCM"
      },
      {
        "name": "SITECORE_LICENSE",
        "value": "${local.license}"
      },
      {
        "name": "SITECORE_AppSettings_role:define",
        "value": "ContentManagement,Indexing"
      },
      {
        "name": "SITECORE_VARIABLES_sourceFolder",
        "value": "c:\\inetpub\\wwwroot\\App_Data\\unicorn"
      },
      {
        "name": "ENTRYPOINT_STDOUT_IIS_ACCESS_LOG_ENABLED",
        "value": "true"
      },
      {
        "name": "SITECORE_FEDERATEDAUTHENTICATION_IDENTITY_SERVER_CALLBACKAUTHORITY",
        "value": "https://cm-dev.aws.nuuday.nu"
      },
      {
        "name": "SITECORE_IDENTITY_SERVER_AUTHORITY",
        "value": "https://sis-dev.aws.nuuday.nu"
      }
    ],
		"portMappings": [
      {
        "containerPort": 80
      }
    ]
  }
]
EOF
}

module "sis" {
  source = "./modules/service"

  name                    = "sis"
  ecs_cluster_id          = aws_ecs_cluster.this.id
  vpc_id                  = module.vpc.vpc_id
  route53_zone_name       = "aws.nuuday.nu."
  dns_prefix              = "sis-dev"
  lb_arn                  = aws_lb.lb_external.id
  lb_listener_arn         = aws_lb_listener.frontend.id
  target_group_protocol   = "HTTPS"
  container_port          = 443
  task_execution_role_arn = aws_iam_role.task_execution_role.arn
  desired_task_count      = 1

  container_definitions_json = <<EOF
[
	{
    "name": "sis",
    "image": "273653477426.dkr.ecr.eu-central-1.amazonaws.com/odin-sitecore-xm-identity:9.3.0-nanoserver-1809-4f6f5703",
    "memory": 1024,
    "cpu": 500,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${aws_cloudwatch_log_group.sitecore.name}",
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "sis"
      }
    },
    "secrets": [
      {
        "name": "SITECORE_Sitecore__IdentityServer__SitecoreMembershipOptions__ConnectionString",
        "valueFrom": "${aws_secretsmanager_secret.security_connection_string.arn}"
      }
    ],
    "environment":  [
      {
        "name": "SITECORE_ENVIRONMENT",
        "value": "Test"
      },
      {
        "name": "SITECORE_LICENSE",
        "value": "${local.license}"
      },
      {
        "name": "SITECORE_URLS",
        "value": "https://+:443"
      },
      {
        "name": "SITECORE_Kestrel__Certificates__Default__Path",
        "value": "c:\\certificates\\identity.pfx"
      },
      {
        "name": "SITECORE_Kestrel__Certificates__Default__Password",
        "value": "Twelve4-4Cranial-Rag-kayo4-Ragweed-This8-grunge9-0Foss-7finalist-hubby"
      },
      {
        "name": "SITECORE_Sitecore__IdentityServer__Clients__DefaultClient__AllowedCorsOrigins__AllowedCorsOriginsGroup1",
        "value": "https://cm-dev.aws.nuuday.nu"
      }
    ],
		"portMappings": [
      {
        "containerPort": 443
      }
    ]
  }
]
EOF
}
