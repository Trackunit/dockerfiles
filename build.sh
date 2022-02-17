#!/bin/bash

VERSION="1.0.1.TU"
TAG="trackunit/solsson-kafka-prometheus-jmx-exporter"

docker build ./prometheus-jmx-exporter -t ${TAG}:${VERSION}
docker push ${TAG}:${VERSION}
