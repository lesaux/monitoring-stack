class haproxycluster::keepalive::base {

include keepalived
sysctl { 'net.ipv4.ip_nonlocal_bind': value => '1' }

keepalived::vrrp::script { 'check_haproxy':
    script => '/usr/bin/killall -0 haproxy',
  }

}

class haproxycluster::keepalive::config {

  if $::address == $::haproxy_master {

  keepalived::vrrp::instance { 'VI_50':
    interface         => $::main_nic,
    state             => MASTER,
    virtual_router_id => 50,
    priority          => 101,
    auth_type         => PASS,
    auth_pass         => 'secret',
    virtual_ipaddress => [ $::haproxy_vip ],
    track_interface   => [ $::main_nic ], # optional, monitor these interfaces.
    track_script      => 'check_haproxy',
  }

} else {

  keepalived::vrrp::instance { 'VI_50':
    interface         => $::main_nic,
    state             => 'BACKUP',
    virtual_router_id => '50',
    priority          => '100',
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    virtual_ipaddress => [ $::haproxy_vip ],
    track_interface   => [ $::main_nic ], # optional, monitor these interfaces.
    track_script      => 'check_haproxy',
  }

  }

}

class haproxycluster::haproxy::base {

#Haproxy Configuration
case $::osfamily {
   'redhat': {
     yumrepo { "haproxy" :
       descr => "Haproxy, The software loadbalancer",
       baseurl => "http://download.linuxdataflow.org:81/rpm-repos/haproxy/el${operatingsystemmajrelease}/",
       enabled => 1,
       gpgcheck => 0,
       gpgkey => absent,
       exclude => absent,
       metadata_expire => absent,
     }
   }
   'debian': {
     apt::ppa {'ppa:vbernat/haproxy-1.5': }
   }
}->


  class { 'haproxy':
    global_options   => {
      'log'     => "$::address local0",
      'chroot'  => '/var/lib/haproxy',
      'pidfile' => '/var/run/haproxy.pid',
      'maxconn' => '4000',
      'user'    => 'haproxy',
      'group'   => 'haproxy',
      'daemon'  => '',
      'stats'   => 'socket /var/lib/haproxy/stats',
    },
    defaults_options => {
      'log'     => 'global',
      'option'  => 'redispatch',
      'retries' => '3',
      'timeout' => [
        'http-request 10s',
        'queue 1m',
        'connect 10s',
        'check 10s',
        'client 1m',
        'server 1m',
      ],
      'maxconn' => '8000',
    },
  }

}

class haproxycluster::haproxy::admin {
  
  haproxy::listen { 'admin':
    collect_exported => true,
    ipaddress        => $::address,
    mode             => 'http',
    ports            => '8080',
    options          => {
      'stats'  => [ 'enable' ],
    }
  }

}

class haproxycluster::redishappy::config {

  class {'redishappy':
    haproxy          => true,
    haproxy_binary   => '/usr/sbin/haproxy',
    haproxy_pidfile  => '/var/run/haproxy_redis.pid',
    template_path    => '/etc/redishappy-haproxy/haproxy_template.cfg',
    output_path      => '/etc/haproxy/haproxy_redis.cfg',
    clusters         => {
      'sensu'    => {
        'ExternalPort' => '6379',
      },
      'flapjack' => {
        'ExternalPort' => '6380',
      },
    },
    sentinels        => {
      'haproxy1'    => {
        'Host' => $::haproxy1_ip,
        'Port' => '26379',
      },
      'haproxy2'    => {
        'Host' => $::haproxy2_ip,
        'Port' => '26379',
      },
      'sensu1'      => {
        'Host' => $::sensu1_ip,
        'Port' => '26379',
      },
      'sensu2'      => {
        'Host' => $::sensu2_ip,
        'Port' => '26379',
      },
    },

  }

}

class haproxycluster::haproxy::graphiteweb {

  haproxy::frontend { 'graphite_web':
    ipaddress        => $haproxy_vip,
    mode             => 'http',
    ports            => '80',
    options          => {
      'default_backend' => ['graphite_web_backend'],
      'option'          => [ 'tcplog' ],
      'mode'            => 'http',
    }
  }

  haproxy::backend { 'graphite_web_backend':
    options => {
      'mode'    => [ 'http' ],
      'balance' => 'roundrobin',
    }
  }

}

class haproxycluster::haproxy::graphiteinput {

  haproxy::frontend { 'graphite_2003':
    ipaddress        => $haproxy_vip,
    ports            => '2003',
    options          => {
      'default_backend' => ['graphite_2213_backend'],
      'option'          => [ 'tcplog' ],
    }
  }

  haproxy::backend { 'graphite_2213_backend':
    options   => {
      'balance' => 'roundrobin',
    }
  }

}

class haproxycluster::haproxy::elasticsearch {

  haproxy::frontend { 'graphite_elasticsearch':
    ipaddress        => $haproxy_vip,
    mode             => 'http',
    ports            => '9200',
    options          => {
      'default_backend' => ['graphite_elasticsearch_backend'],
      'option'          => [ 'tcplog' ],
      'mode'            => 'http',
    }
  }

  haproxy::backend { 'graphite_elasticsearch_backend':
    options => {
      'mode'    => [ 'http' ],
      'balance' => 'roundrobin',
    }
  }

}

class haproxycluster::haproxy::rabbitmqsensu {

  haproxy::frontend { 'rabbitmq_sensu':
    ipaddress     => $haproxy_vip,
    ports         => '5671',
    mode          => 'tcp',
    options       => {
      'default_backend' => ['rabbitmq_sensu_backend'],
      'timeout client'  => '50000',
    }
  }

  haproxy::backend { 'rabbitmq_sensu_backend':
    options => {
      'option'  => [
        'tcpka',
      ]
    }
  }

}

class haproxycluster::haproxy::members {

##the following commented out is for use with puppetdb
#  @@haproxy::balancermember { "${::hostname}_redis_sensu":
#    listening_service => 'redis_sensu_backend',
#    server_names      => $::hostname,
#    ipaddresses       => $::ipaddress,
#    ports             => '6379',
#    options           => 'check',
#  }
#
#  @@haproxy::balancermember { "${::hostname}_flapjack_sensu":
#    listening_service => 'redis_flapjack_backend',
#    server_names      => $::hostname,
#    ipaddresses       => $::ipaddress,
#    ports             => '6380',
#    options           => 'check',
#  }
#
#  @@haproxy::balancermember { "${::hostname}_rabbitmq_sensu":
#    listening_service => 'rabbitmq_sensu_backend',
#    server_names      => $::hostname,
#    ipaddresses       => $::ipaddress,
#    ports             => '5671',
#    options           => 'check',
#  }

  haproxy::balancermember { 'graphite1_web':
    listening_service => 'graphite_web_backend',
    server_names      => "graphite1.$::domain",
    ipaddresses       => "$graphite1_ip",
    ports             => '80',
    options           => 'check',
  }

  haproxy::balancermember { 'graphite2_web':
    listening_service => 'graphite_web_backend',
    server_names      => "graphite2.$::domain",
    ipaddresses       => "$graphite2_ip",
    ports             => '80',
    options           => 'check',
  }

  haproxy::balancermember { 'graphite1_2213':
    listening_service => 'graphite_2213_backend',
    server_names      => "graphite1.$::domain",
    ipaddresses       => "$graphite1_ip",
    ports             => '2213',
    options           => 'check',
  }

  haproxy::balancermember { 'graphite2_2213':
    listening_service => 'graphite_2213_backend',
    server_names      => "graphite2.$::domain",
    ipaddresses       => "$graphite2_ip",
    ports             => '2213',
    options           => 'check',
  }

  haproxy::balancermember { 'graphite1_elasticsearch':
    listening_service => 'graphite_elasticsearch_backend',
    server_names      => "graphite1.$::domain",
    ipaddresses       => "$graphite1_ip",
    ports             => '9200',
    options           => 'check',
  }

  haproxy::balancermember { 'graphite2_elasticsearch':
    listening_service => 'graphite_elasticsearch_backend',
    server_names      => "graphite2.$::domain",
    ipaddresses       => "$graphite2_ip",
    ports             => '9200',
    options           => 'check',
  }

  haproxy::balancermember { 'sensu1_rabbitmq_sensu':
    listening_service => 'rabbitmq_sensu_backend',
    server_names      => "sensu1.$::domain",
    ipaddresses       => "$sensu1_ip",
    ports             => '5671',
    options           => 'check',
  }

  haproxy::balancermember { 'sensu2_rabbitmq_sensu':
    listening_service => 'rabbitmq_sensu_backend',
    server_names      => "sensu2.$::domain",
    ipaddresses       => "$sensu2_ip",
    ports             => '5671',
    options           => 'check',
  }


}
