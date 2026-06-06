# HU-05 — Perfil de Riesgo del Deudor (Semáforo de Exposición)

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** ver en pantalla el historial de comportamiento de pago y el nivel de exposición actual de la empresa frente al deudor de la factura que estoy evaluando,
**Para** tomar una decisión de oferta informada y asegurarme de no exceder los límites de riesgo asignados a ese deudor.

---

## Criterios de Aceptación

### CA-01 · Visualización del historial de pago
- La sección debe mostrar un **gráfico de barra simple** que represente el promedio de días que ese deudor tarda en pagar sus facturas dentro del sistema.
- Junto al gráfico, se muestran dos métricas clave en texto:
  - `Promedio de pago: N días`
  - `Desviación estándar: ± N días`
- Ejemplo visual: `Promedio: 41 días | Desviación: ± 3 días`.

### CA-02 · Deudor sin historial en el sistema
- Si el deudor es **nuevo y no tiene historial de pagos** en la plataforma, el área del gráfico debe mostrar el mensaje: `"Sin historial disponible para este deudor."`, sin dejar el espacio en blanco.

### CA-03 · Termómetro de exposición del cupo
- La sección debe mostrar una **barra de progreso** que represente visualmente qué porcentaje del cupo total asignado al deudor ya está comprometido.
- Encima o debajo de la barra se muestra:
  - `Cupo total asignado: $XXX.XXX.XXX`
  - `Cupo ya utilizado: $XXX.XXX.XXX`
  - `Cupo disponible: $XXX.XXX.XXX`

### CA-04 · Colores del termómetro según nivel de riesgo
El color de la barra de progreso debe cambiar dinámicamente según el nivel de utilización del cupo:

| Rango de uso del cupo | Color de la barra | Significado |
|---|---|---|
| 0% – 50% | **Verde** | Exposición baja. Riesgo controlado. |
| 51% – 74% | **Amarillo** | Exposición media. Precaución. |
| 75% – 89% | **Naranja** | Exposición alta. Atención requerida. |
| 90% – 100% | **Rojo** | Cupo casi agotado. No se puede ofertar. |

### CA-05 · Bloqueo de oferta por cupo agotado
- Si el **cupo disponible del deudor es $0** (uso al 100%), el sistema debe:
  - Mostrar la barra en rojo con el texto: `"Cupo agotado para este deudor."`.
  - **Deshabilitar el botón de "Enviar Oferta Firme"** mientras ese deudor esté en pantalla.
  - Mostrar un mensaje explicativo: `"No puedes ofertar sobre esta factura. El cupo de riesgo para este deudor está al 100%."`.

### CA-06 · Advertencia de cupo insuficiente para el monto a ofertar
- Si la ejecutiva configura una oferta (Columna 3) por un monto que supera el cupo disponible del deudor, el sistema debe mostrar una advertencia **en tiempo real** (sin esperar a que presione "Enviar"):
  > `"Advertencia: Tu oferta de $12.500.000 supera el cupo disponible de $9.800.000 para este deudor."`

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Actualización del cupo en tiempo real** | Si otra ejecutiva acaba de cerrar una operación con el mismo deudor y el cupo disponible baja mientras la primera ejecutiva está revisando, ¿el termómetro se actualiza automáticamente o solo al refrescar? |
| EB-02 | **Cupo no asignado** | ¿Qué pasa si el deudor existe pero el administrador no le ha asignado un cupo? ¿Muestra "Sin cupo definido" y bloquea las ofertas o las permite libremente? |
| EB-03 | **Quién puede modificar el cupo** | ¿Solo el administrador puede modificar el cupo de un deudor? ¿Existe un flujo de solicitud de ampliación de cupo desde la ejecutiva? |
| EB-04 | **Historial de solo 1 pago** | Si el deudor solo ha pagado 1 factura, la desviación estándar es matemáticamente 0 o indefinida. ¿Qué muestra el sistema en ese caso? |
| EB-05 | **Deudor con pagos fuera del sistema** | El deudor puede pagar facturas fuera de la plataforma (otros bancos). ¿El historial solo refleja las operaciones dentro del sistema o se integra con datos externos? |
| EB-06 | **Oferta parcial y cupo** | Si la ejecutiva ofrece financiar solo el 85% del monto (anticipo parcial), ¿el consumo de cupo se calcula sobre el monto total de la factura o sobre el monto anticipado? |
| EB-07 | **Exposición cruzada entre ejecutivas** | Si hay 3 ejecutivas evaluando la misma factura del mismo deudor al mismo tiempo, ¿la exposición mostrada en el termómetro refleja las ofertas pendientes de las otras ejecutivas? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El cupo de riesgo por deudor es un parámetro definido en el módulo de administración de la plataforma. El endpoint del BFF debe retornarlo junto con el acumulado actual de operaciones activas para ese deudor.
- El cálculo de "cupo utilizado" debe incluir operaciones **cerradas y vigentes** (no vencidas ni liquidadas totalmente).

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
