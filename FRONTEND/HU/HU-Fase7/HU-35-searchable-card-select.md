# HU-35 — Componente `SearchableCardSelect` + `OrganizationSelector`

> **Fase**: 7 — `shared-utils` (componente genérico) + `seis-portal` (primera instancia) | **Ruta**: global, usado en top-navbar y en módulos de gestión de organización

---

## Descripción

`SearchableCardSelect` es un **combobox / select buscable avanzado** con tarjetas visuales. Es el componente más reutilizable del sistema: su primera instancia es el `OrganizationSelector` de la top-navbar, pero también es necesario en HU-20 (perfil de org, cambiar líder de grupo) y HU-21 (gestor de org, asignar miembros a grupos).

El componente vive en `shared-utils` para ser consumido por el Shell y por cualquier MFE sin duplicar lógica.

---

## Criterios de Aceptación

### CA-01 · Anatomía general

```
┌─────────────────────────────────────┐  ← Trigger (solo lectura)
│  [🏢]  Constructora ABC S.A.    [▾] │  ← ítem activo + chevron
└─────────────────────────────────────┘
          ↓ clic abre panel flotante
┌─────────────────────────────────────┐
│  🔍 buscar organización...          │  ← input sticky en la parte superior
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │  Constructora ABC S.A.      │[●] │  ← ítem seleccionado (efecto pulse)
│  │  Cedente · Añadido 01/2024  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │  Inmobiliaria XYZ           │    │
│  │  Cedente · Añadido 03/2024  │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### CA-02 · Trigger (estado reposo)

- El trigger es **siempre de solo lectura** — nunca se convierte en input de texto al hacer clic.
- Muestra: ícono configurable (prop `@Input() icon`) + nombre del ítem activo.
- Si no hay selección: muestra el placeholder configurable (`@Input() placeholder`).
- Chevron `▾` indica que es desplegable.

### CA-03 · Apertura del panel

- Al hacer clic en el trigger: se abre el panel flotante y el **foco se transfiere automáticamente** al input de búsqueda dentro del panel.
- Si había una selección previa: el ítem correspondiente recibe foco automático y activa el **efecto pulse**.
- El panel se despliega debajo del trigger (o arriba si no hay espacio bajo).

### CA-04 · Panel flotante

Estructura interna del panel (de arriba hacia abajo):
1. **Input de búsqueda** (sticky en la parte superior del panel): ícono de lupa + placeholder `"Buscar [label]..."` (configurable). Foco automático al abrir.
2. **Lista de tarjetas** scrollable debajo del input.

### CA-05 · Filtrado en tiempo real

- Al escribir en el input: la lista filtra dinámicamente por coincidencia **parcial** en el nombre principal (`case-insensitive`).
- El filtrado ocurre en el cliente (sin llamadas HTTP) sobre la lista de ítems recibida por `@Input()`.
- Si no hay coincidencias: estado vacío `"Sin resultados."` centrado en la lista.

### CA-06 · `ItemCard` — Anatomía de cada tarjeta

Layout horizontal (`flexbox`):

| Zona | Contenido |
|------|-----------|
| Izquierda | **Título principal** (nombre del ítem) en texto destacado. Debajo: **texto secundario** (meta-información, ej. `"Cedente · Añadido 01/2024"`). |
| Derecha | Avatar circular pequeño: logo de la entidad si hay `avatarUrl`; iniciales del nombre si no hay imagen. |

### CA-07 · Selección y cierre

| Acción | Resultado |
|--------|-----------|
| Clic en una tarjeta | Confirma selección → actualiza el trigger → cierra el panel → emite `(selectionChange)` |
| `Enter` sobre ítem con foco | Confirma selección → ídem |
| `Escape` | Cierra el panel sin cambiar la selección |
| Clic fuera del componente | Cierra el panel sin cambiar la selección |

### CA-08 · Navegación por teclado

| Tecla | Acción |
|-------|--------|
| `ArrowDown` | Mueve el foco al siguiente ítem de la lista |
| `ArrowUp` | Mueve el foco al ítem anterior |
| `Enter` | Confirma el ítem con foco activo |
| `Escape` | Cierra el panel sin aplicar cambios |

El foco del teclado es independiente de la selección activa: navegar con teclas no cambia la selección hasta presionar `Enter`.

### CA-09 · Efecto pulse (estado de foco activo)

El ítem con foco activo (por teclado, o por ser la selección previa al abrir el panel) aplica una animación CSS en bucle:
- Expansión suave de `box-shadow` o parpadeo de opacidad.
- El efecto es sutil, no intrusivo — su objetivo es identificar inequívocamente el foco.
- La animación se detiene cuando el foco se mueve a otro ítem.

### CA-10 · API del componente genérico

El componente acepta una lista tipada genérica:

```typescript
interface SearchableCardItem {
  id: string;
  name: string;         // Título principal de la tarjeta
  meta?: string;        // Texto secundario (ej. "Cedente · Añadido 01/2024")
  avatarUrl?: string;   // URL del avatar; si no hay, se muestran iniciales
}
```

**Inputs:**
- `@Input() items: SearchableCardItem[]` — lista de ítems a mostrar.
- `@Input() selectedId: string | null` — ID del ítem actualmente seleccionado.
- `@Input() placeholder: string` — texto del trigger cuando no hay selección.
- `@Input() searchPlaceholder: string` — texto del input de búsqueda dentro del panel.
- `@Input() icon: string` — nombre del ícono del trigger (ej. `"business"`).

**Outputs:**
- `@Output() selectionChange: EventEmitter<SearchableCardItem>` — emitido al confirmar una selección.

---

## `OrganizationSelector` — Primera instancia

El `OrganizationSelector` es el `SearchableCardSelect` configurado para el cambio de organización activa en la top-navbar:

- `items`: organizaciones del usuario (obtenidas de `SessionService`).
- `selectedId`: `activeOrganizationId` del `SessionService`.
- `placeholder`: `"Selecciona una organización"`.
- `searchPlaceholder`: `"Buscar organización..."`.
- `icon`: ícono de edificio (`🏢` o Material Icon `business`).
- Al `selectionChange`: actualiza `activeOrganizationId` + `activeOrganizationName` en el `SessionService`.

La meta de cada ítem de organización sigue el formato: `"[Tipo] · Añadido [MM/YYYY]"` (ej. `"Cedente · Añadido 01/2024"`).

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Lista de ítems vacía** | El trigger se muestra con el placeholder. Al abrir el panel, se muestra el empty state `"Sin resultados."` directamente (sin input de búsqueda o con input deshabilitado). |
| EB-02 | **Un solo ítem en la lista** | El panel se abre igualmente. No se omite el componente para consistencia visual (EB-01 de HU-34). |
| EB-03 | **El texto de búsqueda no coincide con ningún ítem** | Empty state `"Sin resultados."` dentro del panel. El input de búsqueda permanece activo para seguir escribiendo. |
| EB-04 | **El ítem seleccionado ya no está en la lista** | El trigger muestra el placeholder. No lanzar error. (Puede ocurrir si el usuario fue removido de una org entre sesiones.) |
| EB-05 | **`avatarUrl` es una URL rota** | Fallback a iniciales del `name`. Implementar con `(error)` binding en el `<img>`. |

---

## Componentes

| Componente | Ubicación | Descripción |
|------------|-----------|-------------|
| `SearchableCardSelectComponent` | `shared-utils` | Componente contenedor (combobox genérico) |
| `SearchableCardTriggerComponent` | `shared-utils` | Trigger: estado reposo con ícono + nombre + chevron |
| `SearchableCardPanelComponent` | `shared-utils` | Panel flotante: input sticky + lista scrollable |
| `SearchableCardItemComponent` | `shared-utils` | Tarjeta individual: nombre, meta, avatar, efecto pulse |
| `OrganizationSelectorComponent` | `seis-portal` | Instancia de `SearchableCardSelect` configurada para orgs |

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 7 — shared-utils + seis-portal | Consumidores: HU-20, HU-21, HU-34*
