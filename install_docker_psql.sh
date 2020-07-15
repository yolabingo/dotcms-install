#!/bin/sh
# vim: ts=4 sw=4 sts=4 et:

################################
####  docker server setup ####
################################

source ./common.sh

# runs postgres and elasticsearch via docker, as $app_user
run_postgres () {
    cat <<- EOC | su - $app_user
    docker run \
        --name dotcms-postgres \
        -e POSTGRES_USER=${postgres_username} \
        -e POSTGRES_PASSWORD=${postgres_password} \
        -v dotcms_postgres:/var/lib/postgresql/data \
        -p ${postgres_ip}:5432:5432 \
        -d postgres:12
EOC
    docker ps
}

selinux_permissive
create_app_user
docker_install
run_postgres
