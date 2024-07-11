- Nhập lệnh để update centos : yum update -y
- Kiếm tra xem đã mở IPV6 chưa :
  + vi /etc/sysctl.conf
    * net.ipv6.conf.default.disable_ipv6 = 0
    * net.ipv6.conf.all.disable_ipv6 = 0
  + sysctl -p
  + vi /etc/sysconfig/network-scripts/ifcfg-eth0
 
    * IPV4 : 103.79.141.203
    * Dải IPV6 theo IPV4 :
      * 2403:6a40:2:4300::203:0000/56
      * 2403:6a40:2:4300::1
    * Nhập thêm các dòng sau vào File :
  		* IPV6INIT=yes
  		* IPV6_AUTOCONF=no
  		* IPV6_DEFROUTE=yes
  		* IPV6_FAILURE_FATAL=no
  		* IPV6_ADDR_GEN_MODE=stable-privacy
  		* IPV6ADDR=2403:6a40:2:4300::203:0000/56
  		* IPV6_DEFAULTGW=2403:6a40:2:4300::1

  + service network restart
  + ping6 google.com

 - Nhập lệnh để tạo Proxy : bash <(curl -s "https://raw.githubusercontent.com/hoangdoduy/proxyv6/main/setup.sh")
 - vào /home/vpsttt để lấy proxy

ps -aux | grep 3proxy
