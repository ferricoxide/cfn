#!/bin/sh
#
# Description:
#    This script is intended to aid an administrator in quickly
#    setting up a baseline configuration of the Guacamole
#    management-protocol HTTP-tunneling service. When the script
#    exits successfully:
#    * The Tomcat7 servlet-service will have been downloaded and
#      enabled
#    * The Guacamole service will have been configured to tunnel
#      SSH based connections to the Guacamole host to a remote,
#      HTML 5 compliant web browser.
#    * Apache 2.4 will have been configured to provide a proxy of
#      all public-facing port 80/tcp traffic to the Guacamole
#      servlet listening at localhost port 8080/tcp
#
#################################################################
__ScriptName="make-guac.sh"
__GuacVersion="0.9.7"

log()
{
    logger -i -t "${__ScriptName}" -s -- "$1" 2> /dev/console
    echo "$1"
}  # ----------  end of function log  ----------


die()
{
    [ -n "$1" ] && log "$1"
    log "Guacamole install failed"'!'
    exit 1
}  # ----------  end of function die  ----------


__md5sum()
{
    local pass="${1}"
    echo -n "${pass}" | /usr/bin/md5sum - | cut -d ' ' -f 1
}  # ----------  end of function md5sum  ----------


usage()
{
    cat << EOT
  Usage:  ${__ScriptName} [options]
  
  Note:
  If no options are specified, then Guacamole v${__GuacVersion} will be
  installed, but it will not be configured and users will not be able to
  authenticate. Specify -H (and associated options) to configure LDAP 
  authentication. Specify -G (and associated options) to configure file-based
  authentication.

  Options:
  -h  Display this message.
  -H  Hostname of the LDAP server to authenticate users against 
      (e.g. ldap.example.com). Using the domain DNS name is acceptable as long
      as it resolves to an LDAP server (e.g. example.com). If specified, LDAP
      authentication will be installed and configured. Requires -D.
  -D  Distinguished Name (DN) of the directory (e.g. DN=example,DN=com).
      Required by -H.
  -U  The base of the DN for all Guacamole users. This is prepended to the
      directory DN (-D) to create the full DN to the user container. This will
      be appended to the username when a user logs in. Default is "CN=Users".
  -A  The attribute which contains the username and which is part of the DN
      for all Guacamole users. Usually, this will be "uid" or "cn". This is
      used together with the user base DN (-U) to derive the full DN of each
      user logging in. Default is "cn".
  -C  The base of the DN for all Guacamole configurations. Each configuration
      is analogous to a connection. This is prepended to the directory DN (-D)
      to create the full DN to the configuration container. Default is 
      "CN=GuacConfigGroups". NOTE: This default value does not exist by
      default in the LDAP directory and will need to be created, or a
      different value will need to be provided.
  -P  Port on which to connect to the LDAP server. Default is "389".
  -v  Version of Guacamole to build, install, and configure.
      Default is "${__GuacVersion}".
  -G  A username authorized to use the Guacamole service that will be
      authenticated using the basic file authentication provider.
  -g  Password for the Guacamole user (-G). If -G is provided, then this
      parameter is required.
  -S  An Operating System (OS) username that will be created and allowed to
      login via SSH. This parameter is only valid if -G is specified, as well.
      If this parameter is not provided but -G is, then the -G username will
      be used for the OS user.
  -s  Password for the OS user (-S). If -S is specified, then this parameter
      is required.
EOT
}  # ----------  end of function usage  ----------


# Define default values
LDAP_HOSTNAME=
LDAP_DOMAIN_DN=
LDAP_USER_BASE="CN=Users"
LDAP_USER_ATTRIBUTE="cn"
LDAP_CONFIG_BASE="CN=GuacConfigGroups"
LDAP_PORT="389"
GUAC_VERSION="${__GuacVersion}"
GUAC_USERNAME=
GUAC_PASSWORD=
SSH_USERNAME=
SSH_PASSWORD=


# Parse command-line parameters
while getopts :hH:D:U:A:C:P:v:G:g:S:s: opt
do
    case "${opt}" in
        h)
            usage
            exit 0
            ;;
        H)
            LDAP_HOSTNAME="${OPTARG}"
            ;;
        D)
            LDAP_DOMAIN_DN="${OPTARG}"
            ;;
        U)
            LDAP_USER_BASE="${OPTARG}"
            ;;
        A)
            LDAP_USER_ATTRIBUTE="${OPTARG}"
            ;;
        C)
            LDAP_CONFIG_BASE="${OPTARG}"
            ;;
        P)
            LDAP_PORT="${OPTARG}"
            ;;
        v)
            GUAC_VERSION="${OPTARG}"
            ;;
        G)
            GUAC_USERNAME="${OPTARG}"
            ;;
        g)
            GUAC_PASSWORD="${OPTARG}"
            ;;
        S)
            SSH_USERNAME="${OPTARG}"
            ;;
        s)
            SSH_PASSWORD="${OPTARG}"
            ;;
        \?)
            usage
            echo "ERROR: unknown parameter \"$OPTARG\""
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))


# Validate parameters
if [ -n "${LDAP_HOSTNAME}" ]
then
    if [ -z "${LDAP_DOMAIN_DN}" ]
    then
        die "LDAP Hostname was provided (-H), but the LDAP Domain DN was not (-D)"
    fi
elif [ -n "${LDAP_DOMAIN_DN}" ]
then
    die "LDAP Domain DN was provided (-D), but the LDAP Hostname was not (-H)"
fi

if [ -n "${GUAC_USERNAME}" ]
then
    if [ -z "${GUAC_PASSWORD}" ]
    then
        die "Guacamole username was provided (-G), but the password was not (-s)"
    fi
    if [ -z "{SSH_USERNAME}" ]
    then
        SSH_USERNAME="${GUAC_USERNAME}"
        SSH_PASSWORD="${GUAC_PASSWORD}"
    fi
fi


# Set internal variables
PWCRYPT=$( python -c "import random,string,crypt,getpass,pwd; \
           randomsalt = ''.join(random.sample(string.ascii_letters,8)); \
           print crypt.crypt('${SSH_PASSWORD}', '\$6\$%s))\$' % randomsalt)" )
GUACPASS_MD5=$(__md5sum "${GUAC_PASSWORD}")
GUAC_SOURCE="http://sourceforge.net/projects/guacamole/files/current/source"
GUAC_BINARY="http://sourceforge.net/projects/guacamole/files/current/binary"
GUAC_EXTENSIONS="http://sourceforge.net/projects/guacamole/files/current/extensions"
ADDUSER="/usr/sbin/useradd"
MODUSER="/usr/sbin/usermod"


# Start the real work
log "Installing EPEL repo"
yum -y install \
    http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

log "Ensuring the CentOS Base repo is available"
curl -s -L "https://raw.githubusercontent.com/lorengordon/cfn/master/scripts/CentOS-Base.repo" \
    -o "/etc/yum.repos.d/CentOS-Base.repo"

curl -s -L "https://raw.githubusercontent.com/lorengordon/cfn/master/scripts/RPM-GPG-KEY-CentOS-6" \
    -o "/etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6"

log "Enabling the EPEL and base repos"
yum-config-manager --enable epel base

log "Installing OS standard Tomcat and Apache"
yum install -y httpd24 tomcat7

log "Installing libraries to build guacamole from source"
yum -y install gcc cairo-devel libjpeg-turbo-devel libjpeg-devel libpng-devel \
    uuid-devel freerdp-devel pango-devel libssh2-devel pulseaudio-libs-devel \
    openssl-devel libvorbis-devel dejavu-sans-mono-fonts freerdp-plugins

# Build guacamole-server
cd /root
GUAC_FILEBASE="guacamole-server-${GUAC_VERSION}"
log "Downloading and extracting ${GUAC_FILEBASE}.tar.gz"
(curl -s -L "${GUAC_SOURCE}/${GUAC_FILEBASE}.tar.gz/download" | tar -xzv) || \
    die "Could not download and extract ${GUAC_FILEBASE}.tar.gz"

cd "${GUAC_FILEBASE}"
log "Building ${GUAC_FILEBASE} from source"
./configure --with-init-dir=/etc/init.d
make
make install

log "Enabling services to start at next boot"
for SVC in httpd tomcat7 guacd
do
    chkconfig ${SVC} on
done

# Create guacamole directories as necessary
for GUAC_DIR in "/etc/guacamole" "/etc/guacamole/extensions" "/etc/guacamole/lib"
do
    if [[ ! -d "${GUAC_DIR}" ]]
    then
        log "Creating ${GUAC_DIR} directory"
        if [[ $(mkdir -p "${GUAC_DIR}")$? -ne 0 ]]
        then
            die "Cannot populate ${GUAC_DIR}"
        fi
    fi
done


# Install the Guacamole client
log "Downloading Guacamole client from project repo"
curl -s -L ${GUAC_BINARY}/guacamole-${GUAC_VERSION}.war/download \
    -o /var/lib/tomcat7/webapps/guacamole.war


# Gotta make SELinux happy...
if [[ $(getenforce) = "Enforcing" ]] || [[ $(getenforce) = "Permissive" ]]
then
    chcon -R --reference=/var/lib/tomcat7/webapps \
        /var/lib/tomcat7/webapps/guacamole.war
    if [[ $(getsebool httpd_can_network_relay | \
        cut -d ">" -f 2 | sed 's/[ ]*//g') = "off" ]]
    then
        log "Enabling httpd-based proxying within SELinux"
        setsebool -P httpd_can_network_relay=1
    fi
fi


# Create basic config files in /etc/guacamole
cd /etc/guacamole
log "Writing /etc/guacamole/guacamole.properties"
(
    echo "# Hostname and port of guacamole proxy"
    echo "guacd-hostname: localhost"
    echo "guacd-port:     4822"
) > /etc/guacamole/guacamole.properties
log "Writing /etc/guacamole/logback.xml"
(
    printf "<configuration>\n"
    printf "\n"
    printf "\t<!-- Appender for debugging -->\n"
    printf "\t<appender name=\"GUAC-DEBUG\" class=\"ch.qos.logback.core.FileAppender\">\n"
    printf "\t\t<file>/var/log/tomcat7/guacamole.log</file>\n"
    printf "\t\t<encoder>\n"
    printf "\t\t\t<pattern>%%d{HH:mm:ss.SSS} [%%thread] %%-5level %%logger{36} - %%msg%%n</pattern>\n"
    printf "\t\t</encoder>\n"
    printf "\t</appender>\n"
    printf "\n"
    printf "\t<!-- Log at DEBUG level -->\n"
    printf "\t<root level=\"debug\">\n"
    printf "\t\t<appender-ref ref=\"GUAC-DEBUG\"/>\n"
    printf "\t</root>\n"
    printf "\n"
    printf "</configuration>\n"
) > /etc/guacamole/logback.xml


if [ -n "${GUAC_USERNAME}" ]
then
    log "Create the SSH login-user [${SSH_USERNAME}"
    getent passwd ${SSH_USERNAME} > /dev/null
    if [[ $? -eq 0 ]]
    then
        log "User account already exists [${SSH_USERNAME}]."
    elif [[ $(${ADDUSER} ${SSH_USERNAME})$? -ne 0 ]]
    then
        die "Failed to create ssh user account [${SSH_USERNAME}]. Aborting..."
    fi

    log "Set the password for the SSH login-user"
    if  [[ $(${MODUSER} -p "${PWCRYPT}" ${SSH_USERNAME}) -ne 0 ]]
    then
        die "Failed to set password for ssh user account. Aborting..."
    fi

    log "Adding the SSH login-user to sudoers list"
    printf "${SSH_USERNAME}\tALL=(root)\tNOPASSWD:ALL\n" > \
        /etc/sudoers.d/user_${SSH_USERNAME}
    if [[ $? -ne 0 ]]
    then
        die "Failed to add ${SSH_USERNAME} to sudoers."
    fi

    log "Adding the basic user mapping setting to guacamole.properties"
    (
        echo ""
        echo "# Properties used by BasicFileAuthenticationProvider"
        echo "basic-user-mapping: /etc/guacamole/user-mapping.xml"
    ) >> /etc/guacamole/guacamole.properties

    log "Writing /etc/guacamole/user-mapping.xml"
    (
        printf "<user-mapping>\n"
        printf "\t<!-- Per-user authentication and config information -->\n"
        printf "\t<authorize username=\"%s\" password=\"%s\" encoding=\"%s\">\n" "${GUAC_USERNAME}" "${GUACPASS_MD5}" "md5"
        printf "\t\t<protocol>ssh</protocol>\n"
        printf "\t\t\t<param name=\"hostname\">localhost</param>\n"
        printf "\t\t\t<param name=\"port\">22</param>\n"
        printf "\t\t\t<param name=\"font-name\">DejaVu Sans Mono</param>\n"
        printf "\t\t\t<param name=\"font-size\">10</param>\n"
        printf "\t</authorize>\n"
        printf "</user-mapping>\n"
    ) > /etc/guacamole/user-mapping.xml
fi

if [ -n "${LDAP_HOSTNAME}" ]
then

    # Install the Guacamole LDAP auth extension
    log "Downloading Guacmole ldap extension"
    GUAC_LDAP="guacamole-auth-ldap-${GUAC_VERSION}"
    curl -s -L "${GUAC_EXTENSIONS}/${GUAC_LDAP}.tar.gz/download" \
        -o "/root/${GUAC_LDAP}.tar.gz" || \
        die "Could not download ldap extension"

    log "Extracing Guacamole ldap extension"
    cd /root
    tar -xvf "${GUAC_LDAP}.tar.gz" || \
        die "Could not extract Guacamole ldap plugin"

    log "Installing Guacamole ldap .jar file in the extensions directory"
    # Can only have one extension at a time, so ensure the directory is empty
    rm -rf "/etc/guacamole/extensions/*"
    cp "${GUAC_LDAP}/${GUAC_LDAP}.jar" "/etc/guacamole/extensions"

    log "Adding the LDAP auth settings to guacamole.properties"
    (
        echo ""
        echo "# Properties used by the LDAP Authentication plugin"
        echo "ldap-hostname:           ${LDAP_HOSTNAME}"
        echo "ldap-port:               ${LDAP_PORT}"
        echo "ldap-user-base-dn:       ${LDAP_USER_BASE},${LDAP_DOMAIN_DN}"
        echo "ldap-username-attribute: ${LDAP_USER_ATTRIBUTE}"
        echo "ldap-config-base-dn:     ${LDAP_CONFIG_BASE},${LDAP_DOMAIN_DN}"
    ) >> /etc/guacamole/guacamole.properties
fi


log "Creating shell-init profile files"
echo "export GUACAMOLE_HOME=/etc/guacamole" > /etc/profile.d/guacamole.sh
echo "setenv GUACAMOLE_HOME /etc/guacamole" > /etc/profile.d/guacamole.csh


log "Setting SEL contexts on shell-init files"
chcon system_u:object_r:bin_t:s0 /etc/profile.d/guacamole.*


log "Adding a proxy-directive to Apache, /etc/httpd/conf.d/Guacamole-proxy.conf"
(
    printf "<Location />\n"
    printf "\tOrder allow,deny\n"
    printf "\tAllow from all\n"
    printf "\tProxyPass http://localhost:8080/guacamole/"
    printf " flushpackets=on\n"
    printf "\tProxyPassReverse http://localhost:8080/guacamole/\n"
    printf "\tProxyPassReverseCookiePath /guacamole/ /\n"
    printf "</Location>\n"
    printf "\n"
    printf "<Location /guacamole/>\n"
    printf "\tOrder allow,deny\n"
    printf "\tAllow from all\n"
    printf "\tProxyPass http://localhost:8080/guacamole/"
    printf " flushpackets=on\n"
    printf "\tProxyPassReverse http://localhost:8080/guacamole/\n"
    printf "\tProxyPassReverseCookiePath /guacamole/ /guacamole/\n"
    printf "</Location>\n"
    printf "\n"
    printf "<Location /guacamole/websocket-tunnel>\n"
    printf "\tOrder allow,deny\n"
    printf "\tAllow from all\n"
    printf "\tProxyPass ws://localhost:8080//guacamole/websocket-tunnel\n"
    printf "\tProxyPassReverse ws://localhost:8080//guacamole/websocket-tunnel\n"
    printf "</Location>\n"
) > /etc/httpd/conf.d/Guacamole-proxy.conf


log "Link guacamole to /etc/guacamole"
if [[ ! -d /usr/share/tomcat7/.guacamole ]]
then
    mkdir /usr/share/tomcat7/.guacamole
fi
cd /usr/share/tomcat7/.guacamole
for FILE in /etc/guacamole/*
do
    ln -sf ${FILE}
done


log "Ensuring freerdp plugins are linked properly"
if [[ ! -d /usr/lib64/freerdp ]]
then
    mkdir /usr/lib64/freerdp
fi
cd /usr/lib64/freerdp
for FILE in /usr/local/lib/freerdp/*
do
    ln -sf ${FILE}
done


log "Creating directory for file transfers"
if [[ ! -d /var/tmp/guacamole ]]
then
    mkdir /var/tmp/guacamole
fi


# Start services
log "Attempting to start proxy-related services"
for SVC in guacd tomcat7 httpd
do
    log "Stopping and starting ${SVC}"
    /sbin/service ${SVC} stop && /sbin/service ${SVC} start
    if [[ $? -ne 0 ]]
    then
      die "Failed to start ${SVC}."
    fi
done
