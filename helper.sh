# Load this helper scripts by `source ./helper.sh`.
# Management 'username/password' is all 'admin/RedHat1!'.

# Set your Keycloak server home
export SSO_HOME=/home/onagano/work/isetan_sso/keycloak-4.8.3.Final

# Set less -Xmx if needed
export JAVA_OPTS="-Xmx256m -Djava.net.preferIPv4Stack=true -Djboss.modules.system.pkgs=org.jboss.byteman -Djava.awt.headless=true"


# Listen port 8080
function start-sso() {
    ${SSO_HOME}/bin/standalone.sh \
    -Djboss.server.base.dir=./standalone.sso \
    -b 0.0.0.0 \
    $@
}

# Listen port 8080
function start-domain-sso() {
    ${SSO_HOME}/bin/domain.sh \
    -Djboss.domain.base.dir=./domain.sso \
    -b 0.0.0.0 \
    $@
}

# Management port: 9990
function sso-cli() {
    ${SSO_HOME}/bin/jboss-cli.sh -c "$@"
}


# Listen port 9080 = 8080 + 1000
function start-api() {
    ${SSO_HOME}/bin/standalone.sh \
    -Djboss.server.base.dir=./standalone.api \
    -b 0.0.0.0 \
    -Djboss.socket.binding.port-offset=1000 \
    $@
}

# Management port: 10990 = 9990 + 1000
function api-cli() {
    ${SSO_HOME}/bin/jboss-cli.sh --controller=localhost:10990 -c "$@"
}


# Listen port 9180 = 8080 + 1100
function start-web() {
    ${SSO_HOME}/bin/standalone.sh \
    -Djboss.server.base.dir=./standalone.web \
    -b 0.0.0.0 \
    -Djboss.socket.binding.port-offset=1100 \
    $@
}

# Management port: 11090 = 9990 + 1100
function web-cli() {
    ${SSO_HOME}/bin/jboss-cli.sh --controller=localhost:11090 -c "$@"
}


# Build and deploy service-jee-jaxrs
function deploy-api() {
    (
        cd service-jee-jaxrs
        mvn -Denforcer.skip=true clean package
        cp target/service.war ../standalone.api/deployments/
    )
}

# Build and deploy app-jee-jsp
function deploy-web() {
    (
        cd app-jee-jsp
        mvn -Denforcer.skip=true clean package
        cp target/app-jsp.war ../standalone.web/deployments/
    )
}


# Enable and disable HTTP access log

# CMD_1 はroload（再起動）が必要で、初回のみでいい。
ENABLE_ACCESS_LOG_CMD_1='/subsystem=undertow/server=default-server/http-listener=default:write-attribute(name=record-request-start-time,value=true)'
ENABLE_ACCESS_LOG_CMD_2='/subsystem=undertow/server=default-server/host=default-host/setting=access-log:add(pattern="%h %l %u %t \"%r\" %s %b \"%{i,Referer}\" \"%{i,User-Agent}\" Cookie: \"%{i,COOKIE}\" Set-Cookie: \"%{o,SET-COOKIE}\" SessionID: %S Thread: \"%I\" TimeTaken: %T")'
DISABLE_ACCESS_LOG_CMD='/subsystem=undertow/server=default-server/host=default-host/setting=access-log:remove'

fundtion sso-enable-access-log() {
    #sso-cli "$ENABLE_ACCESS_LOG_CMD_1"
    sso-cli "$ENABLE_ACCESS_LOG_CMD_2"
}

fundtion sso-disable-access-log() {
    sso-cli "$DISABLE_ACCESS_LOG_CMD"
}

fundtion api-enable-access-log() {
    #api-cli "$ENABLE_ACCESS_LOG_CMD_1"
    api-cli "$ENABLE_ACCESS_LOG_CMD_2"
}

fundtion api-disable-access-log() {
    api-cli "$DISABLE_ACCESS_LOG_CMD"
}

fundtion web-enable-access-log() {
    #web-cli "$ENABLE_ACCESS_LOG_CMD_1"
    web-cli "$ENABLE_ACCESS_LOG_CMD_2"
}

fundtion web-disable-access-log() {
    web-cli "$DISABLE_ACCESS_LOG_CMD"
}


# Enable and disable request dumper

ENABLE_REQUEST_DUMPER_CMD_1='/subsystem=undertow/configuration=filter/expression-filter=requestDumperExpression:add(expression="dump-request")'
ENABLE_REQUEST_DUMPER_CMD_2='/subsystem=undertow/server=default-server/host=default-host/filter-ref=requestDumperExpression:add'
DISABLE_REQUEST_DUMPER_CMD_1='/subsystem=undertow/server=default-server/host=default-host/filter-ref=requestDumperExpression:remove'
DISABLE_REQUEST_DUMPER_CMD_2='/subsystem=undertow/configuration=filter/expression-filter=requestDumperExpression:remove'

fundtion sso-enable-request-dumper() {
    sso-cli "$ENABLE_REQUEST_DUMPER_CMD_1"
    sso-cli "$ENABLE_REQUEST_DUMPER_CMD_2"
}

fundtion sso-disable-request-dumper() {
    sso-cli "$DISABLE_REQUEST_DUMPER_CMD_1"
    sso-cli "$DISABLE_REQUEST_DUMPER_CMD_2"
}

fundtion api-enable-request-dumper() {
    api-cli "$ENABLE_REQUEST_DUMPER_CMD_1"
    api-cli "$ENABLE_REQUEST_DUMPER_CMD_2"
}

fundtion api-disable-request-dumper() {
    api-cli "$DISABLE_REQUEST_DUMPER_CMD_1"
    api-cli "$DISABLE_REQUEST_DUMPER_CMD_2"
}

fundtion web-enable-request-dumper() {
    web-cli "$ENABLE_REQUEST_DUMPER_CMD_1"
    web-cli "$ENABLE_REQUEST_DUMPER_CMD_2"
}

fundtion web-disable-request-dumper() {
    web-cli "$DISABLE_REQUEST_DUMPER_CMD_1"
    web-cli "$DISABLE_REQUEST_DUMPER_CMD_2"
}
