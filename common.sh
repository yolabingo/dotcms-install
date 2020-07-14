#!/bin/sh
# vim: ts=4 sw=4 sts=4 et:

# variables and functions used by the other setup scripts

app_user=dotcms
app_user_uid=10000
app_dir=/home/${app_user}/app
nfs_dir=/opt/dotcms/data/assets

dotcms_ip=192.168.175.140
nfs_ip=192.168.189.9
postgres_ip=192.168.226.80

app_servername=dotcms.discodecline.com

postgres_db=dotcms
postgres_username=dotcms
postgres_password="bjinjili3thrammleeTtqr87d"

nginx_root=/usr/share/nginx

dotcms_download=http://static.dotcms.com/versions/dotcms_5.3.3.tar.gz

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

