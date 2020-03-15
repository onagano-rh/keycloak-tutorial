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


