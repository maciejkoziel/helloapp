#!/bin/bash
ELB=ecs-lb-1573709468.eu-west-2.elb.amazonaws.com

curl "http://$ELB/hello/jan" -d "birthday=10/11/1991" -X PUT -v
curl "http://$ELB/hello/adam" -d "birthday=1/5/1977" -X PUT -v
curl "http://$ELB/hello/sofia" -d "birthday=30/7/1959" -X PUT -v

curl "http://$ELB/hello/jan"
curl "http://$ELB/hello/adam"
curl "http://$ELB/hello/sofia"
