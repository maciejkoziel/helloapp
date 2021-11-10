# Welcome to HelloApp Demo
Code in this repo will deploy RESTful-API helloapp. URL address for API location will be obtained in the last step of deployment.
## Requirements
Code will de deployed to the AWS public cloud, you need  to have your credentials already configured (~/.aws/credentials).
Required applications:
 - terraform (1.0.10)
- docker (20.10.7)
- aws-cli (2.2.44)
>It should also work with different versions but it has not been tested.
# Set up
## Run
Execute bash script ./deploy.sh  to deploy the app, you will be asked for password which will be used for database access configuration.
## Teardown
Execute bash script ./destroyall.sh  to delete all provisioned AWS resources.
## Test
Execute bash script ./test.sh for simple application testing, Load Balancer endpoint in script will be updated during deployment.

# Architecture
## Resources diagram
Diagram is located in doc-diagram directory inside the repository.
## Endpoints
Following rest enpoints are provided:
- /hello/\<username>
	* get:
	Will return \<username>  record stored in database, along with a date of next birtday. If users birthday is today it will return wishes.
	* put:
	Send with parameter "birthday" will store \<username> record in database along with his date of birth.
- /health/
	* get:
	Just return simple heathcheck with 200 status. It is needed for load balancer to determine if traffic should be redirected to the container.

## Containers
Containers are executed in AWS Elastic Container Service (ECS) in a serverless architecture (Fargate). At least one working container should be available all the time, during application update ECR service will detect change of Docker image and spin up new versions, when new version reports heathy state old container will be decommissioned. 
Docker images are stored in AWS Docker Container Registry (ECR).
## Databases
Application is backed up by Postgres database deployed on EC2 instance. Database is replicated online to a second Postgres instance deployed on EC2 instance in another region.
# Repository
## Directories and files:
- **app_setup/**
	Contains heloapp written in Python along with a Dockerfile and helper files.
- **app_terraform/**
	Contains Terrafom files used to deploy ECS service along with all required infrastructure: subnets, security groups, load balancer, nat gateways, routing tables, etc..
- **db_replication_setup/**
	Contains bash scripts used during streaming replication setup between databases.
- **db_terraform/**
	Contains Terraform files used to setup EC2 instances, install and configure Postgress databases, create all required cloud infrastructure as VPC, subnets, peerings, security groups, internet gateways, routes, etc...
- **ecr_terrraform/**
	Contains Terraform files used for setting up ECR for storing Docker images.
- **ssh_keys/**
	Will be created during setup and contains SSH keys for created EC2 instances.
- **deploy.sh**
	Deploys app with all infrastructure
- **destroy.sh**
	Tears down all deployed infrastructure
- **test.sh**
	Contains simple application tests using curl

