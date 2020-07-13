#!/bin/sh

# dotcms server
app_user=dotcms
app_user_uid=10000
remote_dir=/home/${app_user}/export

nfs_server=192.168.166.199

print_func () {
    echo 
    echo "  === ${FUNCNAME[1]} () === "
}

# disable SElinux for now
selinux_permissive () {
    print_func
    setenforce 0
    sed -i'' 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    echo "getenforce:"
    getenforce
}

install_packages () {
    print_func
    yum install -y  epel-release
    yum install -y fail2ban
    yum install -y rpcbind nfs-utils nfs4-acl-tools
    systemctl enable --now fail2ban rpcbind nfs-idmapd
}

create_app_user () {
    print_func
    useradd --uid=${app_user_uid} ${app_user}
    mkdir -p /mnt/home/${app_user}
    chown ${app_user}:${app_user} /mnt/home/${app_user}
    su -c "mkdir -p ${remote_dir}" ${app_user}
    su -c "cd && ln -fs /mnt/home${remote_dir}" ${app_user}
}

mount_nfs () {
    print_func
    local_dir=/mnt${remote_dir}
    if ( ! egrep -q "^[0-9\.]+:${remote_dir}\s" /etc/fstab )
    then	
        echo "${nfs_server}:${remote_dir}  ${local_dir}  nfs  rw,sync,hard,intr,noatime 0 0" >> /etc/fstab
    fi 
    mount $local_dir
}

selinux_permissive
install_packages
create_app_user
mount_nfs
