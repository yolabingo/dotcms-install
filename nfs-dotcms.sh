#!/bin/sh

# simple NFS server 

app_user=dotcms
app_user_uid=10000
nfs_dir=/home/${app_user}/export

# private IP(s) of nfs client
nfs_client_ip="192.168.223.183"

# private IP of this nfs server
nfs_ip=$( ip -o addr | grep "192.168" | awk '{print $4}' | sed 's,/.*,,' )

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
    yum install -y portmap nfs-utils nfs4-acl-tools
    systemctl enable --now fail2ban
    systemctl enable --now nfs-server.service
}

# add client IPs and NFS service to "internal" 
set_firewall () {
    print_func
    zone=internal
    for ip in $allowed_ips
    do
        firewall-cmd --zone=$zone --add-source=$ip
        firewall-cmd --permanent --zone=$zone --add-source=$ip
	echo "added $ip to zone $zone"
    done
    firewall-cmd --permanent --zone=$zone --add-port=111/tcp
    firewall-cmd --permanent --zone=$zone --add-port=54302/tcp
    firewall-cmd --permanent --zone=$zone --add-port=20048/tcp
    firewall-cmd --permanent --zone=$zone --add-port=46666/tcp
    firewall-cmd --permanent --zone=$zone --add-port=42955/tcp
    firewall-cmd --permanent --zone=$zone --add-port=875/tcp
    firewall-cmd --permanent --zone=$zone --add-service=nfs
    echo "added service nfs to zone $zone"
    firewall-cmd --reload
}

create_app_user () {
    print_func
    useradd --uid=$app_user_uid $app_user
    su -c "mkdir -p $nfs_dir" $app_user
}

nfs_exports () {
    print_func
    echo "RPCNFSDCOUNT=64" > /etc/sysconfig/nfs
    if ( ! grep -q "^${nfs_dir}\s" /etc/exports )
    then
        echo "${nfs_dir}   ${nfs_client_ip}(rw,sync,no_root_squash,no_subtree_check,insecure)" >> /etc/exports
    fi
    systemctl start --now rpcbind nfs-idmapd nfs-server
    exportfs -rav
}

fetch_sample_media () {
    print_func
    su -c "curl --create-dirs -o ${nfs_dir}/media/mountain1.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Blue_sky_clouds_and_mountains.jpg/800px-Blue_sky_clouds_and_mountains.jpg" $app_user
    su -c "curl --create-dirs -o ${nfs_dir}/media/mountain2.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Beartooth_Mountains_7.jpg/800px-Beartooth_Mountains_7.jpg" $app_user
    find ${nfs_dir} -type d -exec chmod 755 {} \;
    find ${nfs_dir} -type f -exec chmod 644 {} \;
}

selinux_permissive
install_packages
set_firewall
create_app_user
nfs_exports
fetch_sample_media
