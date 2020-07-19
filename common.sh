#!/bin/bash
# vim: ts=4 sw=4 sts=4 et:

# variables and functions used by the other setup scripts

dotcms_version=5.3.3
tomcat_version=8.5.32
elasticsearch_version=7.3.2
docker_compose_version=1.26.2

app_user=dotcms
app_user_uid=10000
app_dir=/home/${app_user}/app
nfs_dir=/opt/dotcms/data/assets

dotcms_ip=172.31.37.72
dotcms_ip=127.0.0.1
nfs_ip=172.31.60.88
nfs_ip=127.0.0.1
postgres_ip=172.31.53.58
postgres_ip=127.0.0.1

app_servername=dotcms.scheduleomatic.com

postgres_db=dotcms
postgres_username=dotcms
postgres_password=ADqtarsalgiaMtumplineTamf3TntNF8
postgres_superuser_password=tMegallinazoacedreE4RHMF6RMqJgd4

elasticsearch_superuser_password=mR6antifoamingMJaquesianJhFmTJJ2

# create us user for dotcms
elasticsearch_user=admin
elasticsearch_password=admin

nginx_root=/usr/share/nginx

dotcms_download_url=http://static.dotcms.com/versions/dotcms_${dotcms_version}.tar.gz

#### common functions ####

print_funcname () {
    echo 
    if [ ${FUNCNAME[1]} ]
    then
        echo "  === ${FUNCNAME[1]} () === "
    else
        echo "  === ${FUNCNAME[0]} () === "
    fi
}

# TODO: wrangle SElinux :-/
selinux_permissive () {
    print_funcname
    setenforce 0
    sed -i'' 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    echo "getenforce:"
    getenforce
}

create_app_user () {
    print_funcname
    useradd --uid=$app_user_uid $app_user
}

docker_install () {
    print_funcname
    yum upate -y
    amazon-linux-extras install -y docker	
    systemctl enable --now docker
    usermod -a -G docker $app_user
    # and docker-compose
    if [ ! -x /usr/local/bin/docker-compose ]
    then
        sudo curl -L \
            https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-`uname -s`-`uname -m` \
            -o /usr/local/bin/docker-compose
        chmod 755 /usr/local/bin/docker-compose
    fi
}

