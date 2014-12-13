  {{SERVICE}}:
   discovery: 
    method: "zookeeper"
    path:  "/nerve/services/{{SERVICE}}"
    hosts: "{{ZK_HOSTS}}"
   haproxy:
    server_options: "check inter 2s rise 3 fall 2"
    backend: "mode tcp"
    frontend: "bind 127.0.0.1:{{PORT}}"
