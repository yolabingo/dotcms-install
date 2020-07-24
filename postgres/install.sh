#!/bin/bash
# vim: ts=4 sw=4 sts=4 et:

################################
####  posegres server setup ####
################################

. ../common.sh

set_db_creds () {
    print_funcname
    sed "s/POSTGRES_DB/${postgres_db}/; \
         s/POSTGRES_USERNAME/${postgres_username}/; \
         s/POSTGRES_PASSWORD/${postgres_password}/" init.sql-template > init.sql 
}

# runs postgres and elasticsearch via docker, as $app_user
run_postgres () {
    print_funcname
    docker image build -t postgres12 .
    docker container run \
	    -e POSTGRES_PASSWORD=${postgres_superuser_password} \
	    -p ${postgres_ip}:5432:5432 \
	    --rm -it -d \
	    --name postgres12 postgres12
    docker ps
}

selinux_permissive
create_app_user
docker_install
set_db_creds
run_postgres
