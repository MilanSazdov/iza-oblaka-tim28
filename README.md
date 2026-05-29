# iza-oblaka-tim28

Bronze sloj data lake-a za predmet Računarstvo u oblaku. Dnevni ingest Hacker News i Twitter podataka u particionisan S3 bucket, sve u Terraform-u.

## Struktura

```
infra/
  bootstrap/                 jednokratan setup tfstate bucketa i lock tabele
  backend.tf                 S3 + DynamoDB remote state
  main.tf  variables.tf  outputs.tf
  modules/
    global/iam/              role i policy za lambde
    global/s3/               bronze/silver/gold + KMS + lifecycle
    eu-central-1/vpc/        VPC, NAT, S3 endpoint, lambda SG
    eu-central-1/lambdas/    aws_lambda_function, EventBridge, alarms
    notifications/discord/   SNS topic i discord notifier lambda
lambdas/
  bronze/hacker_news/        Python: ingest HN itema
  bronze/twitter/            Python: ingest CSV dataseta
  bronze/tests/              pytest + moto
  notifier/discord/          Python: SNS na discord webhook
scripts/
  invoke_local.py            lokalno pokretanje handlera
.github/workflows/deploy.yml CI/CD
```

## Deploy

### Jednokratan bootstrap

```bash
cd infra/bootstrap
terraform init
terraform apply
```

### GitHub secrets

`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DISCORD_WEBHOOK_URL`.

### IAM policy za machine usera

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProjectS3",
      "Effect": "Allow",
      "Action": ["s3:*"],
      "Resource": [
        "arn:aws:s3:::iza-oblaka-tim28-*",
        "arn:aws:s3:::iza-oblaka-tim28-*/*"
      ]
    },
    {
      "Sid": "ProjectIAM",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole", "iam:CreateRole", "iam:DeleteRole",
        "iam:AttachRolePolicy", "iam:DetachRolePolicy",
        "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
        "iam:PassRole", "iam:TagRole", "iam:UntagRole",
        "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
        "iam:ListInstanceProfilesForRole", "iam:ListRoleTags"
      ],
      "Resource": "arn:aws:iam::*:role/iza-oblaka-tim28-*"
    },
    {
      "Sid": "ServicesUnrestrictedByName",
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "logs:*",
        "events:*",
        "sns:*",
        "dynamodb:*",
        "kms:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2VPC",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
        "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
        "ec2:AllocateAddress", "ec2:ReleaseAddress",
        "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
        "ec2:CreateRoute", "ec2:DeleteRoute",
        "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
        "ec2:CreateVpcEndpoint", "ec2:DeleteVpcEndpoints", "ec2:ModifyVpcEndpoint",
        "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
        "ec2:CreateTags", "ec2:DeleteTags"
      ],
      "Resource": "*"
    }
  ]
}
```

### Pokretanje

Push na `main` startuje deploy workflow.

Verifikacija posle deploy-a:

```bash
aws lambda invoke --function-name iza-oblaka-tim28-dev-bronze-hacker-news \
  --payload '{"date":"2026-05-28"}' --cli-binary-format raw-in-base64-out out.json

aws s3 ls s3://iza-oblaka-tim28-dev-bronze/source=hacker_news/ --recursive
aws s3 ls s3://iza-oblaka-tim28-dev-bronze/source=twitter/    --recursive
```

## Poznata ograničenja

NAT gateway je u jednoj AZ. Machine user koristi long-lived access key (može se zameniti GitHub OIDC).
