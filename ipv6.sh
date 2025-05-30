#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
install_3proxy() {
    echo "installing 3proxy"
    # https://github.com/hoangdoduy/proxyv6/raw/main/3proxy-3proxy-0.8.6.tar.gz
    # https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz
    URL="https://github.com/hoangdoduy/proxyv6/raw/main/3proxy-3proxy-0.8.6.tar.gz"
    wget -qO- $URL | bsdtar -xvf-
    cd 3proxy-3proxy-0.8.6
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cp ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    chkconfig 3proxy on
    touch /usr/local/etc/3proxy/3proxy.pid
    chmod 777 /usr/local/etc/3proxy/3proxy.pid
    
    echo "* hard nofile 999999" >>  /etc/security/limits.conf
    echo "* soft nofile 999999" >>  /etc/security/limits.conf
    echo "net.ipv6.conf.default.disable_ipv6=0" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6=0" >> /etc/sysctl.conf
    echo "net.ipv6.conf.eth0.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.eth0.accept_ra=2" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.accept_ra=2" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.accept_ra=2" >> /etc/sysctl.conf
    echo "net.ipv6.ip_nonlocal_bind=1" >> /etc/sysctl.conf
    sysctl -p
    systemctl stop firewalld
    systemctl disable firewalld
    
    cd $WORKDIR
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 1000
nobandlimin * * * * *
nobandlimout * * * * *
bandlimin 5120000 * * * * *
bandlimout 5120000 * * * * *
nserver 1.1.1.1
nserver 8.8.4.4
nscache 65536
nscache6 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456 
pidfile /usr/local/etc/3proxy/3proxy.pid
flush
auth strong

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}


gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "user$port/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}
echo "installing apps"
yum -y install gcc net-tools bsdtar zip >/dev/null

install_3proxy

echo "working folder = /home/dh"
WORKDIR="/home/dh"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"
echo "How Port proxy? Example 22000"
read FIRST_PORT
echo "How many proxy do you want to create? Example 500"
read COUNT

LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

bash /etc/rc.local

gen_proxy_file_for_user > /root/proxy.txt
rm -rf /root/setup.sh
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"
