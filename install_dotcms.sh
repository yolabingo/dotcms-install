#!/bin/sh
# vim: ts=4 sw=4 sts=4 et:

##############################
####  dotcms server setup ####
##############################

source ./common.sh

dotcms_install_packages () {
    print_funcname
    yum update -y
    amazon-linux-extras install -y  epel
    yum install -y rpcbind nfs-utils nfs4-acl-tools nginx certbot tar java-1.8.0-openjdk-headless
    systemctl enable --now rpcbind nfs-idmapd nginx
}


dotcms_install_elasticsearch () {
    print_funcname
    sysctl -w $( echo "vm.max_map_count=60000" | tee /etc/sysctl.d/dotcms-es-vm.max_map_count ) 
    docker-compose -f $(pwd)/elasticsearch/docker-compose.yml up -d
    waiting_for_es=true
    while [ "$waiting_for_es" = true ]
    do
        echo "waiting for elasticsearch..." 
        sleep 8
        if ( curl -s -X GET "127.0.0.1:9200/_cat/nodes?v&pretty" ) 
        then 
            waiting_for_es=true
        fi
    done
    echo "elasticsearch is reachable"
}

# mount the NFS media directory from the NFS server
dotcms_mount_nfs () {
    print_funcname
    mkdir -p ${nfs_dir}
    chown -R ${app_user}:${app_user} ${nfs_dir}
    if ( ! egrep -q "^[0-9\.]+:${nfs_dir}\s" /etc/fstab )
    then	
        echo "${nfs_ip}:${nfs_dir}  ${nfs_dir}  nfs  rw,sync,hard,intr,noatime 0 0" >> /etc/fstab
    fi 
    mount -v $nfs_dir
}

# install nginx with SSL as reverse proxy to dotcms app
dotcms_install_nginx_certbot () {
    print_funcname
    mkdir -p /usr/share/nginx/.well-known/acme-challenge
    sed "s,APP_SERVER_NAME,${app_servername},; s,NGINX_ROOT,${nginx_root}," nginx.conf \
		> /etc/nginx/conf.d/${app_servername}.conf
    systemctl reload nginx
    if [ ! -f /etc/letsencrypt/archive/${app_servername}/cert.pem ]
    then
        certbot certonly --webroot -d $app_servername -w $nginx_root \
		           --deploy-hook "/usr/bin/systemctl reload nginx.service" \
 			   --agree-tos --register-unsafely-without-email 
    fi 
    sed "s,APP_SERVER_NAME,${app_servername},; s,NGINXROOT,${nginx_root}," nginx-ssl.conf \
		> /etc/nginx/conf.d/${app_servername}-ssl.conf
    systemctl reload nginx
}

# install and start dotcms
dotcms_app_install () {
    if [ -d $app_dir/dotserver ]
    then
        return 0
    fi
    su -c "cd && mkdir -p $app_dir && curl $dotcms_download | tar -C $app_dir -xzf -" $app_user
    su -c 'echo "JAVA_HOME=$(dirname $(dirname $(dirname $(readlink -f $(which java)))))" >> ~/.bashrc' $app_user
    # ROOT folder config override
    # ugh hard-coded path 
    db_config="${app_dir}/plugins/com.dotcms.config/ROOT/dotserver/tomcat-8.5.32/webapps/ROOT/WEB-INF/classes/db.properties"
    su -c "mkdir -p $(dirname ${db_config})" $app_user

    cat << EOCONF > $db_config
driverClassName=org.postgresql.Driver
jdbcUrl=jdbc:postgresql://${postgres_ip}/${postgres_db}
username=${postgres_username}
password=${postgres_password}
connectionTestQuery=SELECT 1
maximumPoolSize=60
idleTimeout=10
maxLifetime=60000
leakDetectionThreshold=60000
EOCONF
    echo "DB config written to $db_config"
    echo "${app_dir}/bin/startup.sh" | su - $app_user
    echo
    echo "dotcms running at https://${app_servername}"
    echo
}

selinux_permissive
create_app_user
docker_install
dotcms_install_packages
dotcms_mount_nfs
dotcms_install_nginx_certbot
dotcms_app_install
