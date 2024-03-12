#!/bin/bash

aws ecr create-repository --repository-name springpetclinic --image-scanning-configuration scanOnPush=true --region us-east-1

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 687964745987.dkr.ecr.us-east-1.amazonaws.com

docker tag springpetclinic:latest 687964745987.dkr.ecr.us-east-1.amazonaws.com/springpetclinic:latest

docker push 687964745987.dkr.ecr.us-east-1.amazonaws.com/springpetclinic:latest

