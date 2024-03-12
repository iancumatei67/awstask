#!/bin/bash

aws ec2 create-vpc --cidr-block 10.0.0.0/16

aws ec2 create-subnet --vpc-id vpc-089c37358e2657c0c --cidr-block 10.0.0.0/24

aws ec2 create-security-group --group-name my-security-group --description "My security group" --vpc-id vpc-089c37358e2657c0c

aws ec2 authorize-security-group-ingress --group-id sg-02b71a67d2bf2623a --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-02b71a67d2bf2623a --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id sg-02b71a67d2bf2623a --protocol tcp --port 443 --cidr 0.0.0.0/0

aws ec2 run-instances --image-id ami ami-0440d3b780d96b29d --instance-type t2.micro --subnet-id subnet-0ead1cc28fc617a41 --security-group-ids sg-02b71a67d2bf2623a

aws ec2 allocate-address --domain vpc

aws ec2 associate-address --instance-id i-0d193b2387c40a2c1 --allocation-id eipalloc-046df4f24f08a2202
