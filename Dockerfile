FROM maven:3.3.3-jdk-8

RUN apt-get update \
  && apt-get install --no-install-recommends -y zip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# install
RUN git clone -b 1.0.0 --single-branch --depth 1 https://github.com/awslabs/dynamodb-titan-storage-backend.git . \
  && mvn install \
  && ./src/test/resources/install-gremlin-server.sh

WORKDIR /usr/src/app/server/dynamodb-titan100-storage-backend-1.0.0-hadoop1

EXPOSE 8182
COPY docker-entrypoint.sh .
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["server"
