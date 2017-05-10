#!/bin/bash
# init_centos shell  
#安装说明参见 https://sadsu.com/?p=16
#----------------------------------------------------------#
#                  Variables&Functions                     #
#----------------------------------------------------------#
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
needreboot="F"
hostip=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${hostip} ] && hostip=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')

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


	
get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

get_opsy(){
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}


get_os_info(){
    local cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    local cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
    local freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
    local tram=$( free -m | awk '/Mem/ {print $2}' )
    local swap=$( free -m | awk '/Swap/ {print $2}' )
    local up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60;d=$1%60} {printf("%ddays, %d:%d:%d\n",a,b,c,d)}' /proc/uptime )
    local load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
    local opsy=$( get_opsy )
    local arch=$( uname -m )
    local lbit=$( getconf LONG_BIT )
    local host=$( hostname )
    local kern=$( uname -r )

    echo "########## System Information ##########"
    echo 
    echo "CPU model            : ${cname}"
    echo "Number of cores      : ${cores}"
    echo "CPU frequency        : ${freq} MHz"
    echo "Total amount of ram  : ${tram} MB"
    echo "Total amount of swap : ${swap} MB"
    echo "System uptime        : ${up}"
    echo "Load average         : ${load}"
    echo "OS                   : ${opsy}"
    echo "Arch                 : ${arch} (${lbit} Bit)"
    echo "Kernel               : ${kern}"
    echo "Hostname             : ${host}"
    echo "IPv4 address         : ${hostip}"
    echo 
    echo "########################################"
}

install_cp()
{
	#安装常规程序
	yum install mlocate vim yum-utils net-tools bind-utils iptables iptables-services wget mtr gcc-c++ screen git epel-release -y
	yum install vnstat -y
	yum update -y
	#设置vnstat 开机启动
	chkconfig vnstat on
	#初始化vnstat数据库
	vnstat -d
}

close_selinux()
{
	#检测 SELinux 状态
	/usr/sbin/sestatus -v|grep enabled > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
		needreboot="T"
	fi
}

set_iptables()
{
	release_version=$(grep -o "[0-9]" /etc/redhat-release |head -n1)
	#centos7更换防火墙由firewalld为iptables
	if [ "$release_version" -eq 7 ]; then
		systemctl stop firewalld.service 
		systemctl disable firewalld.service
		systemctl restart iptables.service 
		systemctl enable iptables.service 
	else
		service iptables start
		chkconfig iptables on
	fi
	

}

set_sshport()
{
	#设置ssh端口
	sed -i 's/#Port 22/Port '$sshport'/g' /etc/ssh/sshd_config
	#给iptables增加ssh接口
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${sshport} -j ACCEPT
	/usr/libexec/iptables/iptables.init save
	if [ $needreboot == "F" ]; then
		service iptables restart
		service sshd restart
	fi
}

show_end()
{

	if [ $needreboot == "T" ]; then
		echo -e "====================================================================="
		echo -e "          程序安装完毕                                              "            
		echo -e "你的ssh访问端口是：${yellow}${sshport}，${plain}请注意重新设置你的ssh软件 "
		echo -e "${plain}====================================================================="  
		echo "  由于设置了SELinux状态，机器需要重启才能使设置生效"
		echo -ne "  Do you wish to reboot (recommended!): (Default ${green}Y${plain})"; read reboot
		case $reboot in
			[yY] | [yY][Ee][Ss] | "") reboot                 ;;
			[nN] | [nN][Oo] ) echo "  ${cyan}Skipping reboot${normal} ... " ;;
		esac
	else
		echo -e "====================================================================="
		echo -e "          程序安装完毕                                               "            
		echo -e "你的ssh访问端口是：${yellow}${sshport}，${plain}请注意重新设置你的ssh软件 "
		echo -e "${plain}====================================================================="
	fi

}

#----------------------------------------------------------#
#                  Show interface                          #
#----------------------------------------------------------#
#安装程序必须root权限
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1
#安装程序只支持centos
[ $release != "centos" ] &&	echo -e "${red}Error:${plain} This script only support centos!" && exit 1


clear

echo
echo "###############################################################"
echo "# Centos Init AutoInstaller                                   #"
echo "# System Supported: CentOS 5 6 7                              #"
echo "# Intro: https://sadsu.com/?p=147                             #"
echo "# Author: kevin <yanglc@sadsu.com>                            #"
echo "###############################################################"
echo

get_os_info

echo "  请输入希望使用的登录SSH端口号(1-65535):"
    read -p "(默认端口: 5678):" sshport
    [ -z ${sshport} ] && sshport="5678"

echo -e "===========================================================
                         程序准备安装	
     你的ssh访问端口是：${yellow}${sshport}
${plain}==========================================================="
echo "按任意键开始安装 Ctrl+C 取消"
char=`get_char`	

clear
install_cp
close_selinux
set_iptables
set_sshport
show_end



