#!/bin/bash
# init_centos shell  
#安装说明参见 https://sadsu.com/?p=
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

#安装程序只支持centos
[ $release != "centos" ] &&	echo -e "${red}Error:${plain} This script only support centos!" && exit 1
release_version=$(grep -o "[0-9]" /etc/redhat-release |head -n1)
	
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

install_gnome()
{
	echo -e "${yellow}安装VNC主程序${plain}"
	yum install tigervnc-server tigervnc epel-release -y
	clear
	echo -e "============================================================================="
	echo -e "               ${yellow}请设置你的VNC登录密码/Please Set VNC Password           "
	echo -e "               ${red}此密码不需要与你的服务器密码相同                         "
	echo -e "               ${red}建议使用密码含大小写字母以及数字                         "
	echo -e "${plain}==========================================================================="
	vncpasswd 
	echo -e "${yellow}安装桌面支持系统程序${plain}"
	yum update -y
	if [ "$release_version" -eq 7 ]; then
       yum groupinstall "X Window System" -y
	   yum install gnome-classic-session gnome-terminal nautilus-open-terminal control-center liberation-mono-fonts gedit firefox eog -y
	else
	   yum groupinstall "Desktop" -y
	   yum install gnome-classic-session gnome-terminal nautilus-open-terminal control-center liberation-mono-fonts gedit firefox eog -y
	fi
	#安装Adobe Flash Player 25，某些网赚页面必须程序
	echo -e "${yellow}Adobe Flash Player 25 ${plain}"
	rpm -ivh http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm
        rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-adobe-linux
	if [ "$release_version" -eq 7 ]; then
		yum install flash-plugin alsa-plugins-pulseaudio libcurl -y
	elif [ "$release_version" -eq 6 ]; then
		yum install flash-plugin nspluginwrapper alsa-plugins-pulseaudio libcurl -y
	else
		yum groupinstall "Sound and Video" -y
		yum install flash-plugin nspluginwrapper curl -y
	fi
	
	#设置vnc开机启动
	echo -e "${yellow}设置vnc开机启动${plain}"
	if [ "$release_version" -eq 7 ]; then
		cp /lib/systemd/system/vncserver@.service /etc/systemd/system/vncserver@:1.service
		sed -i 's/runuser -l <USER>/runuser -l root/g' /etc/systemd/system/vncserver@:1.service
		sed -i 's/PIDFile=\/home\/<USER>/PIDFile=\/root/g' /etc/systemd/system/vncserver@:1.service
		echo "启动VNC进程"
		systemctl enable vncserver@:1.service
		systemctl start vncserver@:1.service
	else
		echo 'echo "nameserver 8.8.8.8" >> /etc/resolv.conf; ' >> /etc/rc.local
		echo 'VNCSERVERS="5901:root"' >> /etc/sysconfig/vncservers 
		echo 'VNCSERVERARGS[1]="-geometry 1024x768"' >> /etc/sysconfig/vncservers
		echo "启动VNC进程"
		chkconfig vncserver on  --level 345
		service vncserver start
	fi
}


config_firewall() {
    if [ "$release_version" -eq 6 ]; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i 5901 > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 5901 -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "${green}Info:${plain} port ${green}5901${plain} already be enabled."
            fi
        else
            echo -e "${yellow}Warning:${plain} iptables looks like shutdown or not installed, please enable port 5901 manually if necessary."
        fi
    elif [ "$release_version" -eq 7 ]; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=5901/tcp
            firewall-cmd --reload
        else
		   systemctl status iptables > /dev/null 2>&1
		   if [ $? -eq 0 ]; then
				iptables -L -n | grep -i 5901 > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 5901 -j ACCEPT
					/usr/libexec/iptables/iptables.init save
					service iptables restart
				fi
		   else
				echo -e "${yellow}Warning:${plain} firewalld looks like not running, try to start..."
				systemctl start firewalld
				if [ $? -eq 0 ]; then
					firewall-cmd --permanent --zone=public --add-port=5901/tcp
					firewall-cmd --reload
				else
					echo -e "${yellow}Warning:${plain} Start firewalld failed, please enable port 5901 manually if necessary."
				fi
		   fi
        fi
    fi
}


show_end()
{

		echo -e "============================================================================="
		echo -e "                                 程序安装完毕                                     "            
		echo -e "你的VNC访问地址是：${yellow}${hostip}:5901 ${plain}请注意设置你的vnc软件    "
		echo -e "${plain}==========================================================================="
}

#----------------------------------------------------------#
#                  Show interface                          #
#----------------------------------------------------------#
#安装程序必须root权限
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1

clear

echo
echo "###############################################################"
echo "# Centos Gnome Auto Install                                   #"
echo "# System Supported: CentOS 5 6 7                              #"
echo "# Intro: https://sadsu.com/?p=                                #"
echo "# Author: kevin <yanglc@sadsu.com>                            #"
echo "###############################################################"
echo

get_os_info

echo -e "===========================================================
                       Centos远程桌面准备安装	
${plain}==========================================================="
echo "按任意键开始安装 Ctrl+C 取消"
char=`get_char`	

clear
install_gnome
config_firewall
show_end
