# Política para core-service
path "secret/data/core-service/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/*" {
  capabilities = ["read"]
}

path "secret/data/redis/*" {
  capabilities = ["read"]
}

path "secret/data/shared/*" {
  capabilities = ["read"]
}