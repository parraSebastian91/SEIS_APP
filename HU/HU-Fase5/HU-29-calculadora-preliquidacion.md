# HU-29 — Calculadora de Parámetros + Pre-Liquidación Explícita (Sección 4)

> **Referencias de especificación**: HU-06 (inputs), HU-07 (pre-liquidación), HU-08 (Match & Beat), HU-09 (alerta de interferencia). Esta HU consolida esas especificaciones en el contexto del `mfe-ofertador-facturas` y agrega la capa técnica de implementación Angular.

---

## Historia de Usuario

**Yo como** ejecutivo financiero,
**Quiero** simular distintos escenarios de anticipo, tasa y gastos con recálculo instantáneo y ver la estructura de liquidación completa,
**Para** encontrar la oferta más competitiva y rentable sin salir del sistema ni abrir una hoja de cálculo.

---

## Contexto técnico

La Sección 4 es la columna derecha del marketplace (aproximadamente 2/5 del ancho). Toda la lógica de cálculo ocurre **exclusivamente en el frontend** con Angular Signals — no hay llamadas HTTP hasta el momento de enviar la oferta.

Los valores de configuración (tasa máxima, diferencial M&B, umbral de alta liquidez) se cargan **una sola vez** al iniciar la sesión desde `GET /api/core/config/calculadora` y se almacenan en un servicio singleton.

---

## Criterios de Aceptación

### CA-01 · Estado inicial (sin factura seleccionada)

- La Sección 4 muestra el mensaje: `"Selecciona una factura para simular la liquidación."`.
- El formulario y la tarjeta de pre-liquidación no están visibles.

### CA-02 · Campo "% Anticipo" — Input + Slider (HU-06 CA-01)

- **Input numérico** sincronizado con un **slider horizontal**.
- Rango permitido: **10% a 100%**. Default al seleccionar nueva factura: **100%**.
- Al mover el slider o escribir en el input: se actualiza el valor del otro control en tiempo real y se recalcula la pre-liquidación.
- Muestra en tiempo real:
  - **Monto a anticipar** = `montoFactura × % / 100` (formato CLP).
  - **Excedente retenido** = `montoFactura × (1 − % / 100)` (formato CLP).
- Si el usuario borra el valor: se restaura al valor anterior (no dejar campo vacío).

### CA-03 · Campo "Tasa de Interés Mensual (%)" con Match & Beat (HU-06 CA-02, HU-08)

- Input decimal con hasta **2 decimales**.
- No puede ser negativo ni superar el máximo regulatorio (obtenido desde `config.tasaMaxima`).
- Si el usuario borra el valor: se restaura a `0.00`.

**Botón Match & Beat (junto al input de tasa):**

- Siempre muestra la referencia: `"Mejor oferta: X.XX%"` o `"Sin ofertas activas"`.
- Al presionar:
  - Si hay ofertas: establece la tasa en `mejorTasa − config.diferencialMB` y recalcula.
  - Si no hay ofertas: botón deshabilitado (no hay tasa a batir).
  - Si la tasa actual ya es la más competitiva: botón deshabilitado + tooltip `"Tu tasa ya es la más competitiva."`.
- El diferencial `config.diferencialMB` (ej. `0.05%`) es configurable desde backend.
- La tasa a batir se actualiza en tiempo real cuando otra oferta cambia (evento WS).

### CA-04 · Campos de Gastos y Comisiones (HU-06 CA-03)

Cuatro inputs de monto en pesos chilenos, todos opcionales (default `$0`):

| Campo | Etiqueta visible |
|-------|-----------------|
| Comisión de Estructuración | Comisión de Estructuración |
| Gastos Operacionales | Gastos Operacionales |
| Gasto de Contrato | Gasto de Contrato |
| Gasto de Apertura | Gasto de Apertura |

- Solo valores numéricos positivos. Máscara automática con separadores de miles.
- Si el usuario borra un campo: valor restaurado a `$0`.
- **Gasto de Apertura**: puede venir pre-llenado si el cliente es nuevo (indicado por un flag en la respuesta de `GET /api/core/marketplace/factura/:id`). El ejecutivo puede modificarlo.

### CA-05 · Recálculo instantáneo (HU-06 CA-04)

- Al modificar **cualquier campo** del formulario: todos los valores de la `PreLiquidacionCard` (CA-06) se actualizan en **< 16ms** (sin llamadas HTTP).
- Implementación: **Angular Signals** con `computed()`. Los 6 inputs son `signal()`. La tarjeta de pre-liquidación usa `computed()` sobre esos signals.

### CA-06 · Tarjeta de Pre-Liquidación Explícita (HU-07)

Tarjeta de alto contraste con fondo `#0D1655` (variable `--navy-deep`):

```
ESTRUCTURA DE LIQUIDACIÓN
───────────────────────────────────────────────────
Plazo de la Operación:                    [N] días
───────────────────────────────────────────────────
Monto Anticipado ([X]%):           $XX.XXX.XXX
Excedente Retenido ([100-X]%):      $X.XXX.XXX
───────────────────────────────────────────────────
(-) Diferencia de Precio (Interés):   -$XXX.XXX
(-) Subtotal Comisiones/Gastos:        -$XX.XXX
(-) IVA (19% sobre Gastos):            -$XX.XXX
═══════════════════════════════════════════════════
GIRO LÍQUIDO AL CLIENTE:           $XX.XXX.XXX
───────────────────────────────────────────────────
Margen Bruto Operación:             $XXX.XXX
```

**Fórmulas:**

| Concepto | Fórmula |
|----------|---------|
| Monto Anticipado | `montoFactura × (anticipo / 100)` |
| Excedente Retenido | `montoFactura − montoAnticipado` |
| Plazo (días) | `fechaVencimiento − hoy` (en días corridos) |
| Diferencia de Precio (Interés) | `montoAnticipado × (tasa / 100) × (plazo / 30)` |
| Subtotal Gastos | `comisionEstructuracion + gastosOperacionales + gastoContrato + gastoApertura` |
| IVA | `subtotalGastos × 0.19` ⚠️ **Solo sobre gastos, nunca sobre el interés** (regla tributaria 🇨🇱) |
| Giro Líquido al Cliente | `montoAnticipado − diferenciaDePrecio − subtotalGastos − iva` |
| Margen Bruto | `diferenciaDePrecio + subtotalGastos + iva` |

- Todos los montos: formato CLP sin decimales (`$XX.XXX.XXX`). Fuente monoespaciada con `font-variant-numeric: tabular-nums`.
- La tarjeta actualiza todos los valores en < 16ms al cambiar cualquier input (Signals `computed()`).

### CA-07 · Alerta de interferencia en tiempo real (HU-09)

Se activa cuando el backend emite un evento WS indicando que el cliente modificó la factura o que la factura fue retirada.

**Caso A — El cliente modificó datos de la factura:**
- Se muestra un **overlay semitransparente bloqueante** sobre la Sección 4 completa.
- Mensaje: `"Los datos de la factura han cambiado. Recalculando parámetros..."`.
- Al recibir los nuevos datos: el overlay desaparece, el formulario se recalcula con **los mismos parámetros del ejecutivo** (tasa, anticipo, gastos se preservan — solo el monto base cambia), y aparece un toast `"Los datos de la factura han sido actualizados. Tu simulación fue recalculada."`.

**Caso B — La factura fue retirada:**
- Overlay **permanente** (no desaparece): `"Esta factura ya no está disponible."`.
- El botón `"Enviar Oferta Firme"` queda permanentemente bloqueado.
- La tarjeta desaparece de la Columna 1 (evento WS en HU-27).

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Plazo de la operación resulta en 0 o negativo** (factura vencida) | Mostrar `"⚠️ Esta factura está vencida."` en la tarjeta. El botón de envío queda deshabilitado. |
| EB-02 | **IVA calculado sobre el interés por error** | Las fórmulas del `computed()` deben validarse con pruebas unitarias que confirmen que el IVA siempre se aplica solo sobre `subtotalGastos`. Agregar un comentario explícito en el código. |
| EB-03 | **El ejecutivo cambia de factura con el formulario lleno** | El formulario se reinicia a valores default (% anticipo: 100%, tasa: 0, gastos: $0). Ver HU-06 EB-04 — confirmar con negocio si se prefiere preservar los parámetros al cambiar de factura. |
| EB-04 | **Monto anticipo supera cupo del deudor** | Ver HU-28 CA-04. La `CupoExceededAlert` en la Sección 2 muestra la advertencia. El botón de envío queda bloqueado. La Sección 4 no necesita su propio mensaje de cupo — basta con la alerta del header. |
| EB-05 | **El Gasto de Apertura pre-llenado es borrado por el ejecutivo** | El valor queda en `$0`. No se restaura automáticamente (a diferencia de otros campos). El pre-llenado es una sugerencia, no un bloqueo. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Los 6 inputs del formulario son `signal<number>()`. La `PreLiquidacionCard` usa exclusivamente `computed()` derivados — nunca estado local propio. Esto garantiza que el recálculo sea reactivo y sin efectos secundarios.
- El `config.tasaMaxima` y `config.diferencialMB` se cargan al bootstrapear el MFE desde el backend y se almacenan en un `CalculadoraConfigService` singleton. No se cargan al seleccionar cada factura.
- Pruebas unitarias obligatorias para: fórmulas de la pre-liquidación (especialmente IVA solo sobre gastos), límites del slider (10/100%), reinicio al cambiar de factura.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 5 — mfe-ofertador-facturas | Refs: HU-06, HU-07, HU-08, HU-09*
