#!/bin/bash
# vim: ts=4 sw=4 sts=4 et:

##############################
####  dotcms server setup ####
##############################

# install dotcms from binary tarball and run as "dotcms" user
# install nginx as reverse proxy, add cerbot SSL cert

.  ../common.sh

dotcms_install_packages () {
    print_funcname
    yum update -y
    amazon-linux-extras install -y  epel
    yum install -y rpcbind nfs-utils nfs4-acl-tools nginx certbot tar java-1.8.0-openjdk-headless
    systemctl enable --now rpcbind nfs-idmapd nginx
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
dotcms_download () {
    if [ -d $app_dir/dotserver ]
    then
        return 0
    fi
    url=${dotcms_download=http://static.dotcms.com/versions/dotcms_${dotcms_version}.tar.gz}
    su -c "cd && mkdir -p $app_dir && curl $url | tar -C $app_dir -xzf -" $app_user
    su -c 'echo "JAVA_HOME=$(dirname $(dirname $(dirname $(readlink -f $(which java)))))" >> ~/.bashrc' $app_user
    # ROOT folder config override
    db_config="${app_dir}/plugins/com.dotcms.config/ROOT/dotserver/tomcat-${tomcat_version}/webapps/ROOT/WEB-INF/classes/db.properties"
    su -c "mkdir -p $(dirname ${db_config})" $app_user

    cat <<- EOCONF > $db_config
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
}

build_elasticsearch_image () {
    # copy dotcms packages and SSL certs/key to elasticsearch image
    sed -i'' "s/^ELASTIC_PASSWORD=.*/ELASTIC_PASSWORD=${elasticsearch_superuser_password}/" .env
    webinf=${app_dir}/dotserver/tomcat-${tomcat_version}/webapps/ROOT/WEB-INF
    cp -R ${webinf}/elasticsearch/config .
    cat <<- EODOCKER > Dockerfile
	FROM docker.elastic.co/elasticsearch/elasticsearch:${elasticsearch_version}
 	RUN mkdir -p  /usr/share/elasticsearch/config/certificates/ca
	COPY config/root-ca.pem       /usr/share/elasticsearch/config/certificates/ca/root-ca.pem
	COPY config/elasticsearch.pem /usr/share/elasticsearch/config/certificates/elasticsearch.pem
	COPY config/elasticsearch.key /usr/share/elasticsearch/config/certificates/elasticsearch.key
EODOCKER
    for jar in $( find ${webinf}/lib -type f -name "dotcms*.jar" -exec basename {} \; )
    do
        mkdir -p jarfiles
	cp ${webinf}/lib/$jar jarfiles/
	echo "COPY jarfiles/$jar  /usr/share/elasticsearch/lib/$jar" >> Dockerfile
    done
    # docker build -t elasticsearch-dotcms .
}

install_elasticsearch () {
    print_funcname
    sysctl -w $( echo "vm.max_map_count=262144" | tee /etc/sysctl.d/dotcms-es-vm.max_map_count ) 
}


# selinux_permissive
# create_app_user
# docker_install
# dotcms_install_packages
# dotcms_mount_nfs
# dotcms_install_nginx_certbot
# dotcms_download
build_elasticsearch_image
# install_elasticsearch

