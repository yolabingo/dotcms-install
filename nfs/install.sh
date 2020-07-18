#!/bin/bash
# vim: ts=4 sw=4 sts=4 et:
	
##########################
#### NFS server setup ####
##########################

source ./common.sh

nfs_install_packages () {
    print_funcname
    yum update -y
    amazon-linux-extras install -y epel
    yum install -y portmap nfs-utils nfs4-acl-tools
    systemctl enable --now nfs-server
}

# create and export NFS media directory
nfs_exports () {
    print_funcname
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

# add some image files to the NFS dir for testing
nfs_fetch_sample_media () {
    print_funcname
    su -c "curl -o ${nfs_dir}/mountain1.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Blue_sky_clouds_and_mountains.jpg/800px-Blue_sky_clouds_and_mountains.jpg" $app_user
    su -c "curl -o ${nfs_dir}/mountain2.jpg https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Beartooth_Mountains_7.jpg/800px-Beartooth_Mountains_7.jpg" $app_user
    ls -l $nfs_dir
}

selinux_permissive
create_app_user
nfs_install_packages
nfs_exports
nfs_fetch_sample_media
