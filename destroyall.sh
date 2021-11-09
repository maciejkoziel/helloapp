#!/bin/bash
ECR_URL="$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.eu-west-2.amazonaws.com"

terraform -chdir=app_terraform destroy -auto-approve -var helloapp_image_location="$ECR_URL/helloapp:latest"
terraform -chdir=ecr_terraform destroy -auto-approve
terraform -chdir=db_terraform destroy -auto-approve
