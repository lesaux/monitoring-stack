monitoring-stack
================

Am all in one highly availlable haproxy/graphite/sensu deployment. The provided example requires 6 boxes.

##A - The haproxy cluster (servers haproxy1 and haproxy2):

The haproxy cluster consists of two servers with identical haproxy configurations. The VIP is configured via the keepalived daemon. If one instanced was to fail, the other instance would bring up the VIP. Note that the VIP can only be seen with the "ip" command, and not with "ifconfig".

There are two running processes of haproxy.

###1) haproxy process 1.
This one is static: 
```
/usr/sbin/haproxy -D -f /etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid
```
The configuration of this instance is managed by puppet. It has frontends and backends for all services except for the redis servers.

####a) graphite_web
the frontend is running on port 80 and used to load balance in round robin graphite http queries. Apache servers are the backends. On this port you may access the default graphite webui as well as the grafana interface. The backends are graphite1 and graphite2.
####b) graphite_input
the frontend is running on port 2213 is used to ship metrics to the graphite servers in a round robin fashion. The backends are graphite replication relays also listening on port 2213. The replication relays ship data to a local "fanout" relay, and to a remote "fanout" relay on the other graphite server as well. All graphite relays (carbon-relay) are running on graphite1 and graphite2.
####c) graphite_elasticsearch
the frontend is running on port 9200 and load balances in round robin the two elasticsearch instances also running on the graphite servers. Elasticsearch is only used for storing the grafana dashboards you create. Elasticsearch data is replicated accross both elasticsearch instance by an internal mechanism to ES.
####d) rabbitmq_sensu
the frontend is running on port 5671. The backends are also running on port 5671 and are rabbitmq servers configured with ssl. The rabbitmq servers are clustered and the messages queues are replicated. The load balancing algorithm used here is also "round-robin"

###2) haproxy process 2
This one is dynamic:
```
/usr/sbin/haproxy -f /etc/haproxy/haproxy_redis.cfg -p /var/run/haproxy_redis.pid -sf
```
The configuration of this instance is managed by redishappy-haproxy. Redishappy monitors redis master/slave information from the sentinel services, and reconfigures haproxy on the fly if needed. (https://github.com/mdevilliers/redishappy : see the FAQ for the double master issue we are avoiding by using redishappy)

####a) redis_sensu
the frontend is running on port 6379, as well as the backends which are two redis servers. The redis instance is used to store the sensu events. Redis is setup in a classical master-slave fashion. Only the redis master is writable, and therefore sensu data only flows to the redis master. In addition, there is a redis monitoring daemon called "sentinel" which monitors the availlabilty of the redis master, and can promote the slave to master if the original master was to fail.
####b) redis_flapjack
the frontend is running on port 6380, as well as the backends which are also two redis instances. The setup is the same as the redis_sensu configuration, except that the xinetd script is running on port 6480.

The haproxy webui are availlable at http://haproxy1:8080/haproxy?stats and http://haproxy2:8080/haproxy?stats where you can monitor the status of all frontends and backends.
The haproxy webui for the redis services is availlable at http://haproxy1:8081/haproxy?stats and http://haproxy2:8081/haproxy?stats



##B - The graphite cluster (servers graphite1 and graphite2:

The cluster needs one instance to be up and running at any time. It is possible to poweroff or stop services on one server at a time for maintenance purposes. After a maintenance, resyncing the graphite data (whisper databases) will be necessary, although not urgent. Graphite web is able to pull missing data from a "good" server, so that no "holes" are displayed in your graphs. Resyncing graphite data will be described later. Failover is nearly immediate.
As mentioned before, the point of entry of metrics shipped by diamond is a carbon replication relay, running on both graphite servers. The data is forwarded to a local "fanout" carbon relay, and to a remote "fanout" relay on the other graphite server. When data reaches one graphite instance, it is replicated to the other one as well. The "fanout" carbon relay is used to leverage several carbon-cache instances. A carbon-cache process is bound to a single cpu, and depending on the amount of metrics that we have, we may need a second carbon-cache instance to spread the load accross two cpus. The "consistent-hashing" algorithm is used on the carbon fanout relays to insure the unicity of metrics being shipped to the carbon-caches. In our case we are using only two carbon-cache instances, but we can scale out to more if needed. In total we have four carbon-cache instances running, two per server.

The list of services running on a graphite server is the following.
carbon-relay_rep
carbon-relay_fan
carbon-cache_a
carbon-cache_b

##C - The sensu cluster (servers sensu1 and sensu2).
A sensu cluster consists of several running services. The sensu services, two redis instances, the rabbitmq server, uchiwa (a sensu dashboard which is there for convenience but should rarely be used) and flapjack - the alerting router. The sensu services are sensu-server, sensu-api and sensu-client.

###1) The Sensu server
It is responsible for orchestrating check executions, the processing of check results, and event handling. We are running two Sensu servers, and tasks are distributed amongst them automatically. Servers will inspect every check result, saving some of their information for a period of time. Check results that indicate a service failure or contain data such as metrics, will have additional context added to them, creating an event. The Sensu server passes events to handlers.

###2) The Sensu client
It runs on all of the systems we want to monitor. The client receives check execution requests, executes the checks, and publishes their results.

###3) The Sensu API
It provides a REST-like interface to Sensu’s data, such as registered clients and current events. We are running the sensu api on each sensu server. The API is capable of many actions, such as issuing check execution requests, resolving events, and removing a registered client.

###4) Remote Checks
We are running several checks which I call "remote checks". These checks have been created because of the unability to install the sensu-client on certain devices, such as network gear and the ESX infrastructures. These checks are run from the sensu-servers themselves. When we can't install a sensu-client, we usually can't install the diamond client either - but when these checks provide "perfdata" it is possible to forward these metrics to a graphite server by using a special sensu handler.

###5) Checks Handlers
We are using two main check handlers. The flapjack handler is integrated with every check, and it's job is to forward all events to flapjack.
The nagiosperfdata handler is integrated with all remote checks that provide perfdata that can be forwarded to a graphite server. This is how we collect ESX metrics and network gear metrics in graphite.

###6) Redis for sensu
As mentioned before, sensu needs a redis instance to store its data. The cluster is setup in a simple master-slave fashion, with the additional of the sentinel monitoring daemon, and the previously mentioned xinetd scripts. A redis failover can take up to 30seconds.

###7) Redis for flapjack
Flapjack also need a redis instance to store the events data.
