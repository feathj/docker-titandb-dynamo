#!/bin/bash
set -e

CMD=$1
ARG1=$2
ARG2=$3

generate_server_config() {
  if [[ -z "$DYNAMO_LOCAL" ]]; then
    DYNAMO_AUTH_PROVIDER="com.amazonaws.auth.DefaultAWSCredentialsProviderChain"
  else
    DYNAMO_AUTH_PROVIDER="com.amazonaws.auth.BasicAWSCredentials"
    DYNAMO_CREDENTIALS="key,secret"
  fi

  if [[ -z "$ELASTICSEARCH_CLUSTER_NAME" ]]; then
    ELASTICSEARCH_CLUSTER_NAME="elasticsearch"
  fi

cat > /usr/src/app/gremlin-server.yml <<EOF
# Copyright 2014-2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# Portions copyright Titan: Distributed Graph Database - Copyright 2012 and onwards Aurelius.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
# http://aws.amazon.com/apache2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#
# This file was adapted from the following file
# https://github.com/thinkaurelius/titan/blob/1.0.0/titan-dist/src/assembly/static/conf/gremlin-server/gremlin-server.yaml
#
host: 0.0.0.0
port: 8182
threadPoolWorker: 1
gremlinPool: 8
scriptEvaluationTimeout: 30000
serializedResponseTimeout: 30000
channelizer: org.apache.tinkerpop.gremlin.server.channel.WebSocketChannelizer
graphs: {
  graph: /usr/src/app/dynamodb.properties}
plugins:
  - aurelius.titan
scriptEngines: {
  gremlin-groovy: {
    imports: [java.lang.Math],
    staticImports: [java.lang.Math.PI],
    scripts: [scripts/empty-sample.groovy]},
  nashorn: {
      imports: [java.lang.Math],
      staticImports: [java.lang.Math.PI]}}
serializers:
  - { className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV1d0, config: { useMapperFromGraph: graph }}
  - { className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV1d0, config: { serializeResultToString: true }}
  - { className: org.apache.tinkerpop.gremlin.driver.ser.GraphSONMessageSerializerGremlinV1d0, config: { useMapperFromGraph: graph }}
  - { className: org.apache.tinkerpop.gremlin.driver.ser.GraphSONMessageSerializerV1d0, config: { useMapperFromGraph: graph }}
processors:
  - { className: org.apache.tinkerpop.gremlin.server.op.session.SessionOpProcessor, config: { sessionTimeout: 28800000 }}
metrics: {
  consoleReporter: {enabled: false, interval: 180000},
  csvReporter: {enabled: false, interval: 180000, fileName: /tmp/gremlin-server-metrics.csv},
  jmxReporter: {enabled: false},
  slf4jReporter: {enabled: false, interval: 180000},
  gangliaReporter: {enabled: false, interval: 180000, addressingMode: MULTICAST},
  graphiteReporter: {enabled: false, interval: 180000}}
threadPoolBoss: 1
maxInitialLineLength: 4096
maxHeaderSize: 8192
maxChunkSize: 8192
maxContentLength: 65536
maxAccumulationBufferComponents: 1024
resultIterationBatchSize: 64
writeBufferHighWaterMark: 32768
writeBufferHighWaterMark: 65536
ssl: {
  enabled: false}
EOF

cat > /usr/src/app/dynamodb.properties <<EOF
#general Titan configuration
gremlin.graph=com.thinkaurelius.titan.core.TitanFactory
ids.block-size=100000
storage.setup-wait=60000
storage.buffer-size=1024
# Metrics configuration - http://s3.thinkaurelius.com/docs/titan/1.0.0/titan-config-ref.html#_metrics
#metrics.enabled=true
#metrics.prefix=t
# Required; specify logging interval in milliseconds
#metrics.csv.interval=500
#metrics.csv.directory=metrics
# Turn off titan retries as we batch and have our own exponential backoff strategy.
storage.write-time=1 ms
storage.read-time=1 ms
storage.backend=com.amazon.titan.diskstorage.dynamodb.DynamoDBStoreManager

#Amazon DynamoDB Storage Backend for Titan configuration
storage.dynamodb.force-consistent-read=true
storage.dynamodb.prefix=v100
storage.dynamodb.metrics-prefix=d
storage.dynamodb.enable-parallel-scans=false
storage.dynamodb.max-self-throttled-retries=60
storage.dynamodb.control-plane-rate=10

# DynamoDB client configuration: credentials
storage.dynamodb.client.credentials.class-name=$DYNAMO_AUTH_PROVIDER
storage.dynamodb.client.credentials.constructor-args=$DYNAMO_CREDENTIALS

# DynamoDB client configuration: endpoint
# You can change the endpoint to point to Production DynamoDB regions.)
# https://dynamodb.us-east-1.amazonaws.com
storage.dynamodb.client.endpoint=$DYNAMO_ENDPOINT

# max http connections - not recommended to use more than 250 connections in DynamoDB Local
storage.dynamodb.client.connection-max=250
# turn off sdk retries
storage.dynamodb.client.retry-error-max=0

# DynamoDB client configuration: thread pool
storage.dynamodb.client.executor.core-pool-size=25
# Do not need more threads in thread pool than the number of http connections
storage.dynamodb.client.executor.max-pool-size=250
storage.dynamodb.client.executor.keep-alive=60000
storage.dynamodb.client.executor.max-concurrent-operations=1
# should be at least as large as the storage.buffer-size
storage.dynamodb.client.executor.max-queue-length=1024

# 750 r/w CU result in provisioning the maximum equal numbers read and write Capacity Units that can
# be set on one table before it is split into two or more partitions for IOPS. If you will have more than one Rexster server
# accessing the same graph, you should set the read-rate and write-rate properties to values commensurately lower than the
# read and write capacity of the backend tables.

storage.dynamodb.stores.edgestore.capacity-read=100
storage.dynamodb.stores.edgestore.capacity-write=100
storage.dynamodb.stores.edgestore.read-rate=100
storage.dynamodb.stores.edgestore.write-rate=100
storage.dynamodb.stores.edgestore.scan-limit=10000

storage.dynamodb.stores.graphindex.capacity-read=100
storage.dynamodb.stores.graphindex.capacity-write=100
storage.dynamodb.stores.graphindex.read-rate=100
storage.dynamodb.stores.graphindex.write-rate=100
storage.dynamodb.stores.graphindex.scan-limit=10000

storage.dynamodb.stores.systemlog.capacity-read=10
storage.dynamodb.stores.systemlog.capacity-write=10
storage.dynamodb.stores.systemlog.read-rate=10
storage.dynamodb.stores.systemlog.write-rate=10
storage.dynamodb.stores.systemlog.scan-limit=10000

storage.dynamodb.stores.titan_ids.capacity-read=10
storage.dynamodb.stores.titan_ids.capacity-write=10
storage.dynamodb.stores.titan_ids.read-rate=10
storage.dynamodb.stores.titan_ids.write-rate=10
storage.dynamodb.stores.titan_ids.scan-limit=10000

storage.dynamodb.stores.system_properties.capacity-read=10
storage.dynamodb.stores.system_properties.capacity-write=10
storage.dynamodb.stores.system_properties.read-rate=10
storage.dynamodb.stores.system_properties.write-rate=10
storage.dynamodb.stores.system_properties.scan-limit=10000

storage.dynamodb.stores.txlog.capacity-read=10
storage.dynamodb.stores.txlog.capacity-write=10
storage.dynamodb.stores.txlog.read-rate=10
storage.dynamodb.stores.txlog.write-rate=10
storage.dynamodb.stores.txlog.scan-limit=10000

# elasticsearch config
index.search.backend=elasticsearch
index.search.local-mode=false
index.search.cluster-name=$ELASTICSEARCH_CLUSTER_NAME
index.search.hostname=$ELASTICSEARCH_HOST
index.search.elasticsearch.client-only=true
index.search.elasticsearch.sniff=false
EOF
}

# gremlin shell requires remote config to be pulled from yml filed saved on disk (stoopid)
# so we generate a 'docker.yml' file with host specified as 
generate_client_config() {
cat > /usr/src/app/server/dynamodb-titan100-storage-backend-1.0.0-hadoop1/conf/docker.yml <<EOF
hosts: [$1]
port: $2
serializer: { className: org.apache.tinkerpop.gremlin.driver.ser.GryoMessageSerializerV1d0, config: { serializeResultToString: true }}
EOF
}

if [[ $CMD == "server"  ]]; then
  echo "Run with "server" option, starting gremlin server..."
  generate_server_config
  bin/gremlin-server.sh /usr/src/app/gremlin-server.yml
elif [[ $CMD == "client" ]]; then
  echo "Run with "client" option, starting gremlin client..."
  echo "--------------------------------------------------------"
  echo "run \"gremlin> :remote connect tinkerpop.server conf/docker.yml\" to connect to gremlin server"
  echo "execute commands with \":>\" operator IE \"gremlin> :> g.V().has(\"firstName\", \"Jon\")\""
  echo "multiline can be achieved with script string and multiline quote IE"
  echo "gremlin> script=\"\"\""
  echo "gremlin> graph.addVertex(\"firstName\", \"Jon\");"
  echo "gremlin> graph.addVertex(\"firstName\", \"bob\");"
  echo "gremlin> \"\"\""
  echo "gremlin> :> @script"
  if [[ -z "$ARG1" ]]; then
    ARG1=titandb
  fi
  if [[ -z "$ARG2" ]]; then
    ARG2=8182
  fi
  generate_client_config $ARG1 $ARG2
  bin/gremlin.sh
else
  echo 'Run as gremlin server or client.'
  echo 'Image will run as "server" by default.'
  echo 'To run as client, override default CMD with "client", and pass optional host and port (defaults to titandb 8182)'
  echo 'IE with defaults (assumes docker compose with image named "titandb")'
  echo '"docker-compose run --rm titandb client"'
  echo '"docker-compose run --rm titandb client <remotehost> <remoteport>"'
fi
