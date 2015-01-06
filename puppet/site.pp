#The following is needed if you are not using puppet db
#Sonos hosting.com settings
$haproxy_vip='192.168.0.190'
$haproxy1_ip='192.168.0.82'
$haproxy2_ip='192.168.0.83'
$graphite1_ip='192.168.0.85'
$graphite2_ip='192.168.0.86'
$sensu1_ip='192.168.0.80'
$sensu2_ip='192.168.0.81'

$redis_master='192.168.0.80'
$haproxy_master='192.168.0.82'

#The haproxy vip is used for all load balancing
$graphiteweb_vip   = $haproxy_vip  #accessible by all hosts and user browsers
$graphiteinput_vip = $haproxy_vip  #accessible by all hosts
$elasticsearch_vip = $haproxy_vip  #accessible by all user browsers
$rabbitmq_vip      = $haproxy_vip  #accessible by all hosts
$redissensu_vip    = $haproxy_vip  #accessible by both sensu servers
$redisflapjack_vip = $haproxy_vip  #accessible by both sensu servers


import 'nodes/*.pp'
import 'roles/*.pp'


