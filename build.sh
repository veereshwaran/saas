#!/bin/sh

export HUB=$(curl "http://${bamboo_APPRANIX_AUTH_TOKEN}@192.168.0.129:3000/onprem/service/director")

docker build --build-arg BASE_IMAGE=$HUB -t dir:${bamboo_buildNumber} .
