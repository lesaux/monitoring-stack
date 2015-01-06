class sensucluster::redis::base {

  class { 'redis::install':
    redis_version     => '2.8.19',
    redis_build_dir   => '/opt/redis/build',
    redis_install_dir => '/opt/redis/'
  }

}

class sensucluster::redis::sensu {

  if $::ipaddress == $::redis_master {

    redis::server {
      'sensu':
        redis_memory    => '1g',
        redis_ip        => $::ipaddress,
        redis_port      => 6379,
        redis_mempolicy => 'allkeys-lru',
        redis_timeout   => 0,
        redis_nr_dbs    => 16,
        redis_loglevel  => 'notice',
        running         => true,
        enabled         => true
    }

  } else {

    redis::server {
      'sensu':
        redis_memory    => '1g',
        redis_ip        => $::ipaddress,
        redis_port      => 6379,
        redis_mempolicy => 'allkeys-lru',
        redis_timeout   => 0,
        redis_nr_dbs    => 16,
        redis_loglevel  => 'notice',
        running         => true,
        enabled         => true,
        slaveof         => "$::redis_master 6379"
    }

  }

}

class sensucluster::redis::sensu::monit {

  monit::service::template { 'redis-server_sensu':
    process_name  => redis-server_sensu,
    pid_file      => '/var/run/redis_sensu.pid',
    start_program => '/etc/init.d/redis-server_sensu start',
    stop_program  => '/etc/init.d/redis-server_sensu stop',
    port          => 6379,
    ip            => $::ipaddress,
  }

}

class sensucluster::redis::flapjack {

  if $::ipaddress == $::redis_master {

    redis::server {
      'flapjack':
        redis_memory    => '1g',
        redis_ip        => $::ipaddress,
        redis_port      => 6380,
        redis_mempolicy => 'allkeys-lru',
        redis_timeout   => 0,
        redis_nr_dbs    => 16,
        redis_loglevel  => 'notice',
        running         => true,
        enabled         => true
    }

  } else {

    redis::server {
      'flapjack':
        redis_memory    => '1g',
        redis_ip        => $::ipaddress,
        redis_port      => 6380,
        redis_mempolicy => 'allkeys-lru',
        redis_timeout   => 0,
        redis_nr_dbs    => 16,
        redis_loglevel  => 'notice',
        running         => true,
        enabled         => true,
        slaveof         => "$::redis_master 6380"
    }

  }

}

class sensucluster::redis::flapjack::monit {

  monit::service::template { 'redis-server_flapjack':
    process_name  => redis-server_flapjack,
    pid_file      => '/var/run/redis_flapjack.pid',
    start_program => '/etc/init.d/redis-server_flapjack start',
    stop_program  => '/etc/init.d/redis-server_flapjack stop',
    port          => 6380,
    ip            => $::ipaddress,
  }

}


class sensucluster::redis::sentinel {

  redis::sentinel {'sensu':
    sentinel_port    => 26379,
    monitors => {
      'sensu'    => {
        master_host             => "$::redis_master",
        master_port             => 6379,
        quorum                  => 1,
        down_after_milliseconds => 1200,
        parallel-syncs          => 1,
        failover_timeout        => 2000
      },
      'flapjack' => {
        master_host             => "$::redis_master",
        master_port             => 6380,
        quorum                  => 1,
        down_after_milliseconds => 1200,
        parallel-syncs          => 1,
        failover_timeout        => 2000
      }
    }
  }

}
class sensucluster::redis::healthcheck {

  include redis::healthcheck

  $redis_healthchecks = {
    'sensu'    => { redisip         => $ipaddress,
                    redisport       => 6379,
                    healthcheckport => 6479,
    },
    'flapjack' => { redisip         => $ipaddress,
                    redisport       => 6380,
                    healthcheckport => 6480,
    }
  }
  create_resources ( redis::healthcheck::xinetd, $redis_healthchecks )

}


class sensucluster::rabbitmq::base {

  file { '/etc/rabbitmq/ssl/cacert.pem':
    mode    => '0775',
    source  => 'puppet:///modules/sensucustom/certs/testca/cacert.pem',
    require => Class['::rabbitmq']
  }
  file { '/etc/rabbitmq/ssl/server_cert.pem':
    mode    => '0775',
    source  => 'puppet:///modules/sensucustom/certs/server_cert.pem',
    require => Class['::rabbitmq']
  }
  file { '/etc/rabbitmq/ssl/server_key.pem':
    mode    => '0775',
    source  => 'puppet:///modules/sensucustom/certs/server_key.pem',
    require => Class['::rabbitmq']
  }

}

class sensucluster::rabbitmq::config {

  rabbitmq_user {'sensu':
    admin    => false,
    password => 'sensu123',
  }
  rabbitmq_user {'admin':
    admin    => true,
    password => 'admin',
  }
  rabbitmq_user_permissions { 'sensu@/sensu':
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  }
  rabbitmq_vhost {'/sensu':
    ensure => 'present'
  }

  class { 'rabbitmq':
    service_manage           => true,
    port                     => '5672',
    delete_guest_user        => true,
    config_cluster           => true,
    cluster_nodes            => ["$::sensu1_ip", "$::sensu2_ip"],
    cluster_node_type        => 'disc',
    wipe_db_on_cookie_change => true,
    config_variables         => {
      'ssl_listeners' => '[5671]',
      'ssl_options'   => '[{cacertfile,"/etc/rabbitmq/ssl/cacert.pem"},
                           {certfile,"/etc/rabbitmq/ssl/server_cert.pem"},
                           {keyfile,"/etc/rabbitmq/ssl/server_key.pem"},
                           {verify,verify_peer},
                           {fail_if_no_peer_cert,true}]'
    },
    ssl_cacert               => 'puppet:///modules/sensucustom/certs/testca/cacert.pem',
    ssl_cert                 => 'puppet:///modules/sensucustom/certs/cert.pem',
    ssl_key                  => 'puppet:///modules/sensucustom/certs/key.pem'
  }

}

class sensucluster::rabbitmq::monit {

  monit::service::template { 'rabbitmq-server':
    process_name  => rabbitmq-server,
    pid_file      => '/var/run/rabbitmq/pid',
    start_program => '/etc/init.d/rabbitmq-server start',
    stop_program  => '/etc/init.d/rabbitmq-server stop',
    port          => 5671,
    ip            => $::ipaddress,
  }

}

class sensucluster::sensu::base {

  class { 'sensu':
    require                  => [Class['sensucluster::rabbitmq::config'],
                                 Class['sensucluster::redis::sensu'],
                                 Class['sensucluster::redis::flapjack']],
    version                  => latest,
    install_repo             => true,
    repo                     => main,
    client                   => true,
    server                   => true,
    api                      => true,
    manage_services          => true,
    manage_user              => true,
    rabbitmq_port            => '5671',
    rabbitmq_host            => $::rabbitmq_vip,
    rabbitmq_user            => 'sensu',
    rabbitmq_password        => 'sensu123',
    rabbitmq_vhost           => '/sensu',
    rabbitmq_ssl_private_key => 'puppet:///modules/sensucustom/certs/client_key.pem',
    rabbitmq_ssl_cert_chain  => 'puppet:///modules/sensucustom/certs/client_cert.pem',
    redis_host               => $::redissensu_vip,
    api_bind                 => '0.0.0.0',
    api_host                 => 'localhost',
    api_port                 => '4567',
    api_user                 => 'apiuser',
    api_password             => 'apipassword',
    use_embedded_ruby        => true,
    subscriptions            => ['linux_graphite', 'remote_cisco', 'remote_esx', 'remote_ping', 'remote_http', 'remote_emc'],
    plugins                  => [
      'puppet:///modules/sensucustom/sensuscripts/check-data.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-cpu.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-disk.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-swap-percentage.sh',
      'puppet:///modules/sensucustom/sensuscripts/check-memory-pcnt.sh',
      'puppet:///modules/sensucustom/sensuscripts/check-netstat-tcp.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-load.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-fstab-mounts.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-ntp.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-ping.rb',
      'puppet:///modules/sensucustom/sensuscripts/check-http.rb',
    ],
    client_custom            => {
      keepalive => {
        'type'      => 'metric',
        'handler'   => 'flapjack'
      }
    }
  }

}

class sensucluster::sensu::monit {

  monit::service::template { 'sensu-server':
    process_name  => sensu-server,
    pid_file      => '/var/run/sensu/sensu-server.pid',
    start_program => '/etc/init.d/sensu-server start',
    stop_program  => '/etc/init.d/sensu-server stop',
    port          => false,
    ip            => false,
  }

  monit::service::template { 'sensu-api':
    process_name  => sensu-api,
    pid_file      => '/var/run/sensu/sensu-api.pid',
    start_program => '/etc/init.d/sensu-api start',
    stop_program  => '/etc/init.d/sensu-api stop',
    port          => 4567,
    ip            => $::ipaddress,
  }

  monit::service::template { 'sensu-client':
    process_name  => sensu-client,
    pid_file      => '/var/run/sensu/sensu-client.pid',
    start_program => '/etc/init.d/sensu-client start',
    stop_program  => '/etc/init.d/sensu-client stop',
    port          => false,
    ip            => false,
  }

}

class sensucluster::sensu::dashboard {

  class { 'uchiwa':
    require         => Class['sensu'],
    install_repo    => false,
    manage_services => true,
    manage_user     => true,
  }

  uchiwa::api { "${::hostname}":
    host    => 'localhost',
    ssl     => false,
    port    => 4567,
    user    => 'apiuser',
    pass    => 'apipassword',
    path    => '',
    timeout => 5000
  }

}

class sensucluster::sensu::dashboard::monit {

  monit::service::template { 'uchiwa':
    process_name  => uchiwa,
    pid_file      => '/var/run/uchiwa.pid',
    start_program => '/etc/init.d/uchiwa start',
    stop_program  => '/etc/init.d/uchiwa stop',
    port          => 3000,
    ip            => $::ipaddress,
  }

}

class sensucluster::sensu::subscriptions {

  class { 'sensucustom::subscriptions::linux-graphite':
    graphite_host => $::graphiteweb_vip
  }
  class { 'sensucustom::subscriptions::linux-local':}
  class { 'sensucustom::subscriptions::windows-graphite':
    graphite_host => $::graphiteweb_vip
  }

}

class sensucluster::sensu::custom {

# remote checks dependencies
  class { 'sensucustom::nagiosperfdata': 
    graphite_ip   => $::graphiteinput_vip,
    graphite_port => 2003,
  }
# needed if you plan to monitor vmware stuff
#  class { 'vmwareperlsdk': }
# needed to monitor emc
#  class { 'navisphere': }
# plan for future monitoring of network equipments
#  class { 'sflowtool': }

# emc monitors
#  class { 'sensucustom::emc':
#    username => 'username',
#    password => 'password',
#  }
# cisco monitoring
#  class { 'sensucustom::cisco': }
#  class { 'sensucustom::vmware':
#    username => 'username',
#    password => 'password',
#  }
#  class {'sensucustom::http': }

# remote checks definition
#  class {'sensucustom::remotechecks::cisco': }
#  class {'sensucustom::remotechecks::emc': }
#  class {'sensucustom::remotechecks::http': }
#  class {'sensucustom::remotechecks::ping': }
#  class {'sensucustom::remotechecks::vmware': }

}

class sensucluster::flapjack::base {

    class { 'flapjack':
      redis_host                               => $::redisflapjack_vip,
      embedded_redis                           => false,
      new_check_scheduled_maintenance_duration => '0 seconds',
      gateways_email_enabled                   => yes,
      gateways_email_smtp_port                 => 25,
      gateways_email_smtp_domain               => "${::domain}",
      gateways_email_smtp_from                 => "${::hostname}@${::domain}",
      web_api_url                              => "http://${::ipaddress}:3081/",
    }

}

class sensucluster::flapjack::config {

  class { 'sensucustom::flapjack':
    redis_host     => $::redisflapjack_vip,
    redis_port     => '6380',
    redis_db       => '0',
  }

}

class sensucluster::flapjack::monit {

  monit::service::template { 'flapjack':
    process_name  => flapjack,
    pid_file      => '/var/run/flapjack/flapjack.pid',
    start_program => '/etc/init.d/flapjack start',
    stop_program  => '/etc/init.d/flapjack stop',
    port          => 3080,
    ip            => $::ipaddress,
  }

}


class sensucluster::postfix::base {

  class { '::postfix::server':
    myhostname            => "${::fqdn}",
    mydomain              => "${::domain}",
    inet_interfaces       => 'all',
    extra_main_parameters => {
      'mynetworks_style' => 'host',
    }
  }

}


class sensucluster::postfix::monit {

  monit::service::template { 'postfix':
    process_name  => postfix,
    pid_file      => '/var/spool/postfix/pid/master.pid',
    start_program => '/etc/init.d/postfix start',
    stop_program  => '/etc/init.d/postfix stop',
    port          => 25,
    ip            => '127.0.0.1',
  }

}
