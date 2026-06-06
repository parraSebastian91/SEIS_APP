# HU-01 — Tablero de Competición en Tiempo Real (Marketplace de Facturas)

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** ver en tiempo real las facturas disponibles para financiar, ordenadas con las más recientes al tope de la lista y con un contador regresivo de tiempo para ofertar,
**Para** poder tomar decisiones de inversión rápidas y competitivas sin necesidad de refrescar la pantalla manualmente.

---

## Criterios de Aceptación

### CA-01 · Aparición automática de nuevas facturas
- Cuando el sistema procesa y publica una nueva factura disponible, esta **debe aparecer automáticamente en el tope de la lista** sin que la ejecutiva refresque la página.
- La tarjeta nueva debe tener una **animación de entrada** (destello azul suave) para que la ejecutiva note visualmente que es un elemento nuevo.

### CA-02 · Información visible en cada tarjeta
Cada tarjeta de factura debe mostrar, como mínimo:
| Campo | Descripción |
|---|---|
| **Folio** | Número de identificación de la factura (ej: #45902) |
| **Razón Social del Deudor** | Nombre de la empresa que debe pagar, truncado si es largo |
| **RUT del Deudor** | Visible al pasar el mouse sobre la razón social (tooltip) |
| **Monto total** | Formateado en pesos chilenos (ej: $12.500.000) |
| **Contador regresivo** | Tiempo restante para poder ofertar sobre esa factura |

### CA-03 · Comportamiento del contador regresivo
- Si quedan **más de 5 horas** para el cierre: el contador se muestra en **color verde**.
- Si quedan **menos de 60 minutos** para el cierre: el contador se muestra en **color rojo parpadeante** para generar urgencia.

### CA-04 · Indicador de competencia (tracción del mercado)
- Si **otras ejecutivas ya ofertaron** sobre esa factura: la tarjeta muestra el texto `N ofertas — Tasa a batir: X.XX%`, donde N es el número de ofertas y X.XX% es la tasa más baja existente.
- Si **nadie ha ofertado**: se muestra un badge gris con el texto `Sin ofertas activas`.

### CA-05 · Selección de factura
- Al hacer clic sobre cualquier tarjeta de la lista, la **Columna 2 (Centro de Verificación)** debe actualizarse instantáneamente con los datos de esa factura sin recargar la página.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Desconexión de red** | Si la conexión en tiempo real se interrumpe, ¿la lista muestra un aviso de "Desconectado" o simplemente deja de actualizarse sin notificar? ¿Se intenta reconexión automática? |
| EB-02 | **Volumen extremo de facturas** | Si el sistema publica 50 facturas en 10 segundos (ej: carga masiva matutina), ¿se agrupan en un lote o llegan una por una saturando la pantalla con animaciones? |
| EB-03 | **Factura retirada mientras está en lista** | Si un cliente retira su factura del mercado después de que ya apareció en la lista, ¿la tarjeta desaparece automáticamente o se marca como "No disponible"? |
| EB-04 | **Contador llega a cero** | Cuando el tiempo para ofertar expira, ¿la tarjeta desaparece de la lista, se bloquea o se mueve a una sección de "Cerradas"? |
| EB-05 | **Empate de tasa** | Si dos ejecutivas ingresan exactamente la misma tasa al mismo tiempo, ¿cuál gana? ¿Se define por orden de llegada al servidor? ¿Se notifica a la perdedora? |
| EB-06 | **Monto máximo de la tarjeta** | ¿Existe un monto máximo de factura que puede aparecer en el marketplace? ¿Hay alguna restricción por perfil de ejecutiva (solo ve facturas hasta cierto monto)? |
| EB-07 | **Zona horaria** | El contador regresivo, ¿está sincronizado con el servidor (hora Chile continental) o usa la hora local del dispositivo de la ejecutiva? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- La comunicación en tiempo real debe implementarse vía **WebSocket** (canal persistente desde el orquestador en Go hacia el frontend en Angular).
- El scroll de la columna 1 es **independiente** del resto de la pantalla (overflow-y scroll con altura fija).
- Las tarjetas son un **scroll infinito** (virtual scrolling recomendado si el volumen es alto).

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
