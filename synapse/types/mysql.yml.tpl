  {{SERVICE}}:
   discovery: 
    method: "zookeeper"
    path:  "/nerve/services/{{SERVICE}}"
    hosts: "{{ZK_HOSTS}}"
   haproxy:
    server_options: "check inter 2s rise 3 fall 2"
    shared_frontend:
     - "acl is_service1 hdr_dom(host) -i service1.lb.example.com"
     - "use_backend service1 if is_service1"
    backend: "mode tcp"
