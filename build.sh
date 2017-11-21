#!/bin/sh

env

export VERSION=$(curl 'http://192.168.0.129:3000/onprem/service/director' -H 'Authorization: Basic aW5LeUJHZTJ2bXlrTWI0UzVELUI=')

docker build --build-arg VERSION=$VERSION -t dir .
