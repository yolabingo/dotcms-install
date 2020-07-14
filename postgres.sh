#!/bin/sh

################################
####  postgres server setup ####
################################

pg_install_packages () {
}

pg_install () {
    print_funcname
    selinux_permissive
    pg_install_packages
}
