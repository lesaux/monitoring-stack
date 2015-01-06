node /^haproxy/ {

class {'haproxycluster::keepalive::base': }->
class {'haproxycluster::keepalive::config': }->

class {'haproxycluster::haproxy::base': }->
class {'haproxycluster::haproxy::admin': }->

class {'haproxycluster::redishappy::config': } ->

class {'haproxycluster::haproxy::graphiteweb': }->
class {'haproxycluster::haproxy::graphiteinput': }->
class {'haproxycluster::haproxy::elasticsearch': }->
class {'haproxycluster::haproxy::rabbitmqsensu': }->

class {'haproxycluster::haproxy::members': }->

class {'monitoring::graphite::client': }->
class {'monitoring::sensu::client': }

class {'sensucluster::redis::base': }->
class {'sensucluster::redis::sentinel': }

}
