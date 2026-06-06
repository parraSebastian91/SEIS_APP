# HU-36 — Sistema de Notificaciones In-App (`NotificationsSidebar`)

> **Fase**: 7 — `seis-portal` (Shell) | **Rol**: todos los usuarios autenticados | **Refs**: §10.0 – §10.6

---

## Historias de Usuario

- **`US-N01`** — Como usuario, quiero ver todas mis notificaciones en un panel centralizado, para no perder ningún evento relevante de mis operaciones.
- **`US-N02`** — Como usuario, quiero filtrar las notificaciones por categoría (Facturas, Mensajes, Alertas), para enfocarme en lo que me interesa en cada momento.
- **`US-N03`** — Como usuario, quiero que las notificaciones no leídas se marquen automáticamente al verlas, para que el badge sea siempre un reflejo real de lo que aún no he revisado.
- **`US-N04`** — Como usuario, quiero tocar una notificación y que me lleve directamente al contexto relevante, para no tener que navegar manualmente hasta la factura o el chat.
- **`US-N05`** — Como usuario, quiero limpiar todas las notificaciones leídas de una vez, para mantener el panel organizado.
- **`US-N06`** — Como usuario en mobile, quiero que el panel de notificaciones sea un bottom sheet expandible, para acceder cómodamente desde el teléfono.

---

## Contexto técnico

Hay **dos superficies de notificación** distintas en la plataforma:

| Panel | Componente | Scope | Trigger |
|-------|-----------|-------|---------|
| **Global** | `NotificationsSidebar` | Todas las notificaciones del usuario | Botón `🔔` en top-navbar |
| **Por factura** | `InvoiceNotificationSidebar` | Solo actividad de una factura específica | Botón "Notificaciones" en footer de `factura-view` (HU-24) |

Esta HU especifica el panel **global**. El panel por factura reutiliza el mismo feed filtrado por `relatedInvoiceId`.

**Endpoints:**
- `GET /api/core/notificaciones?categoria={categoria}&page={page}&size={size}` — lista paginada.
- `PATCH /api/core/notificaciones/read` con `{ ids: string[] }` — marcar como leídas.
- `DELETE /api/core/notificaciones/read-all` — limpiar todas las leídas.

**WebSocket**: canal `usuario:{userId}` emite evento `notificacion.nueva` con la notificación completa. El cliente la agrega al feed en tiempo real sin recargar.

---

## Criterios de Aceptación

### CA-01 · Modelo de datos de una notificación

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `string` | UUID |
| `category` | `'factura' \| 'mensaje' \| 'alerta'` | Categoría del evento |
| `type` | `string` | Tipo específico (ver CA-02) |
| `title` | `string` | Texto en negrita |
| `body` | `string` | Texto secundario descriptivo |
| `read` | `boolean` | `false` al crear; `true` al marcar como leída |
| `createdAt` | `datetime` | Timestamp del evento |
| `relatedInvoiceId` | `string?` | Factura relacionada (opcional) |
| `relatedOfferId` | `string?` | Oferta relacionada (opcional) |
| `actionUrl` | `string` | Ruta de navegación al tocar |

### CA-02 · Catálogo de tipos de eventos

| `type` | Categoría | Destinatario | Título | Body |
|--------|-----------|-------------|--------|------|
| `invoice.offer_received` | `factura` | Cliente | `"Nueva oferta recibida"` | `"[Ejecutivo] hizo una oferta sobre factura #[folio]"` |
| `invoice.offer_accepted` | `factura` | Ejecutivo | `"Oferta aceptada"` | `"Tu oferta sobre factura #[folio] fue aceptada"` |
| `invoice.offer_rejected` | `factura` | Ejecutivo | `"Oferta rechazada"` | `"Tu oferta sobre factura #[folio] fue rechazada"` |
| `invoice.published` | `factura` | Cliente | `"Factura publicada"` | `"Tu factura #[folio] ya es visible para ejecutivos"` |
| `invoice.rejected` | `factura` | Cliente | `"Factura rechazada"` | `"Tu factura #[folio] fue rechazada: [motivo]"` |
| `invoice.financed` | `factura` | Cliente | `"Operación financiada"` | `"La factura #[folio] fue financiada por [Ejecutivo]"` |
| `invoice.payment_notified` | `factura` | Cliente | `"Depósito notificado"` | `"[Ejecutivo] notificó el depósito de factura #[folio]. Verifica en tu banco."` |
| `invoice.paid` | `factura` | Ejecutivo | `"Pago confirmado"` | `"El cliente confirmó la recepción del depósito en factura #[folio]"` |
| `invoice.expiring_soon` | `alerta` | Cliente | `"Factura próxima a vencer"` | `"Tu factura #[folio] vence en [N] días y no tiene ofertas"` |
| `invoice.expired` | `alerta` | Cliente | `"Factura vencida"` | `"Tu factura #[folio] venció sin recibir financiamiento"` |
| `invoice.denounced` | `alerta` | Ambos | `"Operación denunciada"` | `"La factura #[folio] fue denunciada y está siendo revisada"` |
| `chat.new_message` | `mensaje` | Ambos | `"Nuevo mensaje"` | `"[Nombre] en negociación #[folio]"` |
| `chat.offer_context` | `mensaje` | Ambos | `"Actividad en negociación"` | Evento de sistema (oferta aceptada/rechazada en el hilo) |

> Los mensajes de chat no leídos suman al `unreadNotificationsCount` global **y** generan su badge propio en la tarjeta de oferta dentro del chat.

### CA-03 · Badge del botón `🔔` (`NotificationsButton`)

- Muestra el valor de `unreadNotificationsCount` del `SessionService`.
- Cap visual: `"99+"` si el conteo supera 99.
- El badge desaparece cuando el conteo llega a 0.
- El conteo se decrementa en tiempo real conforme se marcan notificaciones como leídas.

### CA-04 · Comportamiento responsivo del panel

| Breakpoint | Comportamiento |
|------------|---------------|
| `md+` | Panel deslizable desde la derecha (`position: fixed; right: 0; top: 0; height: 100vh`). Ancho fijo ~380px. Overlay oscuro semitransparente detrás. El resto de la app permanece visible pero ininteractuable mientras el panel está abierto. Se cierra con `[✕]`, clic fuera del panel, o `Escape`. |
| `xs–md` | **Bottom sheet** que sube desde el borde inferior. Altura inicial ~65% del viewport. **Drag handle** visible en la parte superior — arrastrar hacia arriba expande a pantalla completa. Se cierra deslizando hacia abajo o tocando el overlay. Footer de "Limpiar todas" fijo en la parte inferior. |

### CA-05 · Anatomía del panel

**A. Header**
- Título `"Notificaciones"`.
- Botón `[✕]` a la derecha para cerrar.

**B. Filtros (chips sticky bajo el header)**

```
[Todas]  [🗒 Facturas]  [✉ Mensajes]  [⚠ Alertas]
```

- Un chip activo a la vez. Default: `"Todas"`.
- Chip activo: fondo sólido (color acento), texto blanco.
- Chips inactivos: borde delineado con ícono + etiqueta.
- Los chips permanecen sticky bajo el header al hacer scroll en el feed.
- Al filtrar: el feed muestra solo las notificaciones de esa categoría. Los separadores temporales y encabezados de categoría que no tengan ítems se ocultan.

**C. Feed de notificaciones**

*Separadores temporales* (agrupan por rango de fecha):
- `"Hoy"` / `"Ayer"` / `"Esta semana"` / `"Anteriores"`

*Encabezado de categoría* (visible solo en la vista `"Todas"`, dentro de cada grupo temporal):
- Ícono + título en negrita (`🗒 Facturas`, `✉ Mensajes`, `⚠ Alertas`).
- Contador de no leídas alineado a la derecha con ícono `≡` en color de alerta.
- Se omite en la vista de categoría filtrada.

*Card de notificación (`NotificationCard`)*:
- `[●]` punto de color (acento) a la izquierda si `read: false`. Ausente si ya fue leída.
- **Título** en negrita.
- **Body** en texto secondary.
- **Timestamp** en texto small/muted.
- Al tocar: marca como leída + navega a `actionUrl`.
- Swipe izquierda (mobile): acciones rápidas `"Marcar como leída"` / `"Eliminar"`.

*Empty state por categoría*:
- Texto centrado: `"Sin notificaciones"`.
- Solo visible cuando la categoría seleccionada no tiene ítems.

**D. Footer fijo**
- Botón `"🗑 Limpiar todas"` en `--color-error`.
- Al pulsar: confirmación **inline dentro del footer** (no modal):
  ```
  ¿Eliminar todas las leídas? [ Cancelar ]  [ Confirmar ]
  ```
- Al confirmar: `DELETE /api/core/notificaciones/read-all` → se eliminan solo las notificaciones leídas. Las no leídas permanecen.

### CA-06 · Comportamiento de marcado como leída (Intersection Observer)

| Acción | Resultado |
|--------|-----------|
| Abrir el panel | Las notificaciones visibles en pantalla se marcan como leídas automáticamente tras **≥ 2 segundos** de visibilidad (Intersection Observer). |
| Hacer scroll sobre una card | Se marca como leída al entrar y permanecer en el viewport ≥ 2s. |
| Tocar una card | Marca como leída inmediatamente + navega. |
| Swipe izquierda → "Marcar como leída" | Marca inmediatamente, punto desaparece. |
| Cerrar el panel | No hay acción adicional — las ya marcadas permanecen leídas. |

Al marcar como leídas: `PATCH /api/core/notificaciones/read` con los IDs acumulados en un batch. El `unreadNotificationsCount` del `SessionService` se decrementa en tiempo real.

### CA-07 · Navegación al tocar una notificación (`actionUrl`)

| Categoría / Tipo | Destino |
|-----------------|---------|
| `invoice.*` (cualquier evento de factura) | Navega a la factura correspondiente y expande el `factura-view` |
| `chat.new_message` | Navega directamente al chat de la oferta |
| `invoice.expiring_soon` / `invoice.expired` | Navega a la factura correspondiente |
| `invoice.denounced` | Navega a la factura correspondiente |

### CA-08 · Notificaciones en tiempo real

- El cliente está suscrito al canal WS `usuario:{userId}`.
- Al recibir evento `notificacion.nueva`: la notificación se **prepende** al feed (aparece en la parte superior del grupo `"Hoy"`), y `unreadNotificationsCount` se incrementa.
- Si el panel está abierto cuando llega la nueva notificación: se agrega visualmente sin cerrar el panel ni interrumpir la lectura actual.
- No se recarga el panel completo al recibir una notificación nueva.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El usuario no tiene ninguna notificación** | Empty state general: `"No tienes notificaciones todavía."` con ícono ilustrativo. No mostrar separadores ni encabezados de categoría. |
| EB-02 | **"Limpiar todas" cuando no hay notificaciones leídas** | El botón está deshabilitado o muestra tooltip `"No hay notificaciones leídas para eliminar."` |
| EB-03 | **El panel se abre y cierra muy rápido antes de los 2s** | Las notificaciones que no completaron los 2s de visibilidad no se marcan como leídas. El batch del Intersection Observer no se envía si el panel se cierra antes. |
| EB-04 | **La paginación carga más notificaciones antiguas** | Scroll infinito: al llegar al final del feed se hace `GET /api/core/notificaciones?page={n+1}` y se agregan al pie del feed. Las nuevas notificaciones entran siempre por la parte superior (real-time), no por paginación. |

---

## Componentes

| Componente | Descripción |
|------------|-------------|
| `NotificationsSidebarComponent` | Panel contenedor. Lateral en `md+`; bottom sheet en `xs–md` |
| `NotificationsHeaderComponent` | Título + botón de cierre |
| `NotificationsFilterBarComponent` | Chips de categoría sticky (Todas / Facturas / Mensajes / Alertas) |
| `NotificationsFeedComponent` | Lista scrollable con separadores temporales y encabezados de categoría |
| `NotificationCardComponent` | Card individual: punto, título, body, timestamp |
| `NotificationCategoryHeaderComponent` | Encabezado de sección: ícono + título + contador de no leídas |
| `NotificationsEmptyStateComponent` | Estado vacío por categoría o global |
| `NotificationsFooterComponent` | Footer fijo con "Limpiar todas" + confirmación inline |
| `NotificationsButtonComponent` | Botón `🔔` de la top-navbar con badge de conteo (pertenece al Shell, HU-34) |

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 7 — seis-portal (Shell) | Refs: §10.0–§10.6, HU-24 (InvoiceNotificationSidebar)*
