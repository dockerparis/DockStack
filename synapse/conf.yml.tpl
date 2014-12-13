{{SYN_BALANCE=roundrobin}} 
haproxy:
  reload_command: "service haproxy reload"
  config_file_path: "/etc/haproxy/haproxy.cfg"
  socket_file_path: "/var/run/haproxy.sock"
  global:
   - "daemon"
   - "user    haproxy"
   - "group   haproxy"
   - "maxconn 4096"
   - "log     127.0.0.1 local2 notice"
   - "stats   socket /var/run/haproxy.sock"
  defaults:
   - "log      global"
   - "balance  {{SYN_BALANCE}}"
