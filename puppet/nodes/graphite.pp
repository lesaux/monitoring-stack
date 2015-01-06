node /^graphite/ {

include monit

class {'graphitecluster::elasticsearch::base': }->
class {'graphitecluster::elasticsearch::config': }->
class {'graphitecluster::elasticsearch::monit': }->

class {'graphitecluster::apache::base': }->
class {'graphitecluster::apache::config': }->
class {'graphitecluster::graphite::user': }->
class {'graphitecluster::graphite::base': }->
class {'graphitecluster::graphite::postconfig': }->
class {'graphitecluster::grafana::base': }->
class {'graphitecluster::apache::monit': }->
class {'graphitecluster::graphite::monit': }->

class {'monitoring::graphite::client': }->
class {'monitoring::graphite::client::monit': }->

class {'monitoring::sensu::client': }->
class {'monitoring::sensu::client::monit': }

}
