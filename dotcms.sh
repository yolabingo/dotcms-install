#!/bin/sh

##############################
####  dotcms server setup ####
##############################

source ./common.sh

# dotcms server
dotcms_install_packages () {
    print_funcname
    amazon-linux-extras install -y  epel
    yum install -y fail2ban rpcbind nfs-utils nfs4-acl-tools nginx certbot tar 
    systemctl enable --now fail2ban rpcbind nfs-idmapd nginx
}

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

dotcms_install_nginx_certbot () {
    mkdir -p /usr/share/nginx/.well-known/acme-challenge
    sed "s/SERVERNAME/${app_servername}/; s/NGINXROOT/${nginx_root}" nginx.conf \
		> /etc/nginx/conf.d/${app_servername}.conf
    systemctl reload nginx
    if [ ! -f /etc/letsencrypt/archive/${app_servername}/cert.pem ]
    then
        certbot-3 certonly --webroot -d $app_servername -w $nginx_root \
		           --deploy-hook "/usr/bin/systemctl reload nginx.service" \
 			   --agree-tos --register-unsafely-without-email 
    fi 
    sed "s/SERVERNAME/${app_servername}/; s/NGINXROOT/${nginx_root}" nginx-ssl.conf \
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
    ${app_dir}/bin/startup.sh
    echo
    echo "dotcms running at https://${app_servername}"
    echo
}

print_funcname
selinux_permissive
create_app_user
dotcms_install_packages
dotcms_mount_nfs
dotcms_install_nginx_certbot
dotcms_app_install
