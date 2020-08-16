FROM solsson/kafka:graalvm as substitutions

WORKDIR /workspace
COPY substitutions/zookeeper-server-start .
RUN mvn package

FROM curlimages/curl@sha256:aa45e9d93122a3cfdf8d7de272e2798ea63733eeee6d06bd2ee4f2f8c4027d7c \
  as extralibs

USER root
RUN curl -sLS -o /slf4j-simple-1.7.30.jar https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/1.7.30/slf4j-simple-1.7.30.jar
RUN curl -sLS -o /log4j-over-slf4j-1.7.30.jar https://repo1.maven.org/maven2/org/slf4j/log4j-over-slf4j/1.7.30/log4j-over-slf4j-1.7.30.jar

FROM solsson/kafka:nativebase as native

#ARG classpath=/opt/kafka/libs/slf4j-log4j12-1.7.30.jar:/opt/kafka/libs/log4j-1.2.17.jar:/opt/kafka/libs/slf4j-api-1.7.30.jar:/opt/kafka/libs/zookeeper-3.5.8.jar:/opt/kafka/libs/zookeeper-jute-3.5.8.jar
COPY --from=substitutions /workspace/target/*.jar /opt/kafka/libs/substitutions.jar
COPY --from=extralibs /*.jar /opt/kafka/libs/extensions/
ARG classpath=/opt/kafka/libs/substitutions.jar:/opt/kafka/libs/slf4j-api-1.7.30.jar:/opt/kafka/libs/extensions/slf4j-simple-1.7.30.jar:/opt/kafka/libs/extensions/log4j-over-slf4j-1.7.30.jar:/opt/kafka/libs/zookeeper-3.5.8.jar:/opt/kafka/libs/zookeeper-jute-3.5.8.jar

COPY configs/zookeeper-server-start /home/nonroot/native-config

# Remaining issues:
# - java.lang.NoClassDefFoundError: Could not initialize class org.apache.zookeeper.server.admin.JettyAdminServer
#   which is fine because https://github.com/apache/zookeeper/blob/release-3.5.7/zookeeper-server/src/main/java/org/apache/zookeeper/server/admin/AdminServerFactory.java
#   documents that admin server is optional and it's only at startup
# - WARN org.apache.zookeeper.server.ZooKeeperServer - Failed to register with JMX
#   java.lang.NullPointerException at org.apache.zookeeper.jmx.MBeanRegistry.register(MBeanRegistry.java:108)
#   is very annoying because it happens a lot so it fills logs

RUN native-image \
  --no-server \
  --install-exit-handlers \
  -H:+ReportExceptionStackTraces \
  --no-fallback \
  -H:ConfigurationFileDirectories=/home/nonroot/native-config \
  # Added because of org.apache.zookeeper.common.X509Util, org.apache.zookeeper.common.ZKConfig, javax.net.ssl.SSLContext ...
  --allow-incomplete-classpath \
  # Added because of "ClassNotFoundException: org.apache.zookeeper.server.NIOServerCnxnFactory"
  --report-unsupported-elements-at-runtime \
  # -D options from entrypoint
  -Djava.awt.headless=true \
  -Dkafka.logs.dir=/opt/kafka/bin/../logs \
  # -Dlog4j.configuration=file:/etc/kafka/log4j.properties \
  -cp ${classpath} \
  -H:Name=zookeeper-server-start \
  org.apache.zookeeper.server.quorum.QuorumPeerMain \
  /home/nonroot/zookeeper-server-start

FROM gcr.io/distroless/base-debian10:nonroot@sha256:f4a1b1083db512748a305a32ede1d517336c8b5bead1c06c6eac2d40dcaab6ad

COPY --from=native \
  /lib/x86_64-linux-gnu/libz.so.* \
  /lib/x86_64-linux-gnu/

COPY --from=native \
  /usr/lib/x86_64-linux-gnu/libzstd.so.* \
  /usr/lib/x86_64-linux-gnu/libsnappy.so.* \
  /usr/lib/x86_64-linux-gnu/liblz4.so.* \
  /usr/lib/x86_64-linux-gnu/

WORKDIR /usr/local
COPY --from=native /home/nonroot/zookeeper-server-start ./bin/zookeeper-server-start.sh
COPY --from=native /etc/kafka /etc/kafka

ENTRYPOINT [ "/usr/local/bin/zookeeper-server-start.sh" ]
CMD ["/etc/kafka/zookeeper.properties"]
