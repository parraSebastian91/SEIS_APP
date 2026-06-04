# HU-13 — `shared-utils`: SessionService y Modelos Base

---

## Historia de Usuario

**Yo como** desarrollador de cualquier MFE del monorepo (`seis-mfe-*`) o del Shell (`seis-portal`),
**Quiero** importar desde `shared-utils` un `SessionService` que exponga el estado de sesión del usuario autenticado como Angular Signals, junto con los modelos TypeScript compartidos,
**Para** acceder a los datos del usuario activo y su organización desde cualquier punto de la aplicación sin duplicar lógica, sabiendo que todos los MFEs consumen la misma instancia en memoria gracias al singleton de Module Federation.

---

## Contexto técnico

`shared-utils` es la librería Angular del workspace multi-project `seis-app-frontend`. Se declara como `singleton: true` en el shared scope de Module Federation, por lo que Shell y todos los MFEs comparten la misma instancia del servicio en runtime.

El patrón de state global vía MF shared singleton es válido y ampliamente usado. Como refinamiento futuro se puede aplicar scope isolation por MFE; por ahora el `SessionService` es accesible a todos los módulos cargados.

---

## Criterios de Aceptación

### CA-01 · Modelos TypeScript exportados desde `shared-utils`

La librería debe exportar al menos las siguientes interfaces (ajustables a medida que el backend los fija):

```ts
// libs/shared-utils/src/lib/models/user.model.ts
export interface User {
  id: string;
  correo: string;
  nombre: string;
  apellido: string;
  username: string;
  avatarUrl?: string;
  rol: UserRole;
}

export type UserRole =
  | 'SUPER_ADMIN' | 'ADMIN' | 'USR_STD' | 'SUPERVISOR' | 'READ_ONLY'
  | 'CLIENTE_CEDENTE' | 'EJECUTIVO_FINANCIADORA' | 'ADMIN_FINANCIADORA'
  | 'ADMIN_CEDENTE' | 'ADMIN_BROKER' | 'EJECUTIVO_BROKER';
```

```ts
// libs/shared-utils/src/lib/models/organization.model.ts
export interface Organization {
  id: string;
  uuid: string;
  nombre: string;
  rut: string;
  tipo: 'CEDENTE' | 'FINANCIERA' | 'BROKER';
  logoUrl?: string;
}
```

```ts
// libs/shared-utils/src/lib/models/session.model.ts
export interface SessionState {
  user: User | null;
  activeOrg: Organization | null;
  isAuthenticated: boolean;
}
```

- Todos los modelos deben re-exportarse desde el `index.ts` público de la librería.

### CA-02 · `SessionService` con Angular Signals

```ts
// libs/shared-utils/src/lib/services/session.service.ts
@Injectable({ providedIn: 'root' })
export class SessionService {
  // Signals de solo lectura expuestos al exterior
  readonly user     = computed(() => this.#state().user);
  readonly activeOrg = computed(() => this.#state().activeOrg);
  readonly isAuthenticated = computed(() => this.#state().isAuthenticated);
  readonly userRole = computed(() => this.#state().user?.rol ?? null);

  // Signal privado con estado completo
  readonly #state = signal<SessionState>({
    user: null,
    activeOrg: null,
    isAuthenticated: false,
  });

  setSession(user: User, activeOrg: Organization | null): void { ... }
  setActiveOrg(org: Organization): void { ... }
  clearSession(): void { ... }
}
```

- Los signals expuestos deben ser **de solo lectura** (`computed` o `asReadonly()`). Los MFEs no pueden mutar el estado directamente — solo el Shell y los interceptores HTTP llaman a los métodos de escritura.
- `setSession` debe actualizar `user`, `activeOrg` e `isAuthenticated` en una sola operación atómica.
- `clearSession` debe resetear todo el estado a los valores nulos del estado inicial.

### CA-03 · `SessionService` es inyectable en un MFE sin error

Prueba mínima de integración:
1. En cualquier componente de `seis-mfe-publicador-facturas`, inyectar `SessionService` desde `shared-utils`.
2. Leer `sessionService.user()` y `sessionService.isAuthenticated()`.
3. No debe aparecer ningún error en consola sobre "multiple instances" ni "NullInjector".

### CA-04 · `shared-utils` declarada como singleton en Module Federation

En el `webpack.config.js` de todos los proyectos que la usan (Shell + 4 MFEs), `shared-utils` debe aparecer en el bloque `shared` con `singleton: true`:

```js
shared: {
  ...shareAll({ singleton: true, strictVersion: true, requiredVersion: 'auto' }),
  'shared-utils': { singleton: true, strictVersion: false },
}
```

- Sin esta configuración, cada MFE cargaría su propia instancia del servicio y el estado no se compartiría.

### CA-05 · El estado de sesión persiste al navegar entre MFEs

Prueba funcional:
1. Shell inicializa sesión (`setSession`) al recibir el callback PKCE.
2. Usuario navega de `/publicador` a `/ofertador` (cambio de MFE remoto).
3. En el MFE de ofertador, `sessionService.user()` debe devolver el mismo objeto que en publicador.
4. `sessionService.isAuthenticated()` debe seguir siendo `true`.

---

## Casos de Borde

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Hidratación del estado en recarga** | Si el usuario recarga la página (`F5`), los Signals se resetean a `null`. ¿El Shell debe rellenar el estado consultando la sesión activa al backend (`GET /security/session` o similar) antes de renderizar? Esto conecta con HU-15 (guard de rutas). |
| EB-02 | **Multi-organización** | Un usuario puede pertenecer a múltiples organizaciones. `activeOrg` almacena solo la activa. ¿El listado de todas las organizaciones del usuario también vive en `SessionService` o en un `ProfileService` separado? |
| EB-03 | **Señal de org activa compartida** | Si el usuario cambia de organización activa desde `mfe-gestion-usuario`, ¿todos los demás MFEs que estén escuchando `activeOrg()` deben reaccionar automáticamente (recargando datos)? Definir si es comportamiento esperado o si requiere navegación forzada. |
| EB-04 | **strictVersion en MF shared** | Si Shell compila con `shared-utils@1.0.0` y un MFE con `@1.1.0`, `strictVersion: false` en el shared config evita el error pero puede generar inconsistencias. ¿Se aplica `strictVersion: true` en su lugar? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Usar `signal()` + `computed()` de `@angular/core` (Angular 17+). No usar `BehaviorSubject` para este servicio.
- El `SessionService` **no** hace llamadas HTTP. Solo mantiene estado. Los llamados a la API de sesión los hacen los interceptores (HU-14) y el guard (HU-15).
- Si `shared-utils` ya existe con implementación previa usando `BehaviorSubject`, la migración a Signals puede hacerse gradualmente: exponer ambas APIs durante la transición y deprecar la basada en RxJS.
- Los `UserRole` deben coincidir exactamente con los valores del enum en base de datos documentados en §2 del spec.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 1 — Infraestructura base*
