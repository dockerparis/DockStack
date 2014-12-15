#DockStack

DockStack is a Docker ambassador based on SmartStack http://nerds.airbnb.com/smartstack-service-discovery-cloud/. It uses zookeeper or etcd (WIP) as discovery service.

DockStack is composed of two tools:
- Nerve, a service registration daemon that performs health checks https://github.com/airbnb/nerve
- Synapse, a transparent service discovery framework that proxyfies the connections. It uses HAProxy to proxy the connections https://github.com/airbnb/synapse

Both tools use a YAML config file, which is not ideal to use with Docker. A wrapper script heavily simplifies the generation of this files via CLI.

##Setup
####Zookeeper
You can easily setup Zookeeper on your hosts using https://registry.hub.docker.com/u/thefactory/zookeeper-exhibitor/

####MySQL
Any other service will work

1. Spawn a MySQL container
```
host1 $ docker run -d --name mysql -p :3306 -e MYSQL_ROOT_PASSWORD=test mysql
```
2. Create an healt-check user
```
host1 $ docker exec -ti mysql /bin/bash
# mysql -u root -p
mysql> INSERT INTO mysql.user (Host,User) values ('%', 'haproxy_check'); FLUSH PRIVILEGES;
```
3. Temporary fix to avoid the following error `ERROR 1129 (HY000): Host '172.17.42.1' is blocked because of many connection errors; unblock with 'mysqladmin flush-hosts'`
```
# mysqladmin -u root -p flush-hosts
```
####Nerve
```
host1 $ docker run -ti --rm -e ZK_HOSTS=<zk_hosts,comma-separated> -e SERVICE_PORT=$(docker port mysql | cut -d : -f 2) -e SERVICE_HOST=<HOST_IP> -e SERVICE=path/test nerve --tcp --zk
```

####Synapse
```
host2 $ docker run -ti --rm -e ZK_HOSTS=<zk_hosts,comma-separated> --name synapse synapse --mysql service1:path/test:3306:haproxy_check
```

####Testing
Here the magic happens! (Running a mysql image, as it carries by default mysql-client)
```
host2 $ docker run -ti --rm --link synapse:db mysql:latest /bin/bash
# mysql -u root -h db
```

The connection is proxified transparently by HAProxy

##Authors
- [Alessandro Siragusa](https://github.com/asiragusa)
- [Yves-Marie Saout](https://github.com/dw33z1lP)
- [Laurent Vergnaud](https://github.com/laurentvergnaud)

##Special thanks
To [Jérôme Petazzoni](https://github.com/jpetazzo) for the great idea!
