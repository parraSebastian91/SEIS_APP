# Política para auth-service
path "secret/data/auth-service/*" {
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