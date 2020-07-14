#!/bin/sh

# simple NFS server 

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
postgres_password="b=&jinjili?thrammle*eTt&@3q&r87d"
# local 192.168 address of this machine
local_ip=$( ip -o addr | grep "192.168" | awk '{print $4}' | sed 's,/.*,,' )

dotcms_download=http://static.dotcms.com/versions/dotcms_5.3.3.tar.gz

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

install_nfs_packages () {
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
    firewall-cmd --reload
}

nfs_exports () {
    print_func
    mkdir -p $nfs_dir
    chown -R ${app_user}:${app_user} $nfs_dir
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
    ls -l $nfs_dir
}

create_nfs_server () {
    print_func
    selinux_permissive
    install_nfs_packages
    set_firewall
    create_app_user
    nfs_exports
    fetch_sample_media
}


####  dotcms server setup ####

# dotcms server
install_dotcms_packages () {
    print_func
    yum install -y  epel-release
    yum install -y fail2ban rpcbind nfs-utils nfs4-acl-tools nginx python3-certbot tar wget
    systemctl enable --now fail2ban rpcbind nfs-idmapd nginx
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

install_nginx_certbot () {
    sed "s/SERVERNAME/${app_servername}/" nginx.conf > /etc/nginx/conf.d/${app_servername}.conf
    systemctl reload nginx
    certbot certonly --webroot -d $app_servername -w /var/www --deploy-hook "/usr/bin/systemctl reload nginx.service" \
 			--agree-tos --register-unsafely-without-email 
    sed "s/SERVERNAME/${app_servername}/" nginx-ssl.conf > /etc/nginx/conf.d/${app_servername}-ssl.conf
    systemctl reload nginx
}

dotcms_app_prep () {
    su -c "cd && mkdir -p $app_dir && curl $dotcms_download | tar -C $app_dir -xzf -" $app_user
    su -c 'echo "JAVA_HOME=$(dirname $(dirname $(dirname $(readlink -f $(which java)))))" >> ~/.bashrc' $app_user
    # ROOT folder config override
    # ugh hard-coded path 
    db_config="${app_dir}/plugins/com.dotcms.config/ROOT/dotserver/tomcat-8.5.32/webapps/ROOT/WEB-INF/classes/db.properties"
    su -c "mkdir -p $(dirname ${db_config})" $app_user
    cat << EOF > $db_config
driverClassName=org.postgresql.Driver
jdbcUrl=jdbc:postgresql://${postgres_ip}/${postgres_db}
username=${postgres_username}
password=${postgres_password}
connectionTestQuery=SELECT 1
maximumPoolSize=60
idleTimeout=10
maxLifetime=60000
leakDetectionThreshold=60000
EOF
    echo "DB config written to $db_config"
}

create_dotcms_server () {
    print_func
    selinux_permissive
    install_dotcms_packages
    create_app_user
    mount_nfs
    dotcms_app_prep
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
