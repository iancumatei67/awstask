#!/bin/bash

# Variables
REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
SUBNET_AVAILABILITY_ZONE="us-east-1a"
ECR_REPO_NAME="spring-petclinic"
EC2_INSTANCE_TYPE="t2.micro"
SECURITY_GROUP_NAME="my-sg"
DOCKER_COMPOSE_VERSION="1.29.0"
DOCKERHUB_IMAGE="iancumatei67/mainlab"
ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')


# Create Key Pair
key_pair_name="aws-key"
aws ec2 create-key-pair --key-name $key_pair_name --region $REGION --query 'KeyMaterial' --output text > $key_pair_name.pem
chmod 400 $key_pair_name.pem
echo "Key pair created with name: $key_pair_name"

# Create VPC
vpc_id=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --output text --query 'Vpc.VpcId')
echo "VPC created with ID: $vpc_id"

# Create Internet Gateway
internet_gateway_id=$(aws ec2 create-internet-gateway --region $REGION --output text --query 'InternetGateway.InternetGatewayId')
echo "Internet Gateway created with ID: $internet_gateway_id"

# Attach Internet Gateway to VPC
aws ec2 attach-internet-gateway --internet-gateway-id $internet_gateway_id --vpc-id $vpc_id --region $REGION

# Create Subnet
subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $SUBNET_CIDR --availability-zone $SUBNET_AVAILABILITY_ZONE --region $REGION --output text --query 'Subnet.SubnetId')
echo "Subnet created with ID: $subnet_id"

# Create Route Table
route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --region $REGION --output text --query 'RouteTable.RouteTableId')
echo "Route Table created with ID: $route_table_id"

# Create Route to Internet Gateway
aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $internet_gateway_id --region $REGION

# Associate Route Table with Subnet
aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $route_table_id --region $REGION

# Create Security Group
security_group_id=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Security group for EC2 instance" --vpc-id $vpc_id --region $REGION --output text --query 'GroupId')
echo "Security Group created with ID: $security_group_id"

# Allow SSH access
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION

# Allow HTTP
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION

# Create ECR repository
aws ecr create-repository --repository-name $ECR_REPO_NAME --region $REGION 

# Launch EC2 Instance
instance_id=$(aws ec2 run-instances --image-id ami-0d7a109bf30624c99 --count 1 --instance-type $EC2_INSTANCE_TYPE --key-name $key_pair_name --security-group-ids $security_group_id --subnet-id $subnet_id --region $REGION --output text --query 'Instances[0].InstanceId')
echo "EC2 instance launched with ID: $instance_id"


# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $instance_id --region $REGION

# Allocate and associate Elastic IP
elastic_ip=$(aws ec2 allocate-address --domain vpc --region $REGION --output text --query 'AllocationId')
aws ec2 associate-address --instance-id $instance_id --allocation-id $elastic_ip --region $REGION


# Get public IP address
public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --region $REGION --output text --query 'Reservations[0].Instances[0].PublicIpAddress')
echo "Public IP address for EC2 instance: $public_ip"

sleep 30

#Pull Docker image 
docker pull $DOCKERHUB_IMAGE

# Log in to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag the image for ECR
docker tag $DOCKERHUB_IMAGE:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Push Docker image to ECR
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME:latest

# Run container on the EC2 Instance
ssh -i ./$key_pair_name.pem ec2-user@$public_ip << EOF
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo chmod 666 /var/run/docker.sock
docker login -u AWS -p $(aws ecr get-login-password --region us-east-1) $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME:latest
docker run -d -p 80:8080 $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ECR_REPO_NAME:latest

EOF




