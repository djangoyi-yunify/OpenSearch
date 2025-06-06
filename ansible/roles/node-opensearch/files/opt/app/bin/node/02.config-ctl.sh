# paths
OPENSEARCH_CONF_PATH=/opt/app/current/conf/opensearch/opensearch.yml
STATIC_SETTINGS_PATH=/data/appctl/data/settings.static
DYNAMIC_SETTINGS_PATH=/data/appctl/data/settings.dynamic
KEYSTORE_SETTINGS_PATH=/data/appctl/data/settings.keystore
JVM_OPTIONS_PATH=/opt/app/current/conf/opensearch/jvm.options
LOG4J2_PROPERTIES_PATH=/opt/app/current/conf/opensearch/log4j2.properties
IKANALYZER_CFG_XML_PATH=/opt/app/current/conf/opensearch/analysis-ik/IKAnalyzer.cfg.xml
SECURITY_CONF_PATH=/opt/app/current/conf/opensearch/opensearch-security
SECURITY_TOOL_PATH=/opt/opensearch/current/plugins/opensearch-security/tools
KEYSTORE_TOOL_PATH=/opt/opensearch/current/bin/opensearch-keystore
OPENSEARCH_JAVA_HOME=/opt/opensearch/current/jdk
OPENSEARCH_HOME=/opt/opensearch/current
OPENSEARCH_PATH_CONF=/opt/app/current/conf/opensearch
CERT_OS_USER_CA_PATH=/data/appctl/data/cert.os.user_ca
CERT_OS_USER_NODE_CERT_PATH=/data/appctl/data/cert.os.user_node_cert
CERT_OS_USER_NODE_KEY_PATH=/data/appctl/data/cert.os.user_node_key
OPENSEARCH_CONF_USER_CERTS_PATH=/opt/app/current/conf/opensearch/certs/user

# $1 confing string
# $2 key
getItemFromConf() {
    local res=$(echo "$1" | sed '/^'$2'=/!d;s/^'$2'=//')
    echo "$res"
}

# recreate opensearch.yml according to static config
refreshOpenSearchConf() {
    local rolestr=""
    if [ "$IS_MASTER" = "true" ]; then
        rolestr="cluster_manager, remote_cluster_client"
    else
        rolestr="data, ingest, remote_cluster_client"
    fi
    local masterlist=$(echo $STABLE_MASTER_NODES_HOSTS $JOINING_MASTER_NODES_HOSTS)

    local settings=$(cat $STATIC_SETTINGS_PATH)
    local sslHttpEnabled=$(getItemFromConf "$settings" "static.os.ssl.http.enabled")
    local threadPoolSearchQueueSize=$(getItemFromConf "$settings" "static.os.thread_pool.search.queue_size")
    local threadPoolWriteQueueSize=$(getItemFromConf "$settings" "static.os.thread_pool.write.queue_size")
    local httpCorsEnabled=$(getItemFromConf "$settings" "static.os.http.cors.enabled")
    local httpCorsAllowOrigin=$(getItemFromConf "$settings" "static.os.http.cors.allow-origin")
    local gatewayRecoverAfterTime=$(getItemFromConf "$settings" "static.os.gateway.recover_after_time")
    local gatewayExpectedDataNodes=$(getItemFromConf "$settings" "static.os.gateway.expected_data_nodes")
    local gatewayRecoverAfterDataNodes=$(getItemFromConf "$settings" "static.os.gateway.recover_after_data_nodes")
    local osAdditionalLine1=$(getItemFromConf "$settings" "static.os.os_additional_line1")
    local osAdditionalLine2=$(getItemFromConf "$settings" "static.os.os_additional_line2")
    local osAdditionalLine3=$(getItemFromConf "$settings" "static.os.os_additional_line3")
    local indicesMemoryIndexBufferSize=$(getItemFromConf "$settings" "static.os.indices.memory.index_buffer_size")
    local indicesFielddataCacheSize=$(getItemFromConf "$settings" "static.os.indices.fielddata.cache.size")
    local indicesQueriesCacheSize=$(getItemFromConf "$settings" "static.os.indices.queries.cache.size")
    local indicesRequestsCacheSize=$(getItemFromConf "$settings" "static.os.indices.requests.cache.size")
    local reindexRemoteWhitelist=$(getItemFromConf "$settings" "static.os.reindex.remote.whitelist")
    local repositoriesUrlAllowedUrls=$(getItemFromConf "$settings" "static.os.repositories.url.allowed_urls")
    local nodeAttrData=$(getItemFromConf "$settings" "static.os.node.attr.data")
    local scriptAllowedTypes=$(getItemFromConf "$settings" "static.os.script.allowed_types")
    local scriptAllowedContexts=$(getItemFromConf "$settings" "static.os.script.allowed_contexts")
    local nodeAttrDataLine
    local scriptAllowedTypesLine
    local scriptAllowedContextsLine

    if [ -n "$nodeAttrData" ]; then
        nodeAttrDataLine="node.attr.data: $nodeAttrData"
    fi

    if [ -n "$scriptAllowedTypes" ]; then
        scriptAllowedTypesLine="script.allowed_types: $scriptAllowedTypes"
    fi

    if [ -n "$scriptAllowedContexts" ]; then
        scriptAllowedContextsLine="script.allowed_contexts: $scriptAllowedContexts"
    fi

    local osUserCaEnabled=$(getItemFromConf "$settings" "static.os.user_ca_enabled")
    local certStr="qc"
    if [ "$osUserCaEnabled" = "true" ]; then
        certStr="user"
    fi

    local cfg=$(cat <<OS_CONF
cluster.name: $CLUSTER_ID

node.name: $NODE_NAME
node.roles: [ $rolestr ]
node.attr.zone: $MY_ZONE
$nodeAttrDataLine

path.data: /data/opensearch/data
path.logs: /data/opensearch/logs

network.host: $MY_IP

http.port: 9200
http.cors.enabled: $httpCorsEnabled
http.cors.allow-origin: "$httpCorsAllowOrigin"

discovery.seed_hosts: [ ${masterlist// /,} ]

thread_pool.write.queue_size: $threadPoolWriteQueueSize
thread_pool.search.queue_size: $threadPoolSearchQueueSize

gateway.recover_after_time: $gatewayRecoverAfterTime
gateway.expected_data_nodes: $gatewayExpectedDataNodes
gateway.recover_after_data_nodes: $gatewayRecoverAfterDataNodes

indices.memory.index_buffer_size: $indicesMemoryIndexBufferSize

indices.fielddata.cache.size: $indicesFielddataCacheSize
indices.queries.cache.size: $indicesQueriesCacheSize
indices.requests.cache.size: $indicesRequestsCacheSize

reindex.remote.whitelist: "$reindexRemoteWhitelist"

repositories.url.allowed_urls: $repositoriesUrlAllowedUrls

$scriptAllowedTypesLine
$scriptAllowedContextsLine

$osAdditionalLine1
$osAdditionalLine2
$osAdditionalLine3

plugins.security.ssl.http.enabled: $sslHttpEnabled
plugins.security.ssl.http.pemcert_filepath: certs/$certStr/node1.pem
plugins.security.ssl.http.pemkey_filepath: certs/$certStr/node1-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: certs/$certStr/root-ca.pem

plugins.security.ssl.transport.pemkey_filepath: certs/qc/node1-key.pem
plugins.security.ssl.transport.pemcert_filepath: certs/qc/node1.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: certs/qc/root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

plugins.security.allow_unsafe_democertificates: true
plugins.security.allow_default_init_securityindex: true

plugins.security.authcz.admin_dn:
  - 'CN=qcadmin,OU=NoSql,O=QC,L=WuHan,ST=HuBei,C=CN'
plugins.security.nodes_dn:
  - 'CN=node.opensearch.cluster,OU=NoSql,O=QC,L=WuHan,ST=HuBei,C=CN'

plugins.security.audit.type: internal_opensearch
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.restapi.roles_enabled: ["all_access", "security_rest_api_access"]
plugins.security.system_indices.enabled: true
plugins.security.system_indices.indices: [".plugins-ml-model", ".plugins-ml-task", ".opendistro-alerting-config", ".opendistro-alerting-alert*", ".opendistro-anomaly-results*", ".opendistro-anomaly-detector*", ".opendistro-anomaly-checkpoints", ".opendistro-anomaly-detection-state", ".opendistro-reports-*", ".opensearch-notifications-*", ".opensearch-notebooks", ".opensearch-observability", ".opendistro-asynchronous-search-response*", ".replication-metadata-store"]
node.max_local_storage_nodes: 3
OS_CONF
    )
    echo "$cfg" > ${OPENSEARCH_CONF_PATH}
}

# modify opensearch.yml for cluster init
injectClusterInitConf() {
    local cfg=$(cat<<CLUSTER_INIT
# managed by appctl, do not modify
cluster.initial_master_nodes: [ $NODE_NAME ]
CLUSTER_INIT
    )
    echo "$cfg" >> $OPENSEARCH_CONF_PATH
}

restoreOpenSearchConf() {
    sed -i '/# managed by appctl, do not modify/,$d' $OPENSEARCH_CONF_PATH
}

refreshJvmOptions() {
    local osfolder="/data/opensearch"
    local conffolder="/opt/app/current/conf/opensearch"
    local maxHeap=$((31*1024))
    local halfMem=$((MY_MEM/2))
    local realHeap
    if [ "$halfMem" -le $maxHeap ]; then
        realHeap=$halfMem
    else
        realHeap=$maxHeap
    fi
    local settings=$(cat $STATIC_SETTINGS_PATH)
    local jvmEnableHeapDump=$(getItemFromConf "$settings" "static.jvm.enable_heap_dump")
    local jvmDumpConf=""
    if [ "$jvmEnableHeapDump" = "true" ]; then
        jvmDumpConf=$(cat <<JVM_DUMP
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data/opensearch/dump
JVM_DUMP
        )
    fi

    local cfg=$(cat<<JVM_CONF
# Xms represents the initial size of total heap space
# Xmx represents the maximum size of total heap space
-Xms${realHeap}m
-Xmx${realHeap}m

## GC configuration
8-10:-XX:+UseConcMarkSweepGC
8-10:-XX:CMSInitiatingOccupancyFraction=75
8-10:-XX:+UseCMSInitiatingOccupancyOnly

## G1GC Configuration
# NOTE: G1GC is the default GC for all JDKs 11 and newer
11-:-XX:+UseG1GC
# See https://github.com/elastic/elasticsearch/pull/46169 for the history
# behind these settings, but the tl;dr is that default values can lead
# to situations where heap usage grows enough to trigger a circuit breaker
# before GC kicks in.
11-:-XX:G1ReservePercent=25
11-:-XX:InitiatingHeapOccupancyPercent=30

## JVM temporary directory
-Djava.io.tmpdir=\${OPENSEARCH_TMPDIR}

## heap dumps
$jvmDumpConf

# specify an alternative path for JVM fatal error logs
-XX:ErrorFile=${osfolder}/logs/hs_err_pid%p.log

## JDK 8 GC logging
8:-XX:+PrintGCDetails
8:-XX:+PrintGCDateStamps
8:-XX:+PrintTenuringDistribution
8:-XX:+PrintGCApplicationStoppedTime
8:-Xloggc:${osfolder}/logs/gc.log
8:-XX:+UseGCLogFileRotation
8:-XX:NumberOfGCLogFiles=32
8:-XX:GCLogFileSize=64m

# JDK 9+ GC logging
9-:-Xlog:gc*,gc+age=trace,safepoint:file=${osfolder}/logs/gc.log:utctime,pid,tags:filecount=32,filesize=64m

# Explicitly allow security manager (https://bugs.openjdk.java.net/browse/JDK-8270380)
18-:-Djava.security.manager=allow

# JDK 20+ Incubating Vector Module for SIMD optimizations;
# disabling may reduce performance on vector optimized lucene
20-:--add-modules=jdk.incubator.vector

# HDFS ForkJoinPool.common() support by SecurityManager
-Djava.util.concurrent.ForkJoinPool.common.threadFactory=org.opensearch.secure_sm.SecuredForkJoinWorkerThreadFactory

## OpenSearch Performance Analyzer
# -Dclk.tck=100
# -Djdk.attach.allowAttachSelf=true
# for performance analyzer and other plugins
-Djava.security.policy=${conffolder}/app.policy
--add-opens=jdk.attach/sun.tools.attach=ALL-UNNAMED
# s3 repo settings
-Dopensearch.allow_insecure_settings=true
JVM_CONF
    )
    echo "$cfg" > ${JVM_OPTIONS_PATH}
}


# calculate secret hash with 
calcSecretHash() {
    chmod +x $SECURITY_TOOL_PATH/hash.sh
    OPENSEARCH_JAVA_HOME=$OPENSEARCH_JAVA_HOME $SECURITY_TOOL_PATH/hash.sh -p $1 | tail -n1
}

# inject internal user when cluster init
injectInternalUsers() {
    local syshash=$(calcSecretHash $SYS_USER_PWD)
    local osdhash=$(calcSecretHash $OSD_USER_PWD)
    local lsthash=$(calcSecretHash $LST_USER_PWD)
    local cfg=$(cat<<INTERNAL_USER
# managed by appctl, do not modify
$SYS_USER:
  hash: "$syshash"
  reserved: true
  hidden: true
  backend_roles:
  - "admin"
  description: "internal user: $SYS_USER"
INTERNAL_USER
)

    echo "$cfg" >> $SECURITY_CONF_PATH/internal_users.yml

    local line=$(sed -n '/^logstash:/=' $SECURITY_CONF_PATH/internal_users.yml)
    line=$((line+1))
    sed -i "$line s/.*/#&/" $SECURITY_CONF_PATH/internal_users.yml
    sed -i "$line i \ \ hash: \"$lsthash\"" $SECURITY_CONF_PATH/internal_users.yml

    line=$(sed -n '/^kibanaserver:/=' $SECURITY_CONF_PATH/internal_users.yml)
    line=$((line+1))
    sed -i "$line s/.*/#&/" $SECURITY_CONF_PATH/internal_users.yml
    sed -i "$line i \ \ hash: \"$osdhash\"" $SECURITY_CONF_PATH/internal_users.yml
}

setAdminPass() {
    local settings=$(cat $STATIC_SETTINGS_PATH)
    local admin_pwd=$(getItemFromConf "$settings" "static.os.admin_pass")
    local adminhash=$(calcSecretHash $admin_pwd)

    fn=$SECURITY_CONF_PATH/internal_users.yml
    adminLine=$(awk '/^admin/{print NR; exit}' $fn)
    hashLine=$(awk -v n=$adminLine 'NR>n && /hash/{print NR; exit}' $fn)
    sed -i "$hashLine c \ \ hash: \"$adminhash\"" $fn
}

restoreInternalUsers() {
    sed -i '/# managed by appctl, do not modify/,$d' ${SECURITY_CONF_PATH}/internal_users.yml

    local line=$(sed -n '/^logstash:/=' $SECURITY_CONF_PATH/internal_users.yml)
    line=$((line+1))
    sed -i "$line d" $SECURITY_CONF_PATH/internal_users.yml
    sed -i "$line s/#//" $SECURITY_CONF_PATH/internal_users.yml

    line=$(sed -n '/^kibanaserver:/=' $SECURITY_CONF_PATH/internal_users.yml)
    line=$((line+1))
    sed -i "$line d" $SECURITY_CONF_PATH/internal_users.yml
    sed -i "$line s/#//" $SECURITY_CONF_PATH/internal_users.yml
}

refreshLog4j2Properties() {
    local settings=$(cat $STATIC_SETTINGS_PATH)
    local rootLoggerLevel=$(getItemFromConf "$settings" "static.log4j.rootLogger.level")
    local loggerActionLevel=$(getItemFromConf "$settings" "static.log4j.logger.action.level")
    local loggerDeprecationLevel=$(getItemFromConf "$settings" "static.log4j.logger.deprecation.level")
    local loggerIndexSearchSlowlogRollingLevel=$(getItemFromConf "$settings" "static.log4j.logger.index_search_slowlog_rolling.level")
    local loggerIndexIndexingSlowlogLevel=$(getItemFromConf "$settings" "static.log4j.logger.index_indexing_slowlog.level")
    local loggerTaskDetailslogRollingLevel=$(getItemFromConf "$settings" "static.log4j.logger.task_detailslog_rolling.level")
    local cleanLogsOlderThanNDays=$(getItemFromConf "$settings" "static.log4j.clean_logs_older_than_n_days")

    local cfg=$(cat<<LOG4J
status = error

# log action execution errors for easier debugging
logger.action.name = org.opensearch.action
logger.action.level = $loggerActionLevel

appender.console.type = Console
appender.console.name = console
appender.console.layout.type = PatternLayout
appender.console.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

################################################
######## Server -  old style pattern ###########
appender.rolling_old.type = RollingFile
appender.rolling_old.name = rolling_old
appender.rolling_old.fileName = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}.log
appender.rolling_old.filePermissions = rw-r-----
appender.rolling_old.layout.type = PatternLayout
appender.rolling_old.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

appender.rolling_old.filePattern = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}-%d{yyyy-MM-dd}-%i.log.gz
appender.rolling_old.policies.type = Policies
appender.rolling_old.policies.time.type = TimeBasedTriggeringPolicy
appender.rolling_old.policies.time.interval = 1
appender.rolling_old.policies.time.modulate = true
appender.rolling_old.policies.size.type = SizeBasedTriggeringPolicy
appender.rolling_old.policies.size.size = 128MB
appender.rolling_old.strategy.type = DefaultRolloverStrategy
appender.rolling_old.strategy.fileIndex = nomax
appender.rolling_old.strategy.action.type = Delete
appender.rolling_old.strategy.action.basepath = \${sys:opensearch.logs.base_path}
appender.rolling_old.strategy.action.condition.type = IfAny
appender.rolling_old.strategy.action.condition.nested_condition.type = IfAccumulatedFileSize
appender.rolling_old.strategy.action.condition.nested_condition.exceeds = 200MB
appender.rolling_old.strategy.action.condition.nested_condition.lastMod.type = IfLastModified
appender.rolling_old.strategy.action.condition.nested_condition.lastMod.age = ${cleanLogsOlderThanNDays}D
################################################

rootLogger.level = $rootLoggerLevel
rootLogger.appenderRef.console.ref = console
rootLogger.appenderRef.rolling_old.ref = rolling_old

appender.header_warning.type = HeaderWarningAppender
appender.header_warning.name = header_warning
#################################################
######## Deprecation -  old style pattern #######
appender.deprecation_rolling_old.type = RollingFile
appender.deprecation_rolling_old.name = deprecation_rolling_old
appender.deprecation_rolling_old.fileName = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_deprecation.log
appender.deprecation_rolling_old.filePermissions = rw-r-----
appender.deprecation_rolling_old.layout.type = PatternLayout
appender.deprecation_rolling_old.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

appender.deprecation_rolling_old.filePattern = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_deprecation-%i.log.gz
appender.deprecation_rolling_old.policies.type = Policies
appender.deprecation_rolling_old.policies.size.type = SizeBasedTriggeringPolicy
appender.deprecation_rolling_old.policies.size.size = 200MB
appender.deprecation_rolling_old.strategy.type = DefaultRolloverStrategy
appender.deprecation_rolling_old.strategy.max = 4
#################################################
logger.deprecation.name = org.opensearch.deprecation
logger.deprecation.level = $loggerDeprecationLevel
logger.deprecation.appenderRef.deprecation_rolling_old.ref = deprecation_rolling_old
logger.deprecation.appenderRef.header_warning.ref = header_warning
logger.deprecation.additivity = false

#################################################
######## Search Request Slowlog Log File -  old style pattern ####
appender.search_request_slowlog_log_appender.type = RollingFile
appender.search_request_slowlog_log_appender.name = search_request_slowlog_log_appender
appender.search_request_slowlog_log_appender.fileName = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_index_search_slowlog.log
appender.search_request_slowlog_log_appender.filePermissions = rw-r-----
appender.search_request_slowlog_log_appender.layout.type = PatternLayout
appender.search_request_slowlog_log_appender.layout.pattern = [%d{ISO8601}][%-5p][%c{1.}] [%node_name]%marker %m%n

appender.search_request_slowlog_log_appender.filePattern = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_index_search_slowlog-%i.log.gz
appender.search_request_slowlog_log_appender.policies.type = Policies
appender.search_request_slowlog_log_appender.policies.size.type = SizeBasedTriggeringPolicy
appender.search_request_slowlog_log_appender.policies.size.size = 200MB
appender.search_request_slowlog_log_appender.strategy.type = DefaultRolloverStrategy
appender.search_request_slowlog_log_appender.strategy.max = 4
#################################################
logger.search_request_slowlog_logger.name = cluster.search.request.slowlog
logger.search_request_slowlog_logger.level = $loggerIndexSearchSlowlogRollingLevel
logger.search_request_slowlog_logger.appenderRef.search_request_slowlog_log_appender.ref = search_request_slowlog_log_appender
logger.search_request_slowlog_logger.additivity = false

#################################################
######## Search slowlog -  old style pattern ####
appender.index_search_slowlog_rolling_old.type = RollingFile
appender.index_search_slowlog_rolling_old.name = index_search_slowlog_rolling_old
appender.index_search_slowlog_rolling_old.fileName = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_index_search_slowlog.log
appender.index_search_slowlog_rolling_old.filePermissions = rw-r-----
appender.index_search_slowlog_rolling_old.layout.type = PatternLayout
appender.index_search_slowlog_rolling_old.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

appender.index_search_slowlog_rolling_old.filePattern = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_index_search_slowlog-%i.log.gz
appender.index_search_slowlog_rolling_old.policies.type = Policies
appender.index_search_slowlog_rolling_old.policies.size.type = SizeBasedTriggeringPolicy
appender.index_search_slowlog_rolling_old.policies.size.size = 200MB
appender.index_search_slowlog_rolling_old.strategy.type = DefaultRolloverStrategy
appender.index_search_slowlog_rolling_old.strategy.max = 4
#################################################
logger.index_search_slowlog_rolling.name = index.search.slowlog
logger.index_search_slowlog_rolling.level = $loggerIndexSearchSlowlogRollingLevel
logger.index_search_slowlog_rolling.appenderRef.index_search_slowlog_rolling_old.ref = index_search_slowlog_rolling_old
logger.index_search_slowlog_rolling.additivity = false

#################################################
######## Indexing slowlog -  old style pattern ##
appender.index_indexing_slowlog_rolling_old.type = RollingFile
appender.index_indexing_slowlog_rolling_old.name = index_indexing_slowlog_rolling_old
appender.index_indexing_slowlog_rolling_old.fileName = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_index_indexing_slowlog.log
appender.index_indexing_slowlog_rolling_old.filePermissions = rw-r-----
appender.index_indexing_slowlog_rolling_old.layout.type = PatternLayout
appender.index_indexing_slowlog_rolling_old.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

appender.index_indexing_slowlog_rolling_old.filePattern = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_index_indexing_slowlog-%i.log.gz
appender.index_indexing_slowlog_rolling_old.policies.type = Policies
appender.index_indexing_slowlog_rolling_old.policies.size.type = SizeBasedTriggeringPolicy
appender.index_indexing_slowlog_rolling_old.policies.size.size = 200MB
appender.index_indexing_slowlog_rolling_old.strategy.type = DefaultRolloverStrategy
appender.index_indexing_slowlog_rolling_old.strategy.max = 4
#################################################
logger.index_indexing_slowlog.name = index.indexing.slowlog.index
logger.index_indexing_slowlog.level = $loggerIndexIndexingSlowlogLevel
logger.index_indexing_slowlog.appenderRef.index_indexing_slowlog_rolling_old.ref = index_indexing_slowlog_rolling_old
logger.index_indexing_slowlog.additivity = false

#################################################
######## Task details log -  old style pattern ####
appender.task_detailslog_rolling_old.type = RollingFile
appender.task_detailslog_rolling_old.name = task_detailslog_rolling_old
appender.task_detailslog_rolling_old.fileName = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_task_detailslog.log
appender.task_detailslog_rolling_old.filePermissions = rw-r-----
appender.task_detailslog_rolling_old.layout.type = PatternLayout
appender.task_detailslog_rolling_old.layout.pattern = [%d{ISO8601}][%-5p][%-25c{1.}] [%node_name]%marker %m%n

appender.task_detailslog_rolling_old.filePattern = \${sys:opensearch.logs.base_path}\${sys:file.separator}\${sys:opensearch.logs.cluster_name}_task_detailslog-%i.log.gz
appender.task_detailslog_rolling_old.policies.type = Policies
appender.task_detailslog_rolling_old.policies.size.type = SizeBasedTriggeringPolicy
appender.task_detailslog_rolling_old.policies.size.size = 200MB
appender.task_detailslog_rolling_old.strategy.type = DefaultRolloverStrategy
appender.task_detailslog_rolling_old.strategy.max = 4
#################################################
logger.task_detailslog_rolling.name = task.detailslog
logger.task_detailslog_rolling.level = $loggerTaskDetailslogRollingLevel
logger.task_detailslog_rolling.appenderRef.task_detailslog_rolling_old.ref = task_detailslog_rolling_old
logger.task_detailslog_rolling.additivity = false
LOG4J
    )

    echo "$cfg" > ${LOG4J2_PROPERTIES_PATH}
}

refreshIKAnalyzerCfgXml() {
    local settings=$(cat $STATIC_SETTINGS_PATH)
    local ikLocalDict=$(getItemFromConf "$settings" "static.ik.local_ext_dict")
    local ikLocalStopwords=$(getItemFromConf "$settings" "static.ik.local_ext_stopwords")
    local ikRemoteExtDict=$(getItemFromConf "$settings" "static.ik.remote_ext_dict")
    local ikRemoteExtStopwords=$(getItemFromConf "$settings" "static.ik.remote_ext_stopwords")

    local localDictStr
    if [ ! "$ikLocalDict" = "false" ]; then
        localDictStr="custom/jieba.dic;extra_main.dic"
    fi
    local remoteDictStr
    if [ -n "$ikRemoteExtDict" ]; then
        remoteDictStr="<entry key=\"remote_ext_dict\">$ikRemoteExtDict</entry>"
    fi
    local localStopStr
    if [ ! "$ikLocalStopwords" = "false" ]; then
        localStopStr="extra_stopword.dic"
    fi
    local remoteStopStr
    if [ -n "$ikRemoteExtStopwords" ]; then
        remoteStopStr="<entry key=\"remote_ext_stopwords\">$ikRemoteExtStopwords</entry>"
    fi

    local cfg=$(cat <<IKA_CONF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
    <entry key="ext_dict">$localDictStr</entry>
    <entry key="ext_stopwords">$localStopStr</entry>
    $remoteDictStr
    $remoteStopStr
</properties>
IKA_CONF
    )
    echo "$cfg" > ${IKANALYZER_CFG_XML_PATH}
}

DYNAMIC_KEY_LIST=(
    dynamic.os.cluster.no_master_block/applyClusterNoMasterBlock
    dynamic.os.action.destructive_requires_name/applyActionDestructiveRequiresName
    dynamic.os.prometheus.indices/applyPrometheusIndices
    dynamic.os.prometheus.cluster.settings/applyPrometheusClusterSettings
    dynamic.os.prometheus.nodes.filter/applyPrometheusNodesFilter
    dynamic.os.cluster.routing.allocation.enable/applyClusterRoutingAllocationEnable
)

applyClusterNoMasterBlock() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local clusterNoMasterBlock=$(getItemFromConf "$settings" "dynamic.os.cluster.no_master_block")
    if [ -z "$clusterNoMasterBlock" ]; then
        resetClusterSettings "cluster.no_master_block" $@
    else
        updateClusterSettings "cluster.no_master_block" \"$clusterNoMasterBlock\" $@
    fi
}

applyActionDestructiveRequiresName() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local actionDestructiveRequiresName=$(getItemFromConf "$settings" "dynamic.os.action.destructive_requires_name")
    if [ -z "$actionDestructiveRequiresName" ]; then
        resetClusterSettings "action.destructive_requires_name" $@
    else
        updateClusterSettings "action.destructive_requires_name" $actionDestructiveRequiresName $@
    fi
}

applyPrometheusIndices() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local prometheusIndices=$(getItemFromConf "$settings" "dynamic.os.prometheus.indices")
    if [ -z "$prometheusIndices" ]; then
        resetClusterSettings "prometheus.indices" $@
    else
        updateClusterSettings "prometheus.indices" $prometheusIndices $@
    fi
}

applyPrometheusClusterSettings() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local prometheusClusterSettings=$(getItemFromConf "$settings" "dynamic.os.prometheus.cluster.settings")
    if [ -z "$prometheusClusterSettings" ]; then
        resetClusterSettings "prometheus.cluster.settings" $@
    else
        updateClusterSettings "prometheus.cluster.settings" $prometheusClusterSettings $@
    fi
}

applyPrometheusNodesFilter() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local prometheusNodesFilter=$(getItemFromConf "$settings" "dynamic.os.prometheus.nodes.filter")
    if [ -z "$prometheusNodesFilter" ]; then
        resetClusterSettings "prometheus.nodes.filter" $@
    else
        updateClusterSettings "prometheus.nodes.filter" \"$prometheusNodesFilter\" $@
    fi
}

applyClusterRoutingAllocationEnable() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local clusterRoutingAllocationEnable=$(getItemFromConf "$settings" "dynamic.os.cluster.routing.allocation.enable")
    if [ -z "$clusterRoutingAllocationEnable" ]; then
        resetClusterSettings "cluster.routing.allocation.enable" $@
    else
        updateClusterSettings "cluster.routing.allocation.enable" \"$clusterRoutingAllocationEnable\" $@
    fi
}

# for maintainers
applyClusterRANCR() {
    if [ "$#" -eq 0 ]; then
        resetClusterSettings "cluster.routing.allocation.node_concurrent_recoveries"
    else
        updateClusterSettings "cluster.routing.allocation.node_concurrent_recoveries" $1
    fi
}

# $1 option, <ip> or $MY_IP
applyAllDynamicSettings() {
    local item
    local key
    local func
    local res
    for item in ${DYNAMIC_KEY_LIST[@]}; do
        key=${item%/*}
        func=${item#*/}
        log "update dynamic setting: ${key#dynamic.os.}"
        eval "$func \$@ || :"
    done
}

# $1: diff command result
# $2 option <ip> or $MY_IP
applyChangedDynamicSettings() {
    local settings="$1"
    shift
    local item
    local key
    local func
    local res
    for item in ${DYNAMIC_KEY_LIST[@]}; do
        key=${item%/*}
        func=${item#*/}
        res=$(echo "$settings" | sed -n "/$key/p")
        if [ -n "$res" ]; then
            log "update dynamic setting: ${key#dynamic.os.}"
            eval "$func \$@ || :"
        fi
    done
}

# $1 - key
# $2 - value
addOrUpdateKeystore() {
    local tmpstr=$2
    tmpstr=${tmpstr//\\/\\\\}
    tmpstr=${tmpstr//\$/\\\$}
    runuser opensearch -g svc -s "/bin/bash" -c "echo -n $tmpstr | OPENSEARCH_PATH_CONF=$OPENSEARCH_PATH_CONF $KEYSTORE_TOOL_PATH add -f $1 --stdin"
}

# $1 - key
removeFromKeystore() {
    runuser opensearch -g svc -s "/bin/bash" -c "OPENSEARCH_PATH_CONF=$OPENSEARCH_PATH_CONF $KEYSTORE_TOOL_PATH remove $1 | :"
}

listKeystore() {
    runuser opensearch -g svc -s "/bin/bash" -c "OPENSEARCH_PATH_CONF=$OPENSEARCH_PATH_CONF $KEYSTORE_TOOL_PATH list"
}

applyAllKeystoreSettings() {
    local rawline
    local k
    local v
    while read -r rawline; do
        tmpstr=${rawline#*/}
        if [ -z "$tmpstr" ]; then
            continue
        fi
        k=${tmpstr%%=*}
        v=${tmpstr#*=}
        log "add or update keysore: $k"
        addOrUpdateKeystore "$k" "$v"
    done <"$KEYSTORE_SETTINGS_PATH"
}

applyChangedKeystoreSettings() {
    local origin=$(echo "$1" | sed -n "/^</p")
    local rawline
    local newline
    local linesel
    local tmpstr
    local oldk
    local oldv
    local newk
    local newv
    while read -r rawline; do
        tmpstr=${rawline%%/*}
        linesel=${tmpstr#< }
        tmpstr=${rawline#*/}
        if [ -n "$tmpstr" ]; then
            oldk=${tmpstr%%=*}
            oldv=${tmpstr#*=}
        else
            oldk=""
            oldv=""
        fi
        newline=$(echo "$1" | sed -n "/^> $linesel/p")
        tmpstr=${newline#*/}
        if [ -n "$tmpstr" ]; then
            newk=${tmpstr%%=*}
            newv=${tmpstr#*=}
        else
            newk=""
            newv=""
        fi
        if [ -z "$oldk" ] || [ "$oldk" = "$newk" ]; then
            log "add or update keysore: $newk"
            addOrUpdateKeystore "$newk" "$newv"
        elif [ -z "$newk" ]; then
            log "remove from keystore: $oldk"
            removeFromKeystore "$oldk"
        else
            log "remove from keystore: $oldk"
            removeFromKeystore "$oldk"
            log "add or update keystore: $newk"
            addOrUpdateKeystore "$newk" "$newv"
        fi
    done <<<"$origin"
}

# $1 - cert path
isCertValid() {
    openssl x509 -in $1 -text -noout
}

refreshAllCerts() {
    cat $CERT_OS_USER_CA_PATH > $OPENSEARCH_CONF_USER_CERTS_PATH/root-ca.pem
    cat $CERT_OS_USER_NODE_CERT_PATH > $OPENSEARCH_CONF_USER_CERTS_PATH/node1.pem
    cat $CERT_OS_USER_NODE_KEY_PATH > $OPENSEARCH_CONF_USER_CERTS_PATH/node1-key.pem
}

refreshAllDynamicServiceStatus() {
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local enable_caddy=$(getItemFromConf "$settings" "dynamic.other.enable_caddy")
    if [ "$enable_caddy" = "true" ]; then
        systemctl start caddy
    else
        systemctl stop caddy
    fi
    local enable_exporter=$(getItemFromConf "$settings" "dynamic.other.enable_exporter")
    if [ "$enable_exporter" = "true" ]; then
        systemctl start node_exporter
    else
        systemctl stop node_exporter
    fi
}

# $1 service name
refreshDynamicService() {
    if [ ! -e $DYNAMIC_SETTINGS_PATH ]; then
        log "cluster is booting up, do nothing!"
        return
    fi
    local settings=$(cat $DYNAMIC_SETTINGS_PATH)
    local curstatus
    case "$1" in
        "caddy")
        curstatus=$(getItemFromConf "$settings" "dynamic.other.enable_caddy")
        ;;
        "node_exporter")
        curstatus=$(getItemFromConf "$settings" "dynamic.other.enable_exporter")
        ;;
        *)
        curstatus=""
        ;;
    esac
    if [ -z "$curstatus" ]; then
        log "unknown service, skipping!"
        return
    fi
    if [ "$curstatus" = "true" ]; then
        log "restart service: $1"
        systemctl restart $1 || :
    else
        log "the $1 service is disabled, stop it!"
        systemctl stop $1 || :
    fi
}

DYNAMIC_SERVICE_LIST=(
    dynamic.other.enable_caddy/caddy
    dynamic.other.enable_exporter/node_exporter
)

refreshChangedDynamicService() {
    local settings="$1"
    shift
    local item
    local key
    local service
    local res
    for item in ${DYNAMIC_SERVICE_LIST[@]}; do
        key=${item%/*}
        service=${item#*/}
        res=$(echo "$settings" | sed -n "/$key/p")
        if [ -n "$res" ]; then
            log "refresh dynamic service: $service"
            refreshDynamicService $service
        fi
    done
}