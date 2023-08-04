listener "tcp" {
address = "0.0.0.0:8200"
tls_disable = "true"
}

storage "raft" {
path = "./vault/data"
node_id = "node1"
}
cluster_addr = "http://104.198.215.100:8201"
api_addr = "http://104.198.215.100:8200"
