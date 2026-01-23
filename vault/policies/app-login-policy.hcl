# Política para app-login (solo lectura de configs públicas)
path "secret/data/app-login/*" {
  capabilities = ["read"]
}

path "secret/data/shared/public/*" {
  capabilities = ["read"]
}