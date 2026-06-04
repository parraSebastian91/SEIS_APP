# HU-08 — Botón "Match & Beat" (Igualador de Tasa Competitiva)

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** poder igualar y superar la mejor tasa de interés del mercado para una factura específica con un solo clic,
**Para** posicionarme automáticamente como la oferta más atractiva sin necesidad de calcular manualmente cuánto debo ajustar mi tasa.

---

## Criterios de Aceptación

### CA-01 · Disponibilidad del botón
- El botón "Match & Beat" debe estar ubicado **junto al campo de Tasa de Interés Mensual** en la Columna 3 (Calculadora).
- El botón solo debe estar **activo (habilitado)** cuando la factura seleccionada tenga al menos **una oferta competidora** activa en el marketplace.
- Si no hay ofertas de otras ejecutivas, el botón debe estar **deshabilitado** con un tooltip explicativo: `"No hay ofertas activas para esta factura."`.

### CA-02 · Lógica de cálculo del "Match & Beat"
- Al presionar el botón, el sistema debe:
  1. Leer la **tasa más baja actual** en el marketplace para esa factura (la mejor oferta competidora).
  2. Restar automáticamente **0.05 puntos porcentuales** a esa tasa.
  3. Establecer ese nuevo valor en el campo **"Tasa de Interés Mensual"** del formulario.
  4. **Disparar el recálculo completo** de la Pre-Liquidación en tiempo real (como si la ejecutiva hubiera escrito el número manualmente).
- Ejemplo: Si la mejor tasa del mercado es `2.20%`, el botón establece `2.15%`.

### CA-03 · Resultado ya es la mejor tasa
- Si la ejecutiva ya tiene ingresada una tasa que es igual o menor a `(mejor tasa − 0.05%)`, el botón **no debe hacer ningún cambio** y debe mostrar un tooltip informativo: `"Tu tasa ya es la más competitiva del mercado."`.

### CA-04 · Resultado de la tasa resultante es negativo o inválido
- Si la aplicación del −0.05% resulta en una tasa negativa o por debajo del mínimo permitido por el negocio, el botón debe establecer la **tasa mínima permitida** (no una tasa inválida) y mostrar un aviso: `"Se ajustó a la tasa mínima permitida: X.XX%."`.

### CA-05 · Indicador de "tasa a batir" siempre visible
- Cerca del botón "Match & Beat" (o dentro del campo de tasa), debe mostrarse siempre el dato de referencia: `Mejor oferta actual: 2.20%` para que la ejecutiva tenga contexto antes de presionar el botón.
- Si no hay ofertas, se muestra: `Sin ofertas activas`.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Tasa cambia justo después del clic** | Si otra ejecutiva mejora su oferta en el microsegundo en que la primera presiona "Match & Beat", ¿la tasa establecida ya no es la mejor? ¿El sistema revalida antes de enviar la oferta firme? |
| EB-02 | **Múltiples clics al botón** | Si la ejecutiva presiona "Match & Beat" varias veces, ¿cada clic sigue restando 0.05%? ¿O el resultado es idempotente (siempre calcula contra la mejor tasa actual)? |
| EB-03 | **El −0.05% es configurable** | ¿El diferencial de 0.05 puntos porcentuales es un parámetro de negocio que puede cambiar o es un valor fijo? Definirlo ahora para saber si debe ser configurable. |
| EB-04 | **Empate con la propia ejecutiva** | ¿La "mejor tasa del mercado" incluye las propias ofertas previas de la ejecutiva en esa misma factura? Si ya tiene una oferta enviada y la vuelve a abrir, ¿estaría compitiendo consigo misma? |
| EB-05 | **Desaparición de la mejor oferta** | Si la ejecutiva que tenía la mejor tasa retira su oferta, ¿el indicador "Mejor oferta actual" se actualiza en tiempo real en la calculadora de la primera ejecutiva? |
| EB-06 | **Tasa ya es mínima del sistema** | Si la ejecutiva ya está en la tasa mínima permitida (ej: 0.50%), pero la mejor oferta del mercado es 0.52%, ¿el botón intenta poner 0.47% y el sistema la sube a 0.50%? ¿Hay un mensaje claro? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- La "mejor tasa actual" del marketplace para una factura específica debe provenir del mismo canal **WebSocket** que alimenta el contador de ofertas en la Columna 1.
- El diferencial de `-0.05%` debe ser un parámetro configurable almacenado en el backend (tabla de configuración del sistema).
- No se hace ninguna llamada HTTP al backend al presionar el botón; solo se actualiza el estado local del formulario.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
