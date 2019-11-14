#!/bin/bash

[[ $DEBUG ]] && set -ex || set -e

get_distribution() {
	lsb_dist=""
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	echo "$lsb_dist"
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

copy_from_centos(){
    info "Update default to CentOS" "$1"
    cp -a ./hack/chinaos/centos-release /etc/os-release
    mkdir -p /etc/yum.repos.d/backup >/dev/null 2>&1
    mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup >/dev/null 2>&1
    cp -a ./hack/chinaos/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo
}

copy_from_ubuntu(){
    info "Update default to Ubuntu" "$1"
    cp -a ./hack/chinaos/ubuntu-release /etc/os-release
    cp -a ./hack/chinaos/ubuntu-lsb-release /etc/lsb-release
    cp -a /etc/apt/sources.list /etc/apt/sources.list.old
    cp -a ./hack/chinaos/sources.list /etc/apt/sources.list
}

other_type_linux(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
    case "$lsb_dist" in
        neokylin)
            copy_from_centos $lsb_dist
        ;;
        kylin)
            copy_from_ubuntu $lsb_dist
        ;;    
    esac
}

offline_init(){
    sed -ir 's/install_type: online/install_type: offline/' ./roles/glusterfs/server/defaults/main.yml
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"



    case "$lsb_dist" in
	ubuntu|debian)

        apt-get update
        apt-get install -y sshpass python-pip uuid-runtime pwgen expect
		;;
	centos)
	    mkdir -p /etc/yum.repos.d/backup >/dev/null 2>&1
        mv -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup
        rm -rf /opt/glusterfs/ && mkdir /opt/glusterfs/
        tar xf /opt/glusterfs.tgz -C /opt/glusterfs/
        cat > /etc/yum.repos.d/glusterfs.repo << EOF
[glusterfs]
name=rainbond_offline_install_repo
baseurl=file:///opt/glusterfs/pkgs/rpm/centos/7
gpgcheck=0
enabled=1
EOF
        yum makecache
        yum install -y ansible
	;;
	*)
        exit 1
	;;
esac
}

online_init(){
    lsb_dist=$( get_distribution )
    lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

    case "$lsb_dist" in
		ubuntu|debian)
            apt-get update
            apt-get install -y sshpass python-pip uuid-runtime pwgen expect
		;;
		centos)
            yum install -y epel-release 
            yum makecache fast 
            yum install -y sshpass python-pip uuidgen pwgen expect
            pip install -U setuptools -i https://pypi.tuna.tsinghua.edu.cn/simple
		;;
		*)
            exit 1
		;;
    esac
    export LC_ALL=C
    pip install ansible==2.8.5 -i https://pypi.tuna.tsinghua.edu.cn/simple

}

install(){
    ansible-playbook -i inventory/hosts glusterfs.yml
}

case $1 in
    offline)
        other_type_linux
        offline_init
        install
    ;;
    *)
        other_type_linux
        online_init
        install
    ;;
esac
