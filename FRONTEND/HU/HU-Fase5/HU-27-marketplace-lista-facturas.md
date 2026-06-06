# HU-27 — Marketplace: Lista de Facturas Disponibles (Columna 1)

---

## Historia de Usuario

**Yo como** ejecutivo financiero (`EJECUTIVO_FINANCIADORA` o `ADMIN_FINANCIADORA`),
**Quiero** ver en tiempo real la lista de facturas disponibles para ofertar con buscador y filtros rápidos,
**Para** identificar oportunidades de inversión y priorizar las más atractivas sin tener que recargaar la pantalla.

---

## Contexto técnico

Esta es la pantalla principal del `mfe-ofertador-facturas`, accesible en la ruta `/ofertador`. La Columna 1 es un panel lateral de 1/5 del ancho en `lg+` — el resto del layout (secciones 2, 3, 4) se activa al seleccionar una factura.

La lista carga facturas en estado `PUBLICADA` u `OFERTADA` y se mantiene actualizada en tiempo real vía WebSocket.

Endpoints:
- `GET /api/core/marketplace/facturas?page=N` — lista paginada inicial
- `WS /ws` canal `marketplace` — eventos de nueva factura publicada, factura retirada, cambio de oferta

---

## Criterios de Aceptación

### CA-01 · Layout y dimensiones de la columna

- La Columna 1 está envuelta en una **card** con:
  - `height: 100vh` menos el alto del top-navbar del shell.
  - El contenido de tarjetas es **scrollable internamente**.
  - El buscador y los chips de filtro son **sticky** (se mantienen fijos al hacer scroll).

**Responsive:**

| Breakpoint | Comportamiento |
|------------|---------------|
| `lg+` | Panel lateral izquierdo fijo, 1/5 del ancho. Las secciones 2–4 ocupan los 4/5 restantes. |
| `md` | La Columna 1 colapsa a un **drawer lateral** que se abre/cierra con un botón flotante. Las secciones 2–4 ocupan la pantalla completa. |
| `xs–sm` | Flujo secuencial: lista de facturas → detalle/visor → calculadora. Se navega entre pantallas. |

### CA-02 · Buscador

- Input sticky en la parte superior de la card.
- Placeholder: `"Buscar por deudor o folio..."`.
- **Filtrado local** (no llamada HTTP): filtra en tiempo real sobre las tarjetas ya cargadas.
- Coincidencia parcial, case-insensitive sobre nombre del deudor y número de factura.
- Al limpiar el buscador: se muestra la lista completa (filtros activos siguen aplicando).

### CA-03 · Filtros rápidos (chips toggle, sticky)

Los filtros son **acumulables** entre sí y con el buscador. Se aplican sobre las tarjetas en memoria.

| Filtro | Lógica | Estado inicial |
|--------|--------|:--------------:|
| **Preferidos** | Muestra solo facturas de clientes con los que el ejecutivo ha cerrado ≥ 1 operación previa | ❌ Inactivo |
| **Más recientes** | Ordena por fecha de publicación descendente | ✅ Activo |
| **Alta liquidez** | Oculta facturas con menos de N días al vencimiento (N = configurable desde backend, ej. 30 días) | ❌ Inactivo |

- Al activar **Preferidos**: las tarjetas de clientes sin historial se ocultan pero siguen en memoria (no se elimina la suscripción WS).
- Si la combinación de filtros activos + buscador no produce resultados: empty state `"No hay facturas que coincidan con los filtros activos."` con botón `"Limpiar filtros"`.

### CA-04 · Tarjeta de factura en la lista

```
┌─────────────────────────────────────────────────────┐
│  Factura #00123        Nombre Deudor SA             │
│  CLP $10.150.413                                    │
│  [Sin ofertas activas]          ← neutro            │
│   — o —                                             │
│  [3 ofertas · Tasa: 2.20%]      ← destacado         │
└─────────────────────────────────────────────────────┘
```

| Elemento | Descripción |
|----------|-------------|
| Número de factura | Folio |
| Nombre del deudor | Razón social del deudor |
| Monto total | Formato `CLP $XX.XXX.XXX` |
| `OfferChip` | `"Sin ofertas activas"` (neutro) o `"N ofertas · Tasa: X.XX%"` (la tasa más baja activa = tasa a batir). Se actualiza en tiempo real. |
| `MyActiveOfferBadge` | Indicador `"Tu oferta activa"` si el ejecutivo ya tiene una oferta sobre esta factura. |
| Indicador preferido | Icono sutil (ej. estrella o borde de color) si el cliente es un "cliente preferido" del ejecutivo. Visible independientemente del filtro. |

- La tarjeta **seleccionada** tiene estado visual activo (borde destacado o fondo diferenciado).
- Al hacer clic en una tarjeta: se cargan las secciones 2, 3 y 4 con los datos de esa factura.

### CA-05 · Actualización en tiempo real (WebSocket)

Eventos del canal `marketplace` que el componente maneja:

| Evento | Acción en UI |
|--------|-------------|
| `factura.publicada` | Agrega la nueva tarjeta al tope de la lista (si pasa los filtros activos). Animación de entrada suave. |
| `factura.retirada` | Elimina la tarjeta de la lista. Si era la factura seleccionada: las secciones 2–4 muestran overlay `"Esta factura ya no está disponible."`. |
| `oferta.nueva` o `oferta.modificada` | Actualiza el `OfferChip` de la tarjeta correspondiente con la nueva tasa a batir. |
| `mi.oferta.aceptada` | Muestra notificación destacada (toast o badge en la tarjeta). La tarjeta puede cambiar a un estilo de éxito. |

### CA-06 · Estado inicial y paginación

- Al cargar la pantalla: `GET /api/core/marketplace/facturas?page=1` — primera página de facturas disponibles.
- **Infinite scroll**: al llegar al final de la lista, cargar la siguiente página.
- Mientras carga la primera página: mostrar skeletons de tarjetas (3–5 skeletons).
- Si no hay facturas disponibles al cargar: empty state `"No hay facturas disponibles en este momento."`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El filtro "Preferidos" está activo pero el ejecutivo no tiene clientes preferidos** | Mostrar empty state `"Aún no tienes clientes preferidos. Los clientes con los que hayas cerrado operaciones aparecerán aquí."` |
| EB-02 | **El ejecutivo tiene >100 facturas cargadas en memoria y activa el buscador** | El filtrado local debe ser performático. Usar Angular Signals o pipes puros para no recalcular en cada ciclo de detección de cambios. |
| EB-03 | **La tarjeta seleccionada desaparece (factura retirada) mientras el ejecutivo está llenando la calculadora** | Ver CA-05 y HU-29 (alerta de interferencia). Las secciones 2–4 muestran overlay y el botón de enviar oferta queda bloqueado. |
| EB-04 | **El ejecutivo recarga la página** | La suscripción WS se reinicia. La factura seleccionada previamente no se recuerda (MVP: no persistir selección en URL). |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- La suscripción al canal `marketplace` se gestiona en el nivel del componente raíz del MFE (`OfertadorPage`), no dentro de la Columna 1 específicamente. Así los eventos de `factura.retirada` también pueden propagarse a las secciones 2–4.
- El valor N del filtro "Alta liquidez" (días mínimos al vencimiento) se obtiene del backend al iniciar la sesión como parte de la configuración global de la aplicación.
- La lista de `clientesPreferidos` del ejecutivo se carga desde `GET /api/core/ejecutivo/preferidos` al montar el componente y se cachea localmente.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 5 — mfe-ofertador-facturas*
