# ⚙️ Servicio Core del ERP (ms-core)

Este directorio contiene el microservicio core con la lógica de negocio del ERP.

## 📦 Repositorio

El código fuente de este servicio se encuentra en:

**🔗 [https://github.com/tu-organizacion/erp-ms-core](https://github.com/tu-organizacion/erp-ms-core)**

## 🚀 Clonar el submódulo

Si no tienes el código del servicio, clónalo usando:

```bash
# Desde la raíz del proyecto
git submodule add https://github.com/tu-organizacion/erp-ms-core.git BUSSINES/ms-core

# O actualizar todos los submódulos
git submodule update --init --recursive
```

## 📖 Documentación

Para más información sobre el servicio core, consulta el README en el repositorio:

- [Documentación completa](https://github.com/tu-organizacion/erp-ms-core#readme)
- [API Documentation](https://github.com/tu-organizacion/erp-ms-core/wiki/API)
- [Modelos de Datos](https://github.com/tu-organizacion/erp-ms-core/wiki/Models)

## 🛠️ Stack Tecnológico

- NestJS
- TypeORM
- PostgreSQL
- Redis
- Event-driven architecture

## 🔧 Desarrollo Local

```bash
cd BUSSINES/ms-core
npm install
npm run start:dev
```

## 📝 Variables de Entorno

El servicio utiliza las siguientes variables (gestionadas por Vault):

- `API_KEY`
- `ENCRYPTION_KEY`
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- `REDIS_HOST`, `REDIS_PORT`
- `VAULT_ADDR`, `VAULT_TOKEN`

## 🔗 Enlaces Relacionados

- [Main ERP Repository](../)
- [Auth Service](../BFF+AUTH/)
- [Frontend](../FRONTEND/)