# HU-02 — Filtros Rápidos del Marketplace de Facturas

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** poder filtrar el listado de facturas disponibles con un solo clic usando categorías predefinidas de mi interés,
**Para** enfocar mi atención en las oportunidades más rentables o urgentes sin perder tiempo buscando manualmente.

---

## Criterios de Aceptación

### CA-01 · Disponibilidad de los filtros
- La cabecera del listado (Columna 1) debe mostrar **tres botones de acceso rápido** siempre visibles, sin necesidad de abrir menús adicionales.
- Los botones son: **"Mis Preferidas"**, **"Alta Liquidez"** y **"Reloj de Arena"**.

### CA-02 · Comportamiento del filtro "Mis Preferidas"
- Muestra únicamente las facturas cuyos deudores han sido marcados previamente como preferidos por esa ejecutiva.
- La configuración de "deudores preferidos" es **personal de cada ejecutiva**: lo que ve una, no lo ve otra.
- Si la ejecutiva no tiene deudores marcados como preferidos, se muestra un mensaje orientativo: `"Aún no tienes deudores favoritos. Márcalos desde el perfil del deudor."`.

### CA-03 · Comportamiento del filtro "Alta Liquidez"
- Muestra facturas emitidas contra **grandes corporaciones** con historial de pago confirmado y puntual en el sistema.
- El criterio de "alta liquidez" debe estar definido por el negocio (ej: deudores con promedio de pago ≤ 30 días y sin mora histórica). **El umbral exacto debe ser configurable por el administrador del sistema, no hardcodeado.**

### CA-04 · Comportamiento del filtro "Reloj de Arena"
- Ordena la lista de facturas de forma **ascendente por tiempo restante para ofertar** (las que vencen primero aparecen arriba).
- Este filtro **no oculta facturas**, solo reordena la lista completa.

### CA-05 · Estado visual del filtro activo
- El botón del filtro actualmente seleccionado debe tener un **estado visual diferenciado** (ej: fondo resaltado, borde de color) para que la ejecutiva sepa qué criterio está aplicado.
- Solo puede haber **un filtro activo a la vez**. Al hacer clic en un filtro ya activo, se desactiva y se vuelve a la vista completa sin filtros.

### CA-06 · Compatibilidad con actualizaciones en tiempo real
- Los filtros deben **mantenerse activos** mientras llegan nuevas facturas en tiempo real (WebSocket). Una nueva factura solo debe aparecer en la lista filtrada si cumple el criterio del filtro activo.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Sin resultados en filtro** | Si un filtro no retorna ninguna factura (ej: "Mis Preferidas" y ningún deudor favorito está en el mercado hoy), ¿se muestra un estado vacío ilustrado o un simple texto? |
| EB-02 | **Cambio de filtro con factura seleccionada** | Si la ejecutiva tiene la factura #45902 abierta en la Columna 2 y cambia el filtro (haciendo que esa factura desaparezca del listado), ¿la Columna 2 se limpia, queda como estaba o muestra un aviso? |
| EB-03 | **Definición de "gran corporación"** | ¿Quién y cuándo actualiza la lista de deudores "Alta Liquidez"? ¿Es un proceso automático basado en datos o lo mantiene manualmente un administrador? |
| EB-04 | **Persistencia del filtro** | Si la ejecutiva cierra la pestaña y vuelve al sistema, ¿el filtro que tenía activo se recuerda (sesión persistente) o siempre inicia sin filtros? |
| EB-05 | **Combinación de filtros** | ¿El roadmap contempla poder combinar filtros en el futuro (ej: "Mis Preferidas" + "Reloj de Arena")? Definirlo ahora evita retrabajos en el diseño. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Los filtros deben operar sobre el **estado local del listado** (ya descargado en el cliente) para dar respuesta inmediata, salvo "Mis Preferidas" que puede requerir una consulta al backend si la lista de preferidas es dinámica.
- El criterio de "Alta Liquidez" debe exponerse como un parámetro configurable en el panel de administración del sistema.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
