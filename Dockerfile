# This is a dummy, see ./hooks/build
FROM eclipse-temurin:11.0.12_7-jre-focal@sha256:23d5cad605d1d2ef79098016397e1c8fb993d28df79cf41c40a6904ae779f4ec

RUN java -XX:+PrintFlagsFinal -version | grep -E "UseContainerSupport|MaxRAMPercentage|MinRAMPercentage|InitialRAMPercentage"
