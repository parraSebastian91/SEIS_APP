# HU-30 — Enviar Oferta Firme + Modal de Doble Confirmación

> **Referencias de especificación**: HU-10 (modal de doble confirmación), HU-09 (alerta de interferencia). Esta HU cubre el botón de envío, el modal de confirmación y el flujo post-envío del `mfe-ofertador-facturas`.

---

## Historia de Usuario

**Yo como** ejecutivo financiero,
**Quiero** confirmar el envío de mi oferta en un modal con un resumen en lenguaje simple antes de que se registre en el sistema,
**Para** evitar errores por clic accidental en operaciones de alto valor.

---

## Contexto técnico

El botón `"Enviar Oferta Firme"` cierra el ciclo de la Sección 4 del marketplace. Cuando se dispara, se envía la oferta al backend y se actualiza el estado de la Columna 1 en tiempo real.

Endpoint:
- `POST /api/core/oferta` con `{facturaId, pctAnticipo, tasaMensual, comisionEstructuracion, gastosOperacionales, gastoContrato, gastoApertura}`

---

## Criterios de Aceptación

### CA-01 · Habilitación del botón `"Enviar Oferta Firme"`

El botón está **deshabilitado** en cualquiera de estas condiciones:

| Condición bloqueante | Fuente |
|---------------------|--------|
| No hay factura seleccionada | Columna 1 (HU-27) |
| El formulario tiene campos inválidos (ej. tasa = 0) | Sección 4 (HU-29) |
| Alerta de interferencia activa (cliente modificó la factura o la retiró) | HU-29 CA-07 |
| El monto anticipado supera el cupo disponible del deudor | HU-28 CA-04 |

El botón está **habilitado** cuando:
- Hay factura seleccionada.
- Tasa > 0 y dentro del rango permitido.
- % anticipo entre 10% y 100%.
- No hay alertas activas.
- Monto anticipado ≤ cupo disponible.

### CA-02 · Modal de doble confirmación (HU-10)

Al hacer clic en `"Enviar Oferta Firme"`:
- Se muestra un **overlay oscuro** sobre las secciones 2–4.
- Aparece un modal centrado con el resumen de la operación en **lenguaje humano**:

```
┌──────────────────────────────────────────────────────────┐
│  Confirmar oferta                                   [✕]  │
│  ──────────────────────────────────────────────────────  │
│                                                          │
│  Vas a transferir $10.150.413 al cliente por la          │
│  factura #45902 de CENCOSUD S.A.                         │
│                                                          │
│  Dejarás retenidos $1.875.000 como excedente.            │
│                                                          │
│  Tu mesa ganará $373.437 en 45 días.                     │
│                                                          │
│  ──────────────────────────────────────────────────────  │
│  Tasa: 2.10% mensual   Anticipo: 84.4%   Plazo: 45 días  │
│  ──────────────────────────────────────────────────────  │
│                                                          │
│  [ Cancelar ]              [ Sí, publicar oferta → ]     │
└──────────────────────────────────────────────────────────┘
```

**Valores dinámicos del resumen en lenguaje humano:**

| Placeholder | Valor |
|-------------|-------|
| `$10.150.413` | Monto anticipado (CLP, sin decimales) |
| `#45902` | Número de factura |
| `CENCOSUD S.A.` | Razón social del deudor |
| `$1.875.000` | Excedente retenido |
| `$373.437` | Margen bruto de la operación |
| `45 días` | Plazo calculado |

- Los valores monetarios usan fuente monoespaciada con `font-variant-numeric: tabular-nums`.
- El resumen textual está estructurado en 3 oraciones fijas con los valores interpolados.

### CA-03 · Acciones del modal

| Acción | Comportamiento |
|--------|---------------|
| **`"Sí, publicar oferta"`** | Botón muestra spinner + se deshabilita → `POST /api/core/oferta` → al éxito: modal se cierra + flujo de éxito (CA-04). Al error: mensaje de error dentro del modal (CA-05). |
| **`"Cancelar"`** | Cierra el modal. El formulario de la Sección 4 conserva todos los valores. |
| **`[✕]`** | Equivalente a `"Cancelar"`. |
| **`Escape`** | Cierra el modal **solo si no está procesando** (spinner activo). Si está procesando, `Escape` no hace nada. |

### CA-04 · Flujo de éxito

Tras recibir la respuesta 201 del backend:
1. Modal se cierra.
2. **Toast verde**: `"¡Oferta enviada exitosamente!"` (3 segundos, luego se oculta).
3. La tarjeta de la factura en la **Columna 1** (HU-27) se actualiza:
   - El `OfferChip` incrementa el conteo de ofertas.
   - Si la tasa del ejecutivo es la más baja: el chip actualiza la tasa a batir.
   - Aparece el `MyActiveOfferBadge` en la tarjeta.
4. La Sección 4 **no se reinicia** automáticamente — el ejecutivo puede seguir simulando o cambiar de factura.

### CA-05 · Flujo de error

Tras recibir un error del backend:
1. El modal permanece abierto.
2. Se muestra un mensaje de error dentro del modal, debajo del resumen de texto:
   - Error de cupo: `"El cupo del deudor fue actualizado y ya no alcanza para esta oferta. Reduce el % de anticipo."`.
   - Error genérico: `"No se pudo enviar la oferta. Intenta nuevamente."`.
3. Los botones del modal se rehabilitan para reintentar.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El ejecutivo ya tiene una oferta activa sobre la misma factura** | El backend rechaza con un error específico. El modal muestra: `"Ya tienes una oferta activa sobre esta factura. Retírala antes de enviar una nueva."`. |
| EB-02 | **La factura pasa a estado FINANCIADA mientras el modal está abierto** | El evento WS de interferencia (HU-29 CA-07) lo detecta. Como el modal está en primer plano, el overlay de interferencia se muestra detrás del modal. Al cancelar el modal, el overlay de Caso B (`"Factura ya no disponible"`) queda visible. |
| EB-03 | **El cupo del deudor cambia entre que el ejecutivo abre el modal y confirma** | El backend valida el cupo al recibir el `POST`. Si el cupo ya no alcanza, devuelve el error específico (EB-05 CA-05). |
| EB-04 | **El margen bruto resulta en $0 o negativo** | El botón `"Enviar Oferta Firme"` no bloquea por esta razón (el ejecutivo puede tener motivos estratégicos para una oferta con margen bajo). El modal muestra el margen real aunque sea $0 o negativo. |
| EB-05 | **El ejecutivo hace clic en `"Sí, publicar oferta"` varias veces rápidamente** | El botón se deshabilita inmediatamente al primer clic (spinner activo). No se envían múltiples `POST`. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El `POST /api/core/oferta` debe ser idempotente o el frontend debe deshabilitar el botón inmediatamente al enviarse la solicitud para evitar duplicados (opción más sencilla y robusta).
- La actualización del `OfferChip` en la Columna 1 tras el éxito no debe esperar al evento WS — actualizar inmediatamente el estado local en el componente de la tarjeta. El evento WS servirá de fuente de verdad para otros ejecutivos conectados al mismo marketplace.
- El texto del resumen en lenguaje humano está hardcodeado en la plantilla del componente con interpolación de valores. No se obtiene del backend (a diferencia de los T&C del publicador).

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 5 — mfe-ofertador-facturas | Refs: HU-09, HU-10*
