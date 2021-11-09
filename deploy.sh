#!/bin/bash
set -e #Fail if any command fails

echo "This script will provision demo hello application,
it has been designed for demonstration of proof of concept only and may contain serious security flaws.
Most of resources should be covered by AWS fre tier, but a very small charges may occur."
echo -e "\033[33;5mDo not run it on production!\033[0m"
read -s -p 'Please provide password which will be set up in deployment: ' ONE_TO_RULE_THEM_ALL

#Generate ssh key pair
SSHKEYDIR="./sshkeys"

[ ! -d "$SSHKEYDIR" ] \
    && mkdir "$SSHKEYDIR" \
    && ssh-keygen -t rsa -N '' -f ./$SSHKEYDIR/id_rsa \
    && chmod 600 ./$SSHKEYDIR/id_rsa

#Init and apply terraform, we deploy infrastructure for databases in this step
if [ -f db_terraform/terraform.tfstate ]; then
    echo -e "\n"
    read -p "Existing TF State file detected, destroy current deployment and install new one? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 0
    else
        ./destroyall.sh
    fi
else
    terraform -chdir=db_terraform init
fi

terraform -chdir=db_terraform apply -auto-approve || true

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Terraform postgres infra provisioning unsuccessfull, check logs"
    exit $retVal
fi

#Get IP adresses of created EC2 instances and assign it to env vars
eval "$(terraform -chdir=db_terraform output -json | jq -r '@sh "export PRIMARY_PRIVATE_IP=\(.PRIMARY_PRIVATE_IP.value)\nexport PRIMARY_PUBLIC_IP=\(.PRIMARY_PUBLIC_IP.value)\nexport SECONDARY_PRIVATE_IP=\(.SECONDARY_PRIVATE_IP.value)\nexport SECONDARY_PUBLIC_IP=\(.SECONDARY_PUBLIC_IP.value)"')"

echo "Wait for instance to spin up"
READY="0"
while [ "$READY" != "1" ]
do
    READY=$(ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$PRIMARY_PUBLIC_IP" 'bash -s' < db_replication_setup/00_check_postgres_status.sh) || true
    echo "Please wait, checking if instance is provisioned..."
    sleep 5
done

echo "Setting up SSH keys on primary"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$PRIMARY_PUBLIC_IP" "sudo mkdir /var/lib/pgsql/.ssh"
scp -oStrictHostKeyChecking=no -i sshkeys/id_rsa sshkeys/id_rsa.pub ec2-user@"$PRIMARY_PUBLIC_IP:/tmp/authorized_keys"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$PRIMARY_PUBLIC_IP" "sudo mv  /tmp/authorized_keys /var/lib/pgsql/.ssh/ && sudo chown -R postgres:postgres /var/lib/pgsql/.ssh/"

echo "Setting up SSH keys on secondary"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$SECONDARY_PUBLIC_IP" "sudo mkdir /var/lib/pgsql/.ssh"
scp -oStrictHostKeyChecking=no -i sshkeys/id_rsa sshkeys/id_rsa.pub ec2-user@"$SECONDARY_PUBLIC_IP:/tmp/authorized_keys"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$SECONDARY_PUBLIC_IP" "sudo mv  /tmp/authorized_keys /var/lib/pgsql/.ssh/ && sudo chown -R postgres:postgres /var/lib/pgsql/.ssh/"

echo "Creating users on primary database"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa postgres@"$PRIMARY_PUBLIC_IP" "bash -s $ONE_TO_RULE_THEM_ALL" < db_replication_setup/01_create_users.sh

echo "Restarting secondary instance and starting backup from primary"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$SECONDARY_PUBLIC_IP" "sudo systemctl stop postgresql-12"
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa postgres@"$SECONDARY_PUBLIC_IP" "bash -s $ONE_TO_RULE_THEM_ALL $PRIMARY_PRIVATE_IP" < db_replication_setup/02_pg_basebackup.sh
ssh -oStrictHostKeyChecking=no -i sshkeys/id_rsa ec2-user@"$SECONDARY_PUBLIC_IP" "sudo systemctl start postgresql-12"

#Exporting config data for app
echo "PRIMARY_PUBLIC_IP = \"$PRIMARY_PUBLIC_IP\"" > app_setup/parameters.py
echo "PRIMARY_PRIVATE_IP = \"$PRIMARY_PRIVATE_IP\"" >> app_setup/parameters.py
echo "SECONDARY_PUBLIC_IP = \"$SECONDARY_PUBLIC_IP\"" >> app_setup/parameters.py
echo "SECONDARY_PRIVATE_IP = \"$SECONDARY_PRIVATE_IP\"" >> app_setup/parameters.py
echo "DB_PASSWORD = \"$ONE_TO_RULE_THEM_ALL\"" >> app_setup/parameters.py

#Terraform part for ECR
if [ -f ecr_terraform/terraform.tfstate ]; then
    echo "TF State for ECR detected, recreating"
    terraform -chdir=ecr_terraform destroy -auto-approve
else
    terraform -chdir=ecr_terraform init
fi

terraform -chdir=ecr_terraform apply -auto-approve || true

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Terraform ECR provisioning unsuccessfull, check logs"
    exit $retVal
fi

#Get ECR URL
ECR_URL="$(aws sts get-caller-identity --query 'Account' --output text).dkr.ecr.eu-west-2.amazonaws.com"

#Build docker image
docker build --tag helloapp app_setup
docker tag helloapp:latest $ECR_URL/helloapp:latest

#Login to ECR with docker, to allow image push
aws ecr get-login-password --region eu-west-2 | docker login -u AWS --password-stdin "https://$ECR_URL"

#Push image to ECR
docker push $ECR_URL/helloapp:latest

#Terraform part for ECS
if [ -f ecs_terraform/terraform.tfstate ]; then
    echo "TF State for ECS detected, recreating"
    terraform -chdir=app_terraform destroy -auto-approve -var helloapp_image_location="$ECR_URL/helloapp:latest"
else
    terraform -chdir=app_terraform init
fi

terraform -chdir=app_terraform apply -auto-approve -var helloapp_image_location="$ECR_URL/helloapp:latest" || true

retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Terraform ECS provisioning unsuccessfull, check logs"
    exit $retVal
fi

#Get ELB address from terraform output
eval "$(terraform -chdir=app_terraform output -json | jq -r '@sh "export LOAD_BALANCER_IP=\(.load_balancer_ip.value)"')"

#Update test file
echo "Updating url address in the test file, this step works only on MacOs version of sed, if it fails, please update it manually or update command"
sed -i ".bak" "s/ELB=.*/ELB=$LOAD_BALANCER_IP/" test.sh
