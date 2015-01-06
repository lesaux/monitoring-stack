class monitoring::graphite::client {


  class { 'diamond':
    graphite_host    => $::graphiteinput_vip,
    graphite_port    => 2003,
    interval         => 30,
  }

  diamond::collector { 'NetworkCollector':}

}


class monitoring::graphite::client::monit {

  #include monit
  monit::service { 'diamond': }

}
