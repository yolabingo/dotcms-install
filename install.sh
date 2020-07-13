#!/bin/sh

# simple NFS server 

app_user=dotcms
app_user_uid=10000
nfs_dir=/opt/dotcms/data/assets

dotcms_ip=192.168.175.140
nfs_ip=192.168.189.9
postgres_ip=192.168.226.80

# local 192.168 address of this machine
local_ip=$( ip -o addr | grep "192.168" | awk '{print $4}' | sed 's,/.*,,' )

#### common functions ####

print_func () {
    echo 
    if [ ${FUNCNAME[1]} ]
    then
        echo "  === ${FUNCNAME[1]} () === "
    else
        echo "  === ${FUNCNAME[0]} () === "
    fi
}

# disable SElinux for now
selinux_permissive () {
    print_func
    setenforce 0
    sed -i'' 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    echo "getenforce:"
    getenforce
}

create_app_user () {
    print_func
    useradd --uid=$app_user_uid $app_user
}

#### NFS server setup ####

install_packages () {
    print_func
    yum install -y  epel-release
    yum install -y fail2ban
    yum install -y portmap nfs-utils nfs4-acl-tools
    systemctl enable --now fail2ban
    systemctl enable --now nfs-server.service
}

# add client IPs and NFS service to "internal" 
set_firewall () {
    print_func
    zone=internal
    firewall-cmd --zone=$zone --add-source=$dotcms_ip
    firewall-cmd --permanent --zone=$zone --add-source=$dotcms_ip 
    firewall-cmd --permanent --zone=$zone --add-port=111/tcp
    firewall-cmd --permanent --zone=$zone --add-service=nfs
    # firewall-cmd --permanent --zone=$zone --add-port=54302/tcp
    # firewall-cmd --permanent --zone=$zone --add-port=20048/tcp
    # firewall-cmd --permanent --zone=$zone --add-port=46666/tcp
    # firewall-cmd --permanent --zone=$zone --add-port=42955/tcp
    # firewall-cmd --permanent --zone=$zone --add-port=875/tcp
    firewall-cmd --reload
}

nfs_exports () {
    print_func
    mkdir -p $nfs_dir
    chown $nfs_dir $app_user
    echo "RPCNFSDCOUNT=64" > /etc/sysconfig/nfs
    if ( ! grep -q "^${nfs_dir}\s" /etc/exports )
    then
        echo "${nfs_dir}   ${dotcms_ip}(rw,sync,no_root_squash,no_subtree_check,insecure)" >> /etc/exports
    fi
    systemctl start --now rpcbind nfs-idmapd nfs-server
    exportfs -rav
}

fetch_sample_media () {
    print_func
    su -c "curl -o ${nfs_dir}/mountain1.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Blue_sky_clouds_and_mountains.jpg/800px-Blue_sky_clouds_and_mountains.jpg" $app_user
    su -c "curl -o ${nfs_dir}/mountain2.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Beartooth_Mountains_7.jpg/800px-Beartooth_Mountains_7.jpg" $app_user
}

create_nfs_server () {
    print_func
    selinux_permissive
    install_packages
    set_firewall
    create_app_user
    nfs_exports
    fetch_sample_media
}


####  dotcms server setup ####

# dotcms server
install_packages () {
    print_func
    yum install -y  epel-release
    yum install -y fail2ban rpcbind nfs-utils nfs4-acl-tools nginx
    systemctl enable --now fail2ban rpcbind nfs-idmapd
}

mount_nfs () {
    print_func
    mkdir -p ${nfs_dir}
    chown -R ${app_user}:${app_user} ${nfs_dir}
    if ( ! egrep -q "^[0-9\.]+:${nfs_dir}\s" /etc/fstab )
    then	
        echo "${nfs_ip}:${nfs_dir}  ${nfs_dir}  nfs  rw,sync,hard,intr,noatime 0 0" >> /etc/fstab
    fi 
    mount -v $nfs_dir
}

create_dotcms_server () {
    print_func
    selinux_permissive
    install_packages
    create_app_user
    mount_nfs
}

if [ "$local_ip" == "$nfs_ip" ]
then
   read -p "Install nfs(server) on this server [y/n]? " -n 1 -r
   echo 
   if [[ $REPLY =~ ^[Yy]$ ]]
    then
        create_nfs_server 
    fi
fi

if [ "$local_ip" == "$dotcms_ip" ]
then
   read -p "Install dotcms on this server [y/n]? " -n 1 -r
   echo 
   if [[ $REPLY =~ ^[Yy]$ ]]
    then
        create_dotcms_server 
    fi
fi
