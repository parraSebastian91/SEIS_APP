# HU-12 — Bootstrap del Shell con Module Federation Manifest

---

## Historia de Usuario

**Yo como** desarrollador del Shell (`seis-portal`),
**Quiero** que la aplicación cargue el `federation.manifest.json` en runtime antes de inicializar Angular,
**Para** que el Shell descubra dinámicamente las URLs de los MFEs remotos sin hardcodear ningún hostname en el bundle compilado, permitiendo desplegar el mismo artefacto en distintos entornos cambiando solo el manifest.

---

## Contexto técnico

El modo **manifest-based** de `@angular-architects/module-federation` requiere que el bootstrap de Angular se haga de forma asíncrona: primero se carga y resuelve el manifest, luego se inicializa la app. Si el bootstrap es síncrono (el default de Angular), `loadRemoteModule` falla porque no encuentra las entradas del manifest.

Además, el Dockerfile del portal debe sobreescribir el manifest de desarrollo con el de producción en build time, manteniendo el mismo nombre de archivo en el contenedor.

---

## Criterios de Aceptación

### CA-01 · `main.ts` con bootstrap asíncrono vía manifest

El archivo `projects/seis-portal/src/main.ts` debe implementar el siguiente patrón:

```ts
import { loadManifest } from '@angular-architects/module-federation';

loadManifest('/federation.manifest.json')
  .then(() => import('./bootstrap'))
  .catch(err => console.error('Error cargando federation manifest:', err));
```

Y `bootstrap.ts` contiene el `bootstrapApplication(AppComponent, appConfig)` original.

- La app no debe arrancar hasta que `loadManifest()` resuelva.
- Si el manifest no puede cargarse (404, red caída), debe loggear el error en consola — sin pantalla blanca silenciosa.

### CA-02 · `federation.manifest.json` para entorno de desarrollo

Archivo en `projects/seis-portal/public/federation.manifest.json`:

```json
{
  "mfeGestionUsuario":    "http://localhost:8084/remoteEntry.json",
  "mfeDashboardFacturas": "http://localhost:8085/remoteEntry.json",
  "mfePublicadorFacturas":"http://localhost:8086/remoteEntry.json",
  "mfeOfertadorFacturas": "http://localhost:8087/remoteEntry.json"
}
```

- Las claves deben coincidir exactamente con los `remoteName` usados en `app.routes.ts`.
- Los valores apuntan a `remoteEntry.json` (JSON, no `.js`).

### CA-03 · `federation.manifest.prod.json` para entorno de producción

Archivo en `projects/seis-portal/public/federation.manifest.prod.json`:

```json
{
  "mfeGestionUsuario":    "https://<DOMINIO>/mfe-gestion-usuario/remoteEntry.json",
  "mfeDashboardFacturas": "https://<DOMINIO>/mfe-dashboard-facturas/remoteEntry.json",
  "mfePublicadorFacturas":"https://<DOMINIO>/mfe-publicador-facturas/remoteEntry.json",
  "mfeOfertadorFacturas": "https://<DOMINIO>/mfe-ofertador-facturas/remoteEntry.json"
}
```

> Los dominios reales de producción deben completarse cuando estén definidos. Por ahora el archivo puede tener los placeholders `<DOMINIO>`.

### CA-04 · Dockerfile del portal sobreescribe manifest en build

La línea en `dockerfile.portal` que copia el manifest de producción debe ejecutarse **después** del `ng build` y **antes** del stage Nginx:

```dockerfile
RUN cp projects/seis-portal/public/federation.manifest.prod.json \
       dist/seis-portal/browser/federation.manifest.json
```

- El contenedor final (`nginx:alpine`) nunca debe contener el `federation.manifest.prod.json` como archivo separado — solo el `federation.manifest.json` sobreescrito.

### CA-05 · Rutas del Shell usan `type: 'manifest'`

El archivo `projects/seis-portal/src/app/app.routes.ts` debe usar `type: 'manifest'` con `remoteName` (no `remoteEntry` con URL):

```ts
loadRemoteModule({
  type: 'manifest',
  remoteName: 'mfePublicadorFacturas',
  exposedModule: './PublicadorRoutes',
})
```

- Aplicar el mismo patrón para los 4 MFEs remotos (`mfeGestionUsuario`, `mfeDashboardFacturas`, `mfePublicadorFacturas`, `mfeOfertadorFacturas`).

### CA-06 · Shell levanta y carga un MFE remoto correctamente

Prueba de integración mínima:
1. Levantar `docker compose up app-portal app-mfe-publicador-facturas`.
2. Navegar a `http://localhost:8083/publicador`.
3. El MFE debe cargar sin errores en consola relacionados con Module Federation.
4. En Network DevTools, verificar que `federation.manifest.json` fue cargado antes que `remoteEntry.json`.

---

## Casos de Borde

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **MFE no disponible al cargar el manifest** | Si uno de los MFEs está caído cuando el Shell hace `loadManifest`, ¿la app debe fallar completamente o cargar igualmente y mostrar un error solo al navegar a esa ruta? |
| EB-02 | **Caché del manifest en browser** | El manifest se sirve sin caché (`Cache-Control: no-store`) desde el Nginx del portal? Confirmar que el portal tiene configurada esa cabecera para `/federation.manifest.json`. |
| EB-03 | **Hot reload en desarrollo local** | Al correr los MFEs con `ng serve` (sin Docker) en desarrollo, ¿el manifiesto apunta a `localhost:PORT` o a los contenedores Docker? Definir cuál es el flujo preferido de desarrollo local. |
| EB-04 | **Versión de remoteEntry desactualizada** | Si el Shell tiene el manifest cacheado y un MFE se redespliega con una versión incompatible de las dependencias compartidas, ¿cómo se detecta y resuelve? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- `loadManifest` es una función de `@angular-architects/module-federation` que hace un `fetch` al JSON y popula el registro interno antes de que Angular inicialice.
- El split en `main.ts` + `bootstrap.ts` es el patrón oficial recomendado por la librería para evitar problemas de inicialización con Webpack Module Federation.
- Si el Shell ya tiene un `main.ts` existente con `bootstrapApplication` directo, refactorizarlo a este patrón no rompe ninguna funcionalidad existente.
- El Nginx del portal (`nginx.conf`) debe tener configurado `Cache-Control: no-store` para `federation.manifest.json` (análogo a como los nginx de los MFEs lo hacen para sus `remoteEntry.json`).

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 1 — Infraestructura base*
