# HU-25 — Modal T&C + Vista de Detalle de Factura y Ofertas (Cliente)

---

## Historia de Usuario (T&C)

**Yo como** cliente cedente,
**Quiero** leer y aceptar los Términos y Condiciones de publicación antes de que mi factura sea visible para los ejecutivos,
**Para** tener claridad sobre las condiciones del financiamiento y dejar constancia de mi consentimiento.

## Historia de Usuario (Detalle de Factura)

**Yo como** cliente cedente,
**Quiero** ver todos los detalles de una factura publicada con sus ofertas recibidas, comparar condiciones y negociar antes de aceptar,
**Para** tomar una decisión informada sobre cuál oferta financiar.

---

## Contexto técnico

Esta HU cubre dos pantallas del `mfe-publicador-facturas`:

1. **`TermsAndConditionsModal`** — Modal que se levanta justo antes de publicar la factura (en los 3 flujos de subida).
2. **Pantalla de Detalle de Factura** — Ruta `/publicador/factura/:id`. Accesible desde el sidebar de notificaciones de `factura-view` (HU-24) o desde links directos.

Endpoints:
- `GET /api/core/factura/tnc` — obtiene título y contenido de los T&C (no hardcodeados)
- `PATCH /api/core/factura/:id/estado` con `{estado: "PUBLICADA"}` — acepta T&C y publica
- `GET /api/core/factura/:id` — datos completos de la factura
- `GET /api/core/factura/:id/ofertas` — lista de ofertas recibidas
- `POST /api/core/oferta/:offerId/aceptar` — aceptar una oferta
- `POST /api/core/oferta/:offerId/rechazar` — rechazar una oferta con motivo opcional

---

## Criterios de Aceptación — `TermsAndConditionsModal`

### CA-01 · Apertura del modal

El modal se levanta en dos momentos distintos del flujo:

| Flujo | Momento de apertura |
|-------|-------------------|
| Caso 1 (Manual sin respaldo) | Automáticamente al recibir la respuesta 201 del `POST /api/core/factura` |
| Casos 2 y 3 (con OCR) | Al pulsar el botón `"Validar y publicar"` en el footer de `factura-view` (solo cuando no hay notas OCR pendientes) |

### CA-02 · Estructura y comportamiento del modal

```
┌──────────────────────────────────────────────────────────────┐
│  Términos y Condiciones de Publicación                  [✕]  │
│  ──────────────────────────────────────────────────────────  │
│  [Título obtenido desde el backend]                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Texto de los T&C...                                  │   │
│  │  (con scroll interno si el texto excede el alto)      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  [ Revisar publicación ]        [ Aceptar términos ]         │
└──────────────────────────────────────────────────────────────┘
```

- **Responsive**: `xs–md`: ~95% del ancho, hasta 85vh. `md+`: ventana centrada. El cuerpo hace scroll interno; los botones **siempre son visibles** sin hacer scroll.
- El título y el texto del T&C provienen del backend (`GET /api/core/factura/tnc`). No están hardcodeados en el frontend.
- El modal no puede abrirse sin haber cargado el contenido del T&C.

### CA-03 · Acciones del modal

| Acción | Comportamiento |
|--------|---------------|
| **`"Aceptar términos"`** | Spinner en el botón → `PATCH /api/core/factura/:id/estado` con `{estado: "PUBLICADA"}` → al éxito: cerrar modal + actualizar badge de estado en `factura-view` con animación pulse |
| **`"Revisar publicación"`** | Cierra el modal. La factura permanece en `PENDIENTE_AUTORIZACION`. El cliente puede volver a abrir el modal desde el footer de `factura-view`. |
| **`[✕]` / `Escape`** | Equivalente a `"Revisar publicación"`. |
| **Error en el PATCH** | Mensaje de error dentro del modal (bajo el cuerpo del T&C). Botones rehabilitados para reintentar. |

---

## Criterios de Aceptación — Vista de Detalle de Factura (`/publicador/factura/:id`)

### CA-04 · Layout de la pantalla

```
[ ← Volver a mis facturas ]

[ Tarjeta de datos de la factura ]

[ Lista de ofertas ]
  ┌──────────────────────────────────────┐
  │  Ejecutivo · Financiera              │
  │  Anticipo: $X.XXX.XXX (XX%)          │
  │  Tasa: X.XX%  ·  Gastos: $XXX.XXX   │
  │  Vigencia: hasta DD/MM/YYYY          │
  │  [Comparar] [Rechazar] [Ver chat ▶] [Aceptar oferta]  │
  └──────────────────────────────────────┘
  ... más ofertas

[ Botón "Comparar seleccionadas" — visible al seleccionar 2 o 3 ]
```

- Enlace `"← Volver a mis facturas"` navega a `/publicador`.

### CA-05 · Tarjeta de datos de la factura

Muestra en modo lectura:
- Folio, RUT y razón social del deudor.
- Monto total (formato CLP).
- Fecha de emisión y fecha de vencimiento.
- Estado actual (badge con color).
- Número de ofertas recibidas.

### CA-06 · Lista de ofertas

Para cada oferta:

| Elemento | Descripción |
|---------|-------------|
| Avatar + nombre del ejecutivo | Link al perfil público del ejecutivo |
| Nombre de la financiera | Si aplica |
| Monto de anticipo | Monto + porcentaje sobre el total de la factura |
| Tasa mensual | Formato `X.XX%` |
| Gastos operacionales | Formato CLP |
| Fecha de vigencia | Con indicador de días restantes. Rojo si ≤ 2 días. |
| Estado de la oferta | Badge: `ACTIVA` / `ACEPTADA` / `RECHAZADA` / `VENCIDA` |

**Acciones por oferta (solo cuando el estado es `ACTIVA`):**

| Botón | Acción |
|-------|--------|
| `Comparar` (checkbox) | Selecciona la oferta para la vista comparativa (máx. 3) |
| `Rechazar` | Confirmación inline con motivo opcional → `POST /api/core/oferta/:offerId/rechazar` |
| `Ver chat ▶` | Abre el `NegotiationChat` (HU-26) en el panel lateral derecho. En `xs–md`: Full Screen. |
| `Aceptar oferta` | Abre `AcceptOfferConfirmDialog` (CA-07) |

Si no hay ofertas: empty state `"Aún no has recibido ofertas para esta factura."`.

### CA-07 · Diálogo de confirmación de aceptación de oferta

```
┌──────────────────────────────────────────────────────────────┐
│  ¿Confirmar aceptación de oferta?                       [✕]  │
│  ──────────────────────────────────────────────────────────  │
│  Ejecutivo: Carlos Soto — Financiera XYZ                     │
│  Anticipo: $9.250.000 (74.6% de $12.400.000)                 │
│  Tasa: 2.10% mensual                                         │
│  Gastos: $85.000                                             │
│  Líquido a recibir: $9.165.000                               │
│  ──────────────────────────────────────────────────────────  │
│  Al aceptar, las demás ofertas se rechazarán automáticamente.│
│                                                              │
│  [ Cancelar ]                      [ Confirmar aceptación ]  │
└──────────────────────────────────────────────────────────────┘
```

- Al confirmar:
  1. `POST /api/core/oferta/:offerId/aceptar`.
  2. La factura pasa a estado `FINANCIADA`.
  3. Las demás ofertas activas pasan a `RECHAZADA` automáticamente (el backend lo maneja).
  4. El diálogo se cierra. La pantalla se actualiza con el nuevo estado.
- El `TermsAndConditionsModal` no aplica aquí — la publicación ya ocurrió antes.

### CA-08 · Modal de comparación de ofertas

Activado al pulsar `"Comparar seleccionadas"` con 2 o 3 ofertas seleccionadas:

```
┌────────────────────────────────────────────────────────────────┐
│  Comparar Ofertas                                         [✕]  │
│  ────────────────────────────────────────────────────────────  │
│              [Oferta A]       [Oferta B]      [Oferta C]       │
│  Ejecutivo   Carlos S.        Ana M.          Pedro L.         │
│  Financiera  Fintech XYZ      Capital ABC     Inv. Sur         │
│  Anticipo    $9.250.000       $9.000.000      $9.100.000       │
│              (74.6%)          (72.6%)         (73.4%)          │
│  Tasa        2.10%            1.95%           2.00%            │
│  Gastos      $85.000          $90.000         $80.000          │
│  Líquido     $9.165.000       $8.910.000      $9.020.000       │
│  Vigencia    5 días           3 días          7 días           │
│              [Aceptar]        [Aceptar]       [Aceptar]        │
└────────────────────────────────────────────────────────────────┘
```

- **Responsive**: Full Screen en `xs–md`; ventana centrada en `md+`.
- El mejor valor de cada fila se destaca visualmente (negrita o color verde).
- Los botones `"Aceptar"` abren el `AcceptOfferConfirmDialog` (CA-07) sin cerrar el modal de comparación primero.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El cliente accede a `/publicador/factura/:id` directamente sin pasar por la lista** | Cargar los datos de la factura desde el backend directamente. Si la factura no pertenece al usuario autenticado o no existe: redirigir a `/publicador` con toast de error. |
| EB-02 | **La oferta vence mientras el cliente está viendo el modal de comparación** | El badge de vigencia se actualiza en tiempo real vía SSE/WS. Si vence, el botón `"Aceptar"` de esa oferta se deshabilita. |
| EB-03 | **Todas las ofertas han sido rechazadas o vencidas** | El empty state de la lista de ofertas debe distinguir entre "nunca hubo ofertas" y "las ofertas que hubo ya no están activas". Mensaje: `"Las ofertas recibidas ya no están disponibles. Tu factura sigue publicada y puede recibir nuevas ofertas."` |
| EB-04 | **El T&C cambia mientras el cliente tiene el modal abierto** | El modal muestra el contenido cargado al abrir. No recarga el T&C mientras está abierto. Si el backend rechaza el PATCH porque el T&C es de una versión obsoleta (improbable en MVP): mostrar error con CTA para cerrar y reabrir el modal. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El `NegotiationChat` (HU-26) se abre como panel lateral en esta pantalla. Usar un layout de 2 columnas con el chat en la columna derecha (en `lg+`), o Full Screen en mobile.
- El `AcceptOfferConfirmDialog` puede reutilizarse en el `NegotiationChat` (el cliente también puede aceptar desde el chat). El componente debe aceptar el `offerId` y los datos de la oferta como `@Input`.
- Los valores monetarios en el modal de comparación deben usar fuente monoespaciada con `tnum` para alineación de columnas.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 4 — mfe-publicador-facturas*
