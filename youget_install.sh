#!/bin/bash
# centos环境一键安装you-get
# code by kevin-cn

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1
#[[ -d "/proc/vz" ]] && echo -e "${red}Error:${plain} Your VPS is based on OpenVZ, not be supported." && exit 1
if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi

#安装程序只支持centos
[ $release != "centos" ] &&	echo -e "${red}Error:${plain} This script only support centos!" && exit 1
release_version=$(grep -o "[0-9]" /etc/redhat-release |head -n1)

check_result() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2"
        exit $1
    fi
}

#安装准备文件
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装支持程序"
echo -e "${plain}============================================================"
yum install -y gcc-c++ epel-release zip unzip screen zlib zlib-devel

#安装ffmpeg
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装ffmpeg"
echo -e "${plain}============================================================"
if [ "$release_version" -eq 7 ]; then
	rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
	rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
	rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm
else
	yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-6.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-6.noarch.rpm
fi
yum install -y ffmpeg 
check_result $? "Can't install ffmpeg"

#安装python3
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装python3"
echo -e "${plain}============================================================"
cd /tmp
wget https://www.python.org/ftp/python/3.6.1/Python-3.6.1.tgz
tar zxf Python-3.6.1.tgz
cd Python-3.6.1
./configure --prefix=/usr/local/python3
check_result $? "Can't configure python3"
make
check_result $? "Can't make python3"
make install
check_result $? "Can't install python3"
cd /usr/bin/
rm -f python3
ln -s /usr/local/python3/bin/python3.6 python3
cd /tmp
rm -rf Python-3.6.1*


#安装you-get
echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}开始安装you-get"
echo -e "${plain}============================================================"
cd /root
wget -N --no-check-certificate https://github.com/soimort/you-get/archive/master.zip
check_result $? "Can't wget you-get"
unzip master.zip
cd you-get-master
python3 setup.py install
check_result $? "Can't install you-get"
cd /usr/bin/
ln -s /usr/local/python3/bin/you-get you-get
cd ~
you-get -V


echo -e "${plain} "
echo -e "${plain} "
echo -e "${plain}============================================================"
echo -e "${yellow}安装结束"
echo -e "${yellow}详细使用教程请看逗比大佬的教程 https://doub.bid/dbrj-4/"
echo -e "${plain}============================================================"

