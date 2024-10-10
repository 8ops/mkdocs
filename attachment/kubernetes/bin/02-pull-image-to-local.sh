#!/bin/bash

#
# usage
#  pull_image_to_local.sh kubernetesui/metrics-scraper:v1.0.7 
#  pull_image_to_local.sh registry.cn-hangzhou.aliyuncs.com/google_containers/nginx-ingress-controller:v1.1.0
#  pull_image_to_local.sh nginx:1.21.4 third
# 
# explain
#  docker pull kubernetesui/metrics-scraper:v1.0.7
#  docker tag kubernetesui/metrics-scraper:v1.0.7 hub.8ops.top/google_containers/metrics-scraper:v1.0.7
#  docker push hub.8ops.top/google_containers/metrics-scraper:v1.0.7
#  docker rmi kubernetesui/metrics-scraper:v1.0.7
#  docker rmi hub.8ops.top/google_containers/metrics-scraper:v1.0.7
#

set -e

src=$1
dst=$2
harbor=hub.8ops.top
[ -z ${dst} ] && dst=google_containers
docker pull ${src}
docker tag ${src} `echo ${src} |awk -v harbor=${harbor} -v dst=${dst} -F'/' '{printf("%s/%s/%s",harbor,dst,$NF)}'`
docker push `echo ${src} |awk -v harbor=${harbor} -v dst=${dst} -F'/' '{printf("%s/%s/%s",harbor,dst,$NF)}'`
docker rmi ${src}
docker rmi `echo ${src} |awk -v harbor=${harbor} -v dst=${dst} -F'/' '{printf("%s/%s/%s",harbor,dst,$NF)}'`

