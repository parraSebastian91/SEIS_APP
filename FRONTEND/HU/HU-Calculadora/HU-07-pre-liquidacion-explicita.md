# HU-07 — Pre-Liquidación Explícita (Estructura de Liquidación)

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** ver en tiempo real una tabla de liquidación detallada que me muestre exactamente cuánto dinero se le gira al cliente, cuánto se retiene y cuánto gana la empresa con la operación,
**Para** entender con claridad el resultado financiero completo de mi oferta antes de confirmarla.

---

## Criterios de Aceptación

### CA-01 · Visualización de la estructura de liquidación
- La sección de Pre-Liquidación debe mostrarse en una **tarjeta de alto contraste** (fondo azul marino oscuro `#0f172a` con texto blanco) ubicada en la parte inferior de la Columna 3.
- Esta tarjeta debe actualizarse automáticamente cada vez que cambie cualquier parámetro del formulario de la Columna 3 (sin clic adicional).

### CA-02 · Desglose obligatorio de la liquidación
La tarjeta debe mostrar exactamente los siguientes campos, en este orden:

```
ESTRUCTURA DE LIQUIDACIÓN
─────────────────────────────────────────────────────
Plazo de la Operación:                      [N] días
─────────────────────────────────────────────────────
Monto Anticipado ([X]%):               $XX.XXX.XXX
Excedente Retenido ([Y]%):              $X.XXX.XXX
─────────────────────────────────────────────────────
(-) Diferencia de Precio (Interés):    -$XXX.XXX
(-) Subtotal Comisiones/Gastos:         -$XX.XXX
(-) IVA (19% sobre Gastos):            -$XX.XXX
═════════════════════════════════════════════════════
GIRO LÍQUIDO AL CLIENTE:               $XX.XXX.XXX
─────────────────────────────────────────────────────
Margen Bruto Operación (Utilidad):      $XXX.XXX
```

### CA-03 · Fórmulas de cálculo (reglas de negocio)

| Línea | Fórmula |
|---|---|
| **Monto Anticipado** | `Monto Factura × (% Anticipo / 100)` |
| **Excedente Retenido** | `Monto Factura × (1 − % Anticipo / 100)` |
| **Diferencia de Precio (Interés)** | `Monto Anticipado × (Tasa Mensual / 100) × (Plazo en días / 30)` |
| **Subtotal Comisiones/Gastos** | `Comisión + Gastos Oper. + Gto. Contrato + Gto. Apertura` |
| **IVA (19%)** | `Subtotal Comisiones/Gastos × 0.19` *(aplica SOLO sobre gastos/comisiones, no sobre el interés)* |
| **Giro Líquido al Cliente** | `Monto Anticipado − Diferencia de Precio − Subtotal Comisiones − IVA` |
| **Margen Bruto Operación** | `Diferencia de Precio` *(la utilidad de la empresa es el interés cobrado)* |

### CA-04 · Regla tributaria del IVA (crítica para Chile 🇨🇱)
- El IVA del 19% se aplica **únicamente** sobre la suma de: Comisión de Estructuración + Gastos Operacionales + Gasto de Contrato + Gasto de Apertura.
- La **Diferencia de Precio (Interés)** es legalmente **exenta de IVA** y **no debe incluirse** en la base de cálculo del impuesto.
- Si todos los gastos son $0, el IVA también debe mostrar $0 (no calcular IVA sobre el interés bajo ninguna circunstancia).

### CA-05 · Todos los montos en pesos chilenos
- Todos los valores deben estar formateados en **pesos chilenos sin decimales** (ej: `$10.150.413`), usando punto como separador de miles.
- Los valores negativos (descuentos) deben mostrar el signo menos con texto gris o en color diferenciado para distinguirlos de los positivos.

### CA-06 · Estado inicial vacío
- Cuando la ejecutiva accede al panel sin haber seleccionado una factura, la tarjeta de Pre-Liquidación debe mostrar un estado vacío neutro: `"Selecciona una factura para simular la liquidación."`.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Giro líquido negativo** | ¿Es matemáticamente posible que los gastos y comisiones superen el monto anticipado y el "Giro Líquido" sea negativo? Si ocurre, ¿el sistema lo muestra en rojo con advertencia o bloquea el formulario? |
| EB-02 | **Margen bruto vs. margen neto** | La tarjeta muestra "Margen Bruto". ¿El equipo financiero necesita también ver el "Margen Neto" (descontando costos operativos propios de la empresa)? Si sí, ¿cuáles son esos costos? |
| EB-03 | **Plazo de la operación** | La fórmula del interés usa el plazo en días. ¿El plazo es el número de días desde hoy hasta el vencimiento de la factura (días calendario) o días hábiles? |
| EB-04 | **Cambio de tasa del mercado durante simulación** | Si la tasa de referencia del mercado cambia (otra ejecutiva mejora la oferta) mientras la ejecutiva está simulando, ¿la calculadora se actualiza sola o solo cuando ella presiona "Match & Beat"? |
| EB-05 | **Excedente retenido al 100% de anticipo** | Si el anticipo es 100%, el excedente es $0. ¿La línea "Excedente Retenido" desaparece de la tarjeta o se muestra con valor $0? |
| EB-06 | **Auditoría de la simulación** | ¿Se necesita guardar un registro de las simulaciones realizadas (log de actividad) aunque la ejecutiva no haya enviado la oferta, para efectos de auditoría interna? |
| EB-07 | **Cambio de tasa de IVA** | El IVA en Chile es actualmente 19%. Si cambia en el futuro, ¿este porcentaje debe ser configurable en el sistema o puede ser un cambio de código? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Todo el cálculo es **puramente en el frontend** con Angular Signals. Cero llamadas HTTP para recalcular.
- La tasa de IVA (19%) debe ser una **constante configurable** desde el backend/administración, no un número literal en el código.
- El formato de moneda CLP (peso chileno sin decimales) debe manejarse con `Intl.NumberFormat('es-CL', { style: 'currency', currency: 'CLP' })`.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
