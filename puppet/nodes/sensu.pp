node /^sensu/ {

#nothing to import, no remote checks in this example atm.
#import '../sensucustom-remote-checks/*.pp'

include monit

class {'sensucluster::redis::base': }->
class {'sensucluster::redis::sensu': }->
class {'sensucluster::redis::sensu::monit': }->
class {'sensucluster::redis::flapjack': }->
class {'sensucluster::redis::flapjack::monit': }->
class {'sensucluster::redis::sentinel': }->

class {'sensucluster::rabbitmq::base': }->
class {'sensucluster::rabbitmq::config': }->
class {'sensucluster::rabbitmq::monit': }->

class {'sensucluster::sensu::base': }->
class {'sensucluster::sensu::monit': }->
class {'sensucluster::sensu::dashboard': }->
class {'sensucluster::sensu::dashboard::monit': }->
class {'sensucluster::sensu::subscriptions': }->
class {'sensucluster::sensu::custom': }->

class {'sensucluster::flapjack::base': }->
class {'sensucluster::flapjack::config': }->
class {'sensucluster::flapjack::monit': }->

class {'sensucluster::postfix::base': }->
class {'sensucluster::postfix::monit': }->

class {'monitoring::graphite::client': }->
class {'monitoring::graphite::client::monit': }

}
