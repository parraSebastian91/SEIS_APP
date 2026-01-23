# 🔐 Servicio de Autenticación (ms-auth)

Este directorio contiene el microservicio de autenticación del ERP.

## 📦 Repositorio

El código fuente de este servicio se encuentra en:

**🔗 [https://github.com/parraSebastian91/ms-auth](https://github.com/parraSebastian91/ms-auth)**

## 🚀 Clonar el submódulo

Si no tienes el código del servicio, clónalo usando:

```bash
# Desde la raíz del proyecto
git submodule add https://github.com/parraSebastian91/ms-auth.git BFF+AUTH/ms-auth

# O actualizar todos los submódulos
git submodule update --init --recursive
```

## 📖 Documentación

Para más información sobre el servicio de autenticación, consulta el README en el repositorio:

- [Documentación completa](https://github.com/parraSebastian91/ms-auth#readme)
- [API Documentation](https://github.com/parraSebastian91/ms-auth/wiki/API)
- [Configuración de Vault](https://github.com/parraSebastian91/ms-auth/wiki/Vault)

## 🛠️ Stack Tecnológico

- NestJS
- TypeORM
- PostgreSQL
- Redis
- JWT
- Passport

## 🔧 Desarrollo Local

```bash
cd BFF+AUTH/ms-auth
npm install
npm run start:dev
```

## 📝 Variables de Entorno

El servicio utiliza las siguientes variables (gestionadas por Vault):

- `JWT_SECRET`
- `JWT_EXPIRATION`
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `REDIS_HOST`, `REDIS_PORT`
- `VAULT_ADDR`, `VAULT_TOKEN`

## 🔗 Enlaces Relacionados

- [Main ERP Repository](../)
- [Core Service](../BUSSINES/)
- [Frontend](../FRONTEND/)