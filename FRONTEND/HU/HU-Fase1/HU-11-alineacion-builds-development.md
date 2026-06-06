# HU-11 — Alineación de Build Configurations a Development

---

## Historia de Usuario

**Yo como** desarrollador del equipo frontend,
**Quiero** que todos los proyectos del monorepo `seis-app-frontend` se compilen con `--configuration development` en sus respectivos Dockerfiles,
**Para** poder acceder a source maps, logs descriptivos y mensajes de error completos durante el desarrollo y testing, sin perder tiempo debuggeando bundles minificados.

---

## Contexto técnico

Los Dockerfiles actuales tienen inconsistencia en la configuración de build:

| Proyecto Angular | Dockerfile | Estado actual | Estado objetivo |
|-----------------|-----------|:-------------:|:---------------:|
| `seis-portal` | `dockerfile.portal` | `development` | ✅ correcto |
| `seis-mfe-gestion-usuario` | `dockerfile.mfe-gestion-usuario` | `production` | ⚠️ cambiar |
| `seis-mfe-dashboard-facturas` | `dockerfile.mfe-dashboard-facturas` | `production` | ⚠️ cambiar |
| `seis-mfe-publicador-facturas` | `dockerfile.mfe-publicador-facturas` | `development` | ✅ correcto |
| `seis-mfe-ofertador-facturas` | `dockerfile.mfe-ofertador-facturas` | `development` | ✅ correcto |

---

## Criterios de Aceptación

### CA-01 · Dockerfile `mfe-gestion-usuario` en development
- La línea de build debe quedar:
  ```
  npx ng build seis-mfe-gestion-usuario --configuration development --base-href=/mfe-gestion-usuario/
  ```

### CA-02 · Dockerfile `mfe-dashboard-facturas` en development
- La línea de build debe quedar:
  ```
  npx ng build seis-mfe-dashboard-facturas --configuration development --base-href=/mfe-dashboard-facturas/
  ```

### CA-03 · Todos los contenedores levantan correctamente tras el cambio
- `docker compose up --build` para ambos servicios debe completar sin errores.
- Los `remoteEntry.json` de ambos MFEs deben ser accesibles en sus respectivos puertos (`localhost:8084`, `localhost:8085`).

### CA-04 · Source maps disponibles en browser DevTools
- Al abrir las DevTools del navegador con alguno de los MFEs cargados, los archivos TypeScript originales deben ser visibles en la pestaña Sources.

---

## Casos de Borde

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Tamaño del bundle** | `development` genera bundles sin minificar, significativamente más grandes. ¿Hay alguna restricción de tamaño en el servidor donde se despliegan que impida esto? |
| EB-02 | **Rama de producción** | ¿Existe o existirá una rama/pipeline de CI donde los builds deben ser `production`? Si es así, la configuración de Dockerfiles debe separarse por entorno (ej: `dockerfile.mfe-*.prod`). |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Este cambio aplica **solo a los Dockerfiles** del monorepo `seis-app-frontend`. No modifica código Angular.
- `app-login` tiene su propio Dockerfile independiente y no está incluido en esta HU.
- En el futuro, cuando se prepare el pipeline de producción, estos Dockerfiles deberán tener una variante con `--configuration production`. Se recomienda nombrarlos `dockerfile.mfe-*.prod` para diferenciarlos.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 1 — Infraestructura base*
