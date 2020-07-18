#!/bin/bash
# vim: ts=4 sw=4 sts=4 et:

##############################
####  elasticsearch server setup ####
##############################

.  ../common.sh

selinux_permissive
create_app_user
docker_install
install_elasticsearch 
