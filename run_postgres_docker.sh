#!/bin/sh
# vim: ts=4 sw=4 sts=4 et:

################################
####  postgres server setup ####
################################

source ./common.sh

pg_install_packages () {
    yum upate -y
    amazon-linux-extras install -y docker	
    systemctl enable --now docker
}

pg_install () {
    print_funcname
    selinux_permissive
    pg_install_packages
}
