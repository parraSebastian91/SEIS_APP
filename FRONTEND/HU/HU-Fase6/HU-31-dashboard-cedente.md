# HU-31 — Dashboard Cedente

> **Fase**: 6 — `mfe-dashboard-facturas` | **Ruta**: `/dashboard/cedente` | **Rol**: Cliente (cedente)

---

## Historias de Usuario

- **`US-D01`** — Como cliente, quiero ver un resumen de mis facturas por estado, para entender el estado de mi pipeline de financiamiento de un vistazo.
- **`US-D02`** — Como cliente, quiero ver el capital total recibido vía factoring en un período, para controlar mi flujo de caja.
- **`US-D03`** — Como cliente, quiero ver alertas de facturas próximas a vencer sin ofertas, para actuar antes de que pierdan interés.

---

## Contexto técnico

El dashboard del cedente es la pantalla principal del MFE `mfe-dashboard-facturas` cuando el usuario autenticado tiene rol **cedente**. Se carga al navegar a `/dashboard`.

Endpoints:
- `GET /api/core/dashboard/cedente?periodo={periodo}` — devuelve todos los KPIs del bloque del período.
- `GET /api/core/dashboard/cedente/pipeline` — conteo de facturas por estado (independiente del período).

---

## Criterios de Aceptación

### CA-01 · Selector de período

Opciones disponibles (pill toggle en la parte superior del dashboard):

| Opción | Etiqueta visible |
|--------|-----------------|
| `1m` | Último mes |
| `3m` | Últimos 3 meses |
| `6m` | Últimos 6 meses |
| `ytd` | Este año |
| `all` | Todo |

- Default al cargar: `"Último mes"`.
- Al cambiar el período: se re-fetchen los KPIs del período y se muestra un skeleton mientras cargan. El bloque de pipeline (CA-02) **no** se re-fetcha (no depende del período).
- El período seleccionado persiste en el estado local del componente durante la sesión.

### CA-02 · Bloque "Pipeline de Facturas" (independiente del período)

Conteo de facturas activas agrupadas por estado:

| Estado | Etiqueta visible |
|--------|-----------------|
| `PUBLICADA` | Publicadas |
| `OFERTADA` | Con oferta |
| `FINANCIADA` | Financiadas |
| `PENDIENTE_VERIFICACION_PAGO` | Verificando pago |

- Presentación sugerida: 4 tarjetas/chips en fila con el conteo numérico prominente y la etiqueta debajo.
- Si un estado tiene conteo 0: mostrar igualmente la tarjeta con `"0"` (no ocultar).
- El clic en una tarjeta de estado navega a `/publicador?estado={estado}` (filtro rápido del MFE publicador).

### CA-03 · KPIs del período

| KPI | Descripción | Formato |
|-----|-------------|---------|
| **Capital por recibir** | Suma de `montoAnticipado` de facturas en `FINANCIADA` + `PENDIENTE_VERIFICACION_PAGO` (sin filtro de período) | CLP sin decimales |
| **Capital recibido** | Suma de `montoAnticipado` de facturas `PAGADA` en el período seleccionado | CLP sin decimales + variación % |
| **Costo promedio de financiamiento** | Tasa ponderada promedio de las ofertas aceptadas en el período | `X.XX% mensual` + variación % |
| **Tiempo promedio para financiarse** | Días promedio entre `PUBLICADA` y `FINANCIADA` en el período | `X días` + variación % |

**Variación porcentual**: todos los KPIs marcados con `+ variación %` muestran la diferencia respecto al período anterior del mismo largo:
- Ejemplo: si el período activo es `"Último mes"`, la variación compara con el mes anterior.
- Formato: `+12% vs período anterior` (verde) / `-8% vs período anterior` (rojo) / `sin cambios` (gris).
- Si no hay datos para el período anterior: omitir la etiqueta de variación (no mostrar `"N/A"`).
- Capital por recibir no tiene variación % (es una instantánea actual, no del período).

### CA-04 · Alerta de Facturas en Riesgo (`⚠️ Facturas en riesgo`)

- Se muestra como una sección de alerta destacada **si y solo si** existen facturas en `PUBLICADA` con menos de **N días** al vencimiento sin ninguna oferta.
- `N` es configurable desde backend (ej. 5 días). No hardcodear.
- La alerta lista las facturas en riesgo:
  ```
  ⚠️  3 facturas próximas a vencer sin ofertas
  ─────────────────────────────────────────────────────
  #45123 — CENCOSUD S.A. — vence en 2 días — $4.500.000
  #45902 — SODIMAC CORP — vence en 3 días — $2.100.000
  #46001 — RIPLEY S.A.  — vence en 4 días — $1.800.000
  ─────────────────────────────────────────────────────
  [ Ver mis facturas publicadas → ]
  ```
- Cada fila es clic para navegar a `/publicador/factura/:id`.
- El botón `"Ver mis facturas publicadas"` navega a `/publicador`.
- Si no hay facturas en riesgo: no se muestra la sección (no renderizar el contenedor vacío).

### CA-05 · Estados de carga y error

- Al cargar la página por primera vez: skeleton de cada bloque (pipeline + KPIs + alerta).
- Si el endpoint de KPIs falla: mostrar estado de error con botón `"Reintentar"` por bloque afectado (pipeline y KPIs son llamadas independientes — un fallo no debe ocultar el otro bloque).
- Si todos los KPIs son cero (ej. primer ingreso): empty state amigable `"Aún no tienes operaciones registradas. Publica tu primera factura."` con CTA a `/publicador`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El cedente no tiene facturas en ningún estado** | Mostrar empty state en el bloque de pipeline y en los KPIs (CA-05). La alerta de riesgo no se muestra. |
| EB-02 | **No hay datos del período anterior para calcular variación** | Omitir la etiqueta de variación para ese KPI (no mostrar `"N/A"` ni `"—"`). |
| EB-03 | **Un ejecutivo accede a `/dashboard`** | El shell redirige a `/dashboard/ejecutivo` según el rol en el `SessionService`. El dashboard cedente no es accesible para ejecutivos. |
| EB-04 | **El período "Todo" no tiene período anterior comparable** | No mostrar variaciones % para ningún KPI cuando el período es `"Todo"`. |

---

## Componentes

| Componente | Descripción |
|------------|-------------|
| `DashboardCedenteComponent` | Contenedor principal de la ruta `/dashboard/cedente` |
| `PeriodSelectorComponent` | Pill toggle reutilizable con las 5 opciones de período |
| `PipelineSummaryComponent` | 4 tarjetas de estado de pipeline |
| `KpiCardComponent` | Tarjeta individual de KPI (valor + etiqueta + variación %) — reutilizable en HU-33 |
| `RiskAlertComponent` | Sección de alerta de facturas en riesgo |

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 6 — mfe-dashboard-facturas*
