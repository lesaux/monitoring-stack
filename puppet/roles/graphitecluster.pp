class graphitecluster::elasticsearch::base {

  class { 'elasticsearch':
    manage_repo  => true,
    repo_version => '1.2',
    java_install => true,
    status       => 'enabled',
  }

}

class graphitecluster::elasticsearch::config {

  elasticsearch::instance { 'es-01':
  }

  elasticsearch::plugin{'mobz/elasticsearch-head':
    module_dir => 'head',
    instances  => 'es-01',
  }

}

class graphitecluster::elasticsearch::monit {

  monit::service::template { 'elasticsearch-es-01':
    process_name  => elasticsearch,
    pid_file      => '/var/run/elasticsearch/elasticsearch-es-01.pid',
    start_program => '/etc/init.d/elasticsearch-es-01 start',
    stop_program  => '/etc/init.d/elasticsearch-es-01 stop',
    port          => 9200,
    ip            => $::ipaddress,
  }

}

class graphitecluster::apache::base {

  class {'apache':
    default_vhost => false,
  }

}

class graphitecluster::apache::config {

  file { '/opt/graphite':
    ensure  => directory,
  }->

  case $::osfamily {
    'redhat': {
      file { '/opt/graphite/webapp':
        ensure  => directory,
        owner => apache,
        group => apache,
      }
    }
    'debian': {
      file { '/opt/graphite/webapp':
        ensure  => directory,
        owner => www-data,
        group => www-data,
      }
    }
  }

  apache::vhost { "graphite.${::domain}":
    port                        => 80,
    docroot                     => '/opt/graphite/webapp',
    error_log_file              => 'graphite-error.log',
    access_log_file             => 'graphite-access.log',
    wsgi_daemon_process         => graphite,
    wsgi_import_script          => '/opt/graphite/conf/graphite.wsgi',
    wsgi_process_group          => graphite,
    wsgi_daemon_process_options => {
      processes          => '5',
      threads            => '5',
      display-name       => "%{GROUP}",
      inactivity-timeout => '120',
    },
    wsgi_import_script_options  => {
      process-group      => graphite,
      application-group  => "%{GLOBAL}",
    },
    aliases                     => [
      { alias => '/content/',
        path  => '/opt/graphite/webapp/content/',
      },
      { alias => '/media/',
        path  => '@DJANGO_ROOT@/contrib/admin/media/',
      },
      { alias => '/grafana/',
        path  => '/opt/grafana/',
      } ],
    headers                     => [
      'set Access-Control-Allow-Origin "*"',
      'set Access-Control-Allow-Methods "GET, OPTIONS"',
      'set Access-Control-Allow-Headers "origin, authorization, accept"',
    ],
    wsgi_script_aliases         => {
      '/' => '/opt/graphite/conf/graphite.wsgi'
    },
    directories                 => {
      path           => '/opt/graphite/conf',
      options        => 'None',
      allow          => 'from All',
      allow_override => 'None',
      order          => 'Deny,Allow',
    },
    custom_fragment             => '<Location "/content/">

      SetHandler None

      </Location>

      <Location "/media/">

      SetHandler None

      </Location>

      <Location "/grafana/">

      SetHandler None

      </Location>'
  }

}

class graphitecluster::apache::monit {

  monit::service { "$::apache::apache_name": }

}


class graphitecluster::graphite::user {

# this user has a password which is used by carbonate, password is "carbon"

  user { 'carbon':
    ensure            =>  'present',
    uid               =>  215,
    gid               =>  215,
    shell             =>  '/bin/bash',
    home              =>  '/opt/graphite',
    comment           =>  'carbon user',
    require           =>  Group['carbon'],
    groups            => "$::apache::group",
    password          => '$6$m9ezVMol$ahmQgVh5RsfDaRfx18BumwYIhlYSbQUwopYjP2w31MKdltoK/WH.mjbNwXy0nE9ttMAtC0zW5q6dUs4Nz1BZO.',
  }

  group { 'carbon':
    gid               => 215,
  }

}

class graphitecluster::graphite::base {

  class { 'graphite':
    gr_max_updates_per_second  => 100,
    gr_timezone                => 'Europe/Berlin',
    secret_key                 => 'Mys3cr3tk3y',
    gr_web_server              => 'none',
    gr_cluster_servers         => [$::graphite1_ip,$::graphite2_ip],
    gr_install_carbonate       => True,
    gr_carbonate_servers       => ["$::graphite1_ip:2004:fan","$::graphite2_ip:2004:fan"],
    gr_user                    => 'carbon',
    gr_group                   => 'carbon',
    gr_storage_schemas         => [
      {
        name       => 'carbon',
        pattern    => '^carbon\.',
        retentions => '1m:90d'
      },
      {
        name       => 'default',
        pattern    => '.*',
        retentions => '30s:30m,1m:1d,5m:2y'
      }
    ],
    gr_apache_24               => true,
    gr_web_cors_allow_from_all => true,
    gr_carbon_daemons => {
      rep => {
        carbontype => relay,
        conf       => {
          line_receiver_interface    => '0.0.0.0',
          line_receiver_port         => 2213,
          pickle_receiver_interface  => '0.0.0.0',
          pickle_receiver_port       => 2214,
          relay_method               => consistent-hashing,
          replication_factor         => 2,
          destinations               => "$::graphite1_ip:2414:fan, $graphite2_ip:2414:fan",
          max_datapoints_per_message => 500,
          max_queue_size             => 100000,
          use_flow_control           => true
        }
      },
      fan => {
        carbontype => relay,
        conf       => {
          line_receiver_interface    => '0.0.0.0',
          line_receiver_port         => 2413,
          pickle_receiver_interface  => '0.0.0.0',
          pickle_receiver_port       => 2414,
          relay_method               => consistent-hashing,
          destinations               => 'localhost:2104:a, localhost:2204:b',
          max_datapoints_per_message => 500,
          max_queue_size             => 100000,
          use_flow_control           => true
        }
      },
      a   => {
        carbontype => cache,
        conf       => {
          cache_write_strategy      => sorted,
          max_cache_size            => inf,
          use_flow_control          => True,
          whisper_fallocate_create  => True,
          max_creates_per_minute    => 3000,
          max_updates_per_second    => 10000,
          line_receiver_interface   => '0.0.0.0',
          line_receiver_port        => 2103,
          pickle_receiver_interface => '0.0.0.0',
          pickle_receiver_port      => '2104',
          use_insecure_unpickler    => 'False',
          cache_query_interface     => '0.0.0.0',
          cache_query_port          => 7102,
          log_cache_hits            => False,
          log_cache_queue_sorts     => True,
          log_listener_connections  => True,
          log_updates               => False,
          enable_logrotation        => True,
          whisper_autoflush         => False
        }
      },
      b   => {
        carbontype => cache,
        conf       => {
          cache_write_strategy      => sorted,
          max_cache_size            => inf,
          use_flow_control          => True,
          whisper_fallocate_create  => True,
          max_creates_per_minute    => 3000,
          max_updates_per_second    => 10000,
          line_receiver_interface   => '0.0.0.0',
          line_receiver_port        => 2203,
          pickle_receiver_interface => '0.0.0.0',
          pickle_receiver_port      => '2204',
          use_insecure_unpickler    => 'False',
          cache_query_interface     => '0.0.0.0',
          cache_query_port          => 7202,
          log_cache_hits            => False,
          log_cache_queue_sorts     => True,
          log_listener_connections  => True,
          log_updates               => False,
          enable_logrotation        => True,
          whisper_autoflush         => False
        }
      }
    }
  }

  # Fix graphite for Django 1.6
  if $::osfamily == 'Debian' {
    exec { 'fix_graphite_django1.6':
      command => '/usr/bin/find /opt/graphite/webapp/graphite -iname "urls.py" -exec /bin/sed -i s/"from django.conf.urls.defaults import \*"/"from django.conf.urls import \*"/ {} \;',
      onlyif  => "/bin/grep -r 'from django.conf.urls.defaults import' /opt/graphite/webapp/graphite",
      require => Class['graphite'],
    }
  }

}

class graphitecluster::graphite::postconfig {

  file { '/opt/graphite/.ssh':
    ensure            =>  directory,
    owner             =>  carbon,
    group             =>  carbon,
    mode              =>  '0700',
    require           =>  File['/opt/graphite'],
  }

}

class graphitecluster::graphite::monit {

  monit::service::template { 'carbon-relay_rep':
    process_name  => carbon-relay_rep,
    pid_file      => '/opt/graphite/storage/carbon-relay_rep.pid',
    start_program => '/etc/init.d/carbon-relay_rep start',
    stop_program  => '/etc/init.d/carbon-relay_rep stop',
    port          => 2213,
    ip            => $::ipaddress,
  }

  monit::service::template { 'carbon-relay_fan':
    process_name  => carbon-relay_fan,
    pid_file      => '/opt/graphite/storage/carbon-relay_fan.pid',
    start_program => '/etc/init.d/carbon-relay_fan start',
    stop_program  => '/etc/init.d/carbon-relay_fan stop',
    port          => 2413,
    ip            => $::ipaddress,
  }

  monit::service::template { 'carbon-cache_a':
    process_name  => carbon-cache_a,
    pid_file      => '/opt/graphite/storage/carbon-cache-a.pid',
    start_program => '/etc/init.d/carbon-cache_a start',
    stop_program  => '/etc/init.d/carbon-cache_a stop',
    port          => 2103,
    ip            => '127.0.0.1',
  }

  monit::service::template { 'carbon-cache_b':
    process_name  => carbon-cache_b,
    pid_file      => '/opt/graphite/storage/carbon-cache-b.pid',
    start_program => '/etc/init.d/carbon-cache_b start',
    stop_program  => '/etc/init.d/carbon-cache_b stop',
    port          => 2203,
    ip            => '127.0.0.1',
  }

}

class graphitecluster::grafana::base {

  class { 'grafana':
    symlink            => true,
    datasources        => {
      'graphite'      => {
        'type'    => 'graphite',
        'url'     => "http://${::graphiteweb_vip}:80",
        'default' => 'true' # lint:ignore:quoted_booleans
      },
      'elasticsearch' => {
        'type'      => 'elasticsearch',
        'url'       => "http://${::elasticsearch_vip}:9200",
        'index'     => 'grafana-dash',
        'grafanaDB' => 'true' # lint:ignore:quoted_booleans
      },
    }
  }

}
