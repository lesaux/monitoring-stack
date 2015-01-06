class monitoring::sensu::client {


  class { 'sensu':
    safe_mode                => false,
    manage_services          => true,
    manage_user              => true,
    rabbitmq_port            => '5671',
    rabbitmq_host            => $::rabbitmq_vip,
    rabbitmq_user            => 'sensu',
    rabbitmq_password        => 'sensu123',
    rabbitmq_vhost           => '/sensu',
    rabbitmq_ssl_private_key => 'puppet:///modules/sensucustom/certs/client_key.pem',
    rabbitmq_ssl_cert_chain  => 'puppet:///modules/sensucustom/certs/client_cert.pem',
    use_embedded_ruby        => true,
    subscriptions            => ['linux_local','linux_graphite'],
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
    ],
    client_custom            => {
      params    => {
        'graphite.cpu.iowait.warning'      => '0',
        'graphite.cpu.iowait.critical'     => '0'
      },
      keepalive => {
        'type'      => 'metric',
        'handler'   => 'flapjack'
      }
    }
  }


}


class monitoring::sensu::client::monit {

  #include monit
  monit::service { 'sensu-client': }

}
