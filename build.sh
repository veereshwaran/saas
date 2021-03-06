#!/bin/sh

ls

export HUB=$(curl "http://${bamboo_APPRANIX_AUTH_TOKEN}@192.168.0.129:3000/onprem/service/director")

tar -cJf circuit-saas-1.tar.xz . --exclude='circuit-saas-1.tar.xz'

docker build --build-arg BASE_IMAGE=$HUB -t dir:${bamboo_buildNumber} .

docker rmi $HUB
