#!/bin/sh
# vim: ts=4 sw=4 sts=4 et:

################################
####  docker server setup ####
################################

source ./common.sh

docker_install () {
    yum upate -y
    amazon-linux-extras install -y docker	
    systemctl enable --now docker
    usermod -a -G docker $app_user
}

# runs postgres and elasticsearch via docker, as $app_user
docker_run () {
    echo "git clone https://github.com/yolabingo/dotcms-install" | su - $app_user
    echo "cd dotcms-install && ./run_postgres_docker.sh" | su - $app_user
    echo "cd dotcms-install && ./run_elasticserch_docker.sh" | su - $app_user
}

selinux_permissive
create_app_user
docker_install
docker_run
