# This is a dummy, see ./hooks/build
FROM adoptopenjdk:11.0.10_9-jre-hotspot-focal@sha256:c365d39341f54bd64f4eadce7aa2f2251743dba4bfb7bd2e0a6fc7b76eeba25e

RUN java -XX:+PrintFlagsFinal -version | grep -E "UseContainerSupport|MaxRAMPercentage|MinRAMPercentage|InitialRAMPercentage"
