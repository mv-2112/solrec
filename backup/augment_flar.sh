#!/bin/sh

# Shamelessly borrowed from many...

mkdir -p /var/opt/recovery
mkdir -p /var/opt/recovery/tar
mkdir -p /var/opt/recovery/etc
cp -p /etc/hosts /var/opt/recovery/etc
cp -p /etc/shadow /var/opt/recovery/etc
cp -p /etc/passwd /var/opt/recovery/etc
cp -p /etc/vfstab /var/opt/recovery/etc
cp -p /etc/nodename /var/opt/recovery/etc
cp -p /etc/hostname. /var/opt/recovery/etc
cp -p /etc/dhcp. /var/opt/recovery/etc
cp -p /etc/defaultdomain /var/opt/recovery/etc
cp -p /etc/TIMEZONE /var/opt/recovery/etc
mkdir -p /var/opt/recovery/etc/inet
cp -p /etc/inet/netmasks /var/opt/recovery/etc/inet/netmasks
cp -p /etc/defaultrouter /var/opt/recovery/etc/defaultrouter
mkdir -p /var/opt/recovery/var/ldap
cp -p /etc/.rootkey /var/opt/recovery/etc
cp -p /etc/resolv.conf /var/opt/recovery/etc
cp -p /etc/sysidcfg /var/opt/recovery/etc
cp -p /var/ldap/ldap_client_cache /var/opt/recovery/var/ldap/ldap_client_cache
cp -p /var/ldap/ldap_client_file /var/opt/recovery/var/ldap/ldap_client_file
cp -p /var/ldap/ldap_client_cred /var/opt/recovery/var/ldap/ldap_client_cred
cp -p /var/ldap/cachemgr.log /var/opt/recovery/var/ldap/cachemgr.log
mkdir -p /var/opt/recovery/var/nis
cp -p /var/nis/NIS_COLD_START /var/opt/recovery/var/nis
mkdir -p /var/opt/recovery/var/yp
cp -R -p /var/yp/ /var/opt/recovery/var/yp
# Capture some disk layout stuff for none root
mkdir -p /var/opt/recovery/disk
metastat -p > /var/opt/recovery/disk/metastat-p
zfs list > /var/opt/recovery/disk/zfslist
zpool list > /var/opt/recovery/disk/zpoollist
zpool status > /var/opt/recovery/disk/zpoolstatus
vxprint -ht > /var/opt/recovery/disk/vxprint-ht
vxdisk list > /var/opt/recovery/disk/vxdisklist
swap -l > /var/opt/recovery/disk/swap-l
tar cf /var/opt/recovery/tar/etc.tar /etc && compress /var/opt/recovery/tar/etc.tar
