ui            = true
cluster_addr  = "https://127.0.0.1:8201"
api_addr      = "https://127.0.0.1:8200"

storage "file" {
  path = "/openbao/file"
}

listener "tcp" {
  address       = "127.0.0.1:8200"
  tls_cert_file = "/openbao/config/certs/full-chain.pem"
  tls_key_file  = "/openbao/config/certs/private-key.pem"
}

// telemetry {
//   statsite_address = "127.0.0.1:8125"
//   disable_hostname = true
// }
