# HU-33 — Dashboard Ejecutivo

> **Fase**: 6 — `mfe-dashboard-facturas` | **Ruta**: `/dashboard/ejecutivo` | **Rol**: Ejecutivo financiero

---

## Historias de Usuario

- **`US-D07`** — Como ejecutivo, quiero ver el capital que tengo desplegado actualmente, para controlar mi exposición total.
- **`US-D08`** — Como ejecutivo, quiero ver mi cupo disponible frente al desplegado, para saber si tengo capacidad para nuevas operaciones.
- **`US-D09`** — Como ejecutivo, quiero ver mis retornos acumulados en el período, para medir la rentabilidad de mi cartera.
- **`US-D10`** — Como ejecutivo, quiero ver mi pipeline de ofertas activas, para priorizar el seguimiento de las que aún no tienen respuesta.

---

## Contexto técnico

El dashboard del ejecutivo es la pantalla principal del MFE `mfe-dashboard-facturas` cuando el usuario autenticado tiene rol **ejecutivo**. Se carga al navegar a `/dashboard`.

Endpoints:
- `GET /api/core/dashboard/ejecutivo?periodo={periodo}` — devuelve todos los KPIs del período.
- `GET /api/core/dashboard/ejecutivo/cartera` — datos de cartera activa (sin filtro de período).

---

## Criterios de Aceptación

### CA-01 · Selector de período

Mismo componente `PeriodSelectorComponent` de HU-31 con las mismas 5 opciones:

`Último mes` / `Últimos 3 meses` / `Últimos 6 meses` / `Este año` / `Todo`

- Default al cargar: `"Último mes"`.
- Al cambiar el período: re-fetchea los KPIs de período. El bloque de cartera activa (CA-02) **no** se re-fetcha.
- Sin variaciones % cuando el período es `"Todo"` (ver HU-31 EB-04).

### CA-02 · Bloque de Cartera Activa (instantánea, sin filtro de período)

| KPI | Descripción | Formato |
|-----|-------------|---------|
| **Capital desplegado** | Suma de `montoAnticipado` de operaciones en `FINANCIADA` + `PENDIENTE_VERIFICACION_PAGO` | CLP sin decimales |
| **Capital disponible** | Cupo total configurado − capital desplegado | CLP sin decimales |
| **Ofertas activas** | Conteo de ofertas en estado `ACTIVA` (enviadas, sin respuesta) | número entero |
| **Tasa promedio de cartera** | Tasa ponderada de las operaciones activas (ponderada por `montoAnticipado`) | `X.XX% mensual` |

Visualización sugerida: barra de progreso o donut chart mostrando `capital desplegado / cupo total` + los 4 valores debajo o al lado.

- Si `cupoTotal` no está configurado para el ejecutivo: ocultar la barra de progreso y mostrar solo el capital desplegado con nota `"(sin límite configurado)"`.
- Si capital desplegado = 0: barra en 0%, texto `"Sin operaciones activas."`.

### CA-03 · KPIs del período

| KPI | Descripción | Formato |
|-----|-------------|---------|
| **Retorno proyectado** | Suma de intereses esperados de la cartera activa (interés × días restantes por factura) | CLP sin decimales |
| **Retorno realizado** | Intereses cobrados de facturas `PAGADA` en el período | CLP sin decimales + variación % |
| **Operaciones cerradas** | Facturas que llegaron a `PAGADA` en el período | número entero + variación % |
| **Ticket promedio** | Monto anticipado promedio por operación cerrada en el período | CLP sin decimales + variación % |

**Variación porcentual**: mismas reglas que HU-31 CA-03. Verde si mejora, rojo si empeora, gris si no hay cambio.

> **Nota**: "Retorno proyectado" es una instantánea de la cartera activa actual — no varía con el selector de período. Sin embargo, se incluye aquí por afinidad temática con los retornos. Si el equipo prefiere moverlo al bloque de cartera (CA-02), es válido.

### CA-04 · Panel de ofertas activas sin respuesta

Si el ejecutivo tiene ofertas en estado `ACTIVA`, se muestra un panel `"Pipeline en espera"`:

```
Pipeline en espera  (4 ofertas sin respuesta)
─────────────────────────────────────────────────────────
#45902 — CENCOSUD S.A.  $10.150.413  2.10%  hace 2 días
#46011 — SODIMAC CORP   $5.320.000   1.95%  hace 1 día
#46234 — RIPLEY S.A.    $2.100.000   2.40%  hace 4 días
#46501 — FALABELLA S.A. $3.600.000   2.05%  hace 6 días
─────────────────────────────────────────────────────────
[ Ver todas mis ofertas → ]
```

- Muestra máximo 5 filas. Si hay más: botón `"Ver todas mis ofertas →"` a `/dashboard/mis-ofertas?estado=ACTIVA`.
- El campo `"hace X días"` se calcula en el cliente desde `fechaOferta`.
- Si no hay ofertas activas: no se muestra el panel.
- Clic en una fila: navega a `/ofertador` con la factura seleccionada, o abre el chat si ya existe conversación.

### CA-05 · Estados de carga y error

- Al cargar por primera vez: skeleton de cada bloque (cartera + KPIs + pipeline).
- Si el endpoint de KPIs falla: error inline con `"Reintentar"` por bloque (cartera y KPIs son llamadas independientes).
- Empty state general (ejecutivo sin ninguna operación): `"Aún no tienes operaciones registradas. Encuentra facturas en el marketplace."` con CTA a `/ofertador`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Cupo total no configurado para el ejecutivo** | Ver CA-02 — se muestra capital desplegado sin barra ni capital disponible. |
| EB-02 | **Retorno proyectado cuando no hay cartera activa** | Mostrar `$0` sin variación % (es una instantánea, no del período). |
| EB-03 | **Un cedente accede a `/dashboard/ejecutivo`** | El shell redirige a `/dashboard/cedente` según el rol. La ruta `/ejecutivo` no es accesible para cedentes. |
| EB-04 | **Ticket promedio cuando `operaciones cerradas = 0` en el período** | Mostrar `"—"` en lugar de `$0` para evitar confusión (0 operaciones → no hay ticket calculable). |

---

## Componentes

| Componente | Descripción |
|------------|-------------|
| `DashboardEjecutivoComponent` | Contenedor principal de la ruta `/dashboard/ejecutivo` |
| `PeriodSelectorComponent` | Reutilizado de HU-31 |
| `KpiCardComponent` | Reutilizado de HU-31 (valor + etiqueta + variación %) |
| `CarteraActivaSummaryComponent` | Bloque de cartera activa con barra de progreso |
| `ActivaOffersPipelineComponent` | Panel "Pipeline en espera" con lista de ofertas activas |

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 6 — mfe-dashboard-facturas | Refs: HU-32 (Mis Ofertas)*
