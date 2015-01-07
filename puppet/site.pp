# below is used to work around issue in some provisioners where public network is not eth0
# modify eth0 to whatever your public network will be. i.e. 
# $::ipaddress_eth1 with virtualbox provider or 
# $::ipaddress_eth0 with vcenter provider

$main_nic = "eth1"

# We'll then be using the following variable instead of $::ipaddress.
$address = inline_template("<%= scope.lookupvar('::ipaddress_${main_nic}') -%>")


# The following is needed because we are using masterless puppet
$haproxy_vip    = '192.168.0.190'
$haproxy1_ip    = '192.168.0.82'
$haproxy2_ip    = '192.168.0.83'
$graphite1_ip   = '192.168.0.85'
$graphite2_ip   = '192.168.0.86'
$sensu1_ip      = '192.168.0.80'
$sensu2_ip      = '192.168.0.81'

$redis_master   = '192.168.0.80'
$haproxy_master = '192.168.0.82'


#The haproxy vip is used for all load balancing
#do not edit unless you know what you're doing
$graphiteweb_vip   = $haproxy_vip  #accessible by all hosts and user browsers
$graphiteinput_vip = $haproxy_vip  #accessible by all hosts
$elasticsearch_vip = $haproxy_vip  #accessible by all user browsers
$rabbitmq_vip      = $haproxy_vip  #accessible by all hosts
$redissensu_vip    = $haproxy_vip  #accessible by both sensu servers
$redisflapjack_vip = $haproxy_vip  #accessible by both sensu servers

import 'nodes/*.pp'
import 'roles/*.pp'


