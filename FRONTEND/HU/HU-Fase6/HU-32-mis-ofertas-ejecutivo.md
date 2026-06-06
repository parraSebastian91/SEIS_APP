# HU-32 — Mis Ofertas (Ejecutivo)

> **Fase**: 6 — `mfe-dashboard-facturas` | **Ruta**: `/dashboard/mis-ofertas` | **Rol**: Ejecutivo financiero

---

## Historias de Usuario

- **`US-D04`** — Como ejecutivo, quiero ver todas las ofertas que he enviado y su estado actual, para hacer seguimiento de mis operaciones.
- **`US-D05`** — Como ejecutivo, quiero saber cuándo una oferta mía fue aceptada, para proceder con la liquidación.
- **`US-D06`** — Como ejecutivo, quiero filtrar mis ofertas por estado (activa, aceptada, rechazada, vencida), para gestionar mi pipeline.

---

## Contexto técnico

Historial completo de ofertas enviadas por el ejecutivo autenticado. Es la segunda pestaña del dashboard ejecutivo (la primera es el resumen de KPIs, HU-33).

Endpoints:
- `GET /api/core/ejecutivo/ofertas?estado={estado}&page={page}&size={size}` — paginado.
- `PATCH /api/core/oferta/:id/retirar` — retirar una oferta activa.

---

## Criterios de Aceptación

### CA-01 · Tabla `MyOffersTable`

Cada fila de la tabla contiene:

| Columna | Descripción | Formato |
|---------|-------------|---------|
| Factura | Número de folio + razón social del deudor | `#45902 — CENCOSUD S.A.` |
| Monto ofertado | `montoAnticipado` calculado al momento de la oferta | CLP sin decimales |
| Tasa | Tasa mensual pactada | `X.XX%` |
| Fecha de oferta | Fecha en que se envió la oferta | `DD/MM/YYYY` |
| Estado oferta | Badge con color por estado (CA-02) | `OfferStatusBadge` |
| Estado factura | Estado actual de la factura | texto o badge secundario |
| Acciones | Accesos rápidos según estado (CA-04) | íconos / botones |

- Ordenación por defecto: **más reciente primero** (por `fechaOferta` descendente).
- Paginación: 20 filas por página. Paginador al pie de la tabla.
- La tabla es responsive:
  - `lg+`: todas las columnas visibles.
  - `md`: se oculta `Fecha de oferta`. El resto visible.
  - `xs–sm`: vista de tarjetas apiladas (una por oferta con los datos clave).

### CA-02 · `OfferStatusBadge` — Estado de la oferta

| Estado | Etiqueta | Color |
|--------|----------|-------|
| `ACTIVA` | Activa | Azul |
| `ACEPTADA` | Aceptada | Verde |
| `RECHAZADA` | Rechazada | Rojo |
| `VENCIDA` | Vencida | Gris |
| `RETIRADA` | Retirada | Gris tenue |

### CA-03 · Filtros por estado de oferta

Pill toggle múltiple encima de la tabla (puede aplicarse más de uno a la vez):

```
[ Activas ]  [ Aceptadas ]  [ Rechazadas ]  [ Vencidas ]  [ Todas ]
```

- Default al cargar: `"Todas"` activo.
- Seleccionar `"Todas"` deselecciona los demás filtros.
- Al cambiar el filtro: re-fetchea con `?estado={estado}` y vuelve a la página 1.
- Si el filtro activo devuelve 0 resultados: empty state `"No tienes ofertas en este estado."`.

### CA-04 · Acciones por estado

| Estado de la oferta | Acción disponible |
|--------------------|-------------------|
| `ACTIVA` | `"Ver chat"` (si el cliente inició chat) + `"Retirar oferta"` |
| `ACEPTADA` | `"Ver chat"` (obligatorio — la negociación continúa) |
| `RECHAZADA` | `"Ver chat"` (para ver el motivo si el cliente lo comunicó) |
| `VENCIDA` | Sin acciones |
| `RETIRADA` | Sin acciones |

**`"Ver chat"`**: abre el `NegotiationChat` del `shared-utils` en panel lateral (`lg+`) o pantalla completa (mobile), igual que en HU-26.

**`"Retirar oferta"`**:
- Disponible solo para ofertas `ACTIVA`.
- Al hacer clic: diálogo de confirmación `"¿Retirar oferta? Esta acción no se puede deshacer."` con botones `"Sí, retirar"` / `"Cancelar"`.
- `PATCH /api/core/oferta/:id/retirar` → al éxito: badge cambia a `RETIRADA`, acción desaparece.
- Si hay chat en curso: el mensaje de retiro se envía automáticamente al chat (`"El ejecutivo ha retirado su oferta."`).

### CA-05 · Notificación de oferta aceptada

Cuando una oferta del ejecutivo pasa a `ACEPTADA` (evento WS del canal `ejecutivo:{ejecutivoId}`):
- Se muestra un **toast destacado**: `"🎉 ¡Tu oferta para la factura #45902 fue aceptada!"` con botón `"Ver chat"`.
- La fila correspondiente en la tabla se actualiza inmediatamente con el badge `ACEPTADA` sin necesidad de recargar.
- Si el ejecutivo está en otra pantalla del portal: el toast aparece igualmente (canal WS global, manejado por el Shell).

### CA-06 · Estados de carga y error

- Al cargar la tabla: skeleton de 5 filas.
- Si el endpoint falla: error inline con botón `"Reintentar"`.
- Empty state general (ejecutivo sin ninguna oferta enviada nunca): `"Aún no has enviado ninguna oferta. Ve al marketplace para comenzar."` con CTA a `/ofertador`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El ejecutivo tiene >100 ofertas** | Paginación de 20 en 20. No cargar todo en memoria. |
| EB-02 | **La factura asociada a una oferta fue eliminada del sistema** | Mostrar `"#XXXXX (factura no disponible)"` en la columna Factura. La fila sigue visible para referencia histórica. |
| EB-03 | **Un cedente accede a `/dashboard/mis-ofertas`** | El shell redirige a `/dashboard/cedente` según el rol. La ruta `/mis-ofertas` no es accesible para cedentes. |
| EB-04 | **El ejecutivo tiene oferta ACTIVA sobre una factura que el cliente retiró** | El estado de la factura en la columna cambia a `"Retirada"`. La oferta sigue como `ACTIVA` hasta que el backend la venza o el ejecutivo la retire manualmente. Mostrar chip o nota: `"Factura retirada por el cliente"`. |

---

## Componentes

| Componente | Descripción |
|------------|-------------|
| `MyOffersTableComponent` | Tabla principal con paginación y filtros |
| `OfferStatusBadgeComponent` | Badge de estado (reutilizable en HU-33 si corresponde) |
| `OfferRetireConfirmDialogComponent` | Diálogo de confirmación de retiro |

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 6 — mfe-dashboard-facturas | Refs: HU-26 (NegotiationChat)*
