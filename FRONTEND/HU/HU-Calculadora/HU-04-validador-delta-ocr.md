# HU-04 — Validador Delta OCR (Verificación Inteligente de Datos)

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** ver en pantalla una comparación automática entre los datos que el cliente declaró al subir la factura y los datos que el sistema leyó desde el documento real,
**Para** detectar de inmediato si hay inconsistencias entre lo declarado y lo real, y proteger a la empresa de financiar facturas con información incorrecta.

---

## Criterios de Aceptación

### CA-01 · Visualización del mapeo de datos
- En la parte inferior de la Columna 2, el sistema debe mostrar una **tabla comparativa** con los campos clave de la factura:
  - RUT del Emisor (cliente)
  - RUT del Deudor
  - Monto total de la factura
  - Fecha de emisión
  - Fecha de vencimiento

### CA-02 · Resultado de coincidencia — Datos correctos
- Para cada campo donde el dato **declarado por el cliente y el dato leído por el OCR coincidan exactamente**, el sistema muestra:
  - El valor en texto plano.
  - Un **check de color verde** (✓) junto al campo.
  - Sin mensaje adicional de alerta.

### CA-03 · Resultado de discrepancia — Alerta visible
- Para cada campo donde el dato declarado **no coincida** con el dato extraído por el OCR, el sistema debe:
  - Pintar ese campo con un fondo de color **naranja o rojo** para llamar la atención.
  - Mostrar ambos valores lado a lado con etiquetas claras:
    - `Declarado por cliente: [valor]`
    - `Leído por OCR: [valor]`
  - Mostrar un texto de alerta descriptivo. Ejemplo:
    > `Alerta: El vencimiento declarado es 30 días mayor al leído por el OCR. Verificar documento original.`

### CA-04 · Alerta de plazo menor (regla de negocio crítica)
- Si el campo de **fecha de vencimiento** leído por el OCR es **anterior** a la fecha declarada por el cliente (el cliente inflló artificialmente el plazo), el sistema debe resaltar esto como una **alerta de alta prioridad** (color rojo, ícono de advertencia).
- Esta alerta específica debe tener el texto: `"Alerta: El plazo real es menor al declarado. Revisar antes de ofertar."`.

### CA-05 · Estado cuando no hay discrepancias
- Si todos los campos coinciden, la sección muestra un banner verde con el mensaje: `"Documento validado — Todos los campos coinciden con el OCR."`.

### CA-06 · Estado cuando el OCR no pudo leer el campo
- Si el motor OCR no pudo extraer un campo específico (confianza baja o campo ilegible), el sistema debe mostrar ese campo con el valor `"No legible"` en color gris, sin marcarlo como error ni como correcto.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Diferencias menores de formato** | Si el cliente escribió `"10.000.000"` y el OCR leyó `"$10.000.000"`, ¿el sistema lo trata como error o como coincidencia? La lógica de comparación debe normalizar los formatos antes de comparar. |
| EB-02 | **OCR aún procesando** | Si la ejecutiva abre la factura antes de que el OCR termine, ¿qué muestra el validador? ¿Un estado de "Procesando" o simplemente vacío? |
| EB-03 | **Factura con múltiples montos** | Algunas facturas incluyen subtotales, IVA y total. ¿El OCR extrae el monto total neto, el bruto o todos? ¿Cuál se compara con el declarado? |
| EB-04 | **Discrepancia tolerable de monto** | ¿Existe un margen de tolerancia aceptable para diferencias de monto (ej: ±$1 por redondeo)? Si no se define, cualquier diferencia mínima generará una alerta falsa. |
| EB-05 | **Factura en otro idioma o moneda** | Si algún proveedor emite facturas en dólares o en inglés, ¿el OCR y el validador soportan ese formato? |
| EB-06 | **Trazabilidad de la alerta** | Cuando la ejecutiva ve una alerta de discrepancia y aun así decide ofertar, ¿el sistema registra en el historial que tomó la decisión con una alerta activa? |
| EB-07 | **Score de confianza del OCR** | ¿El sistema expone el porcentaje de confianza del OCR por campo? Si el OCR dice "99% seguro", ¿se muestra de forma diferente a uno con 60% de certeza? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Los datos del OCR son producidos por el **motor de Rust** del orquestador. El backend (NestJS) debe exponer un endpoint que retorne tanto los datos declarados como los datos del OCR en un mismo objeto para que el frontend los compare.
- La lógica de comparación y normalización (formatos de moneda, fechas, RUT) debe realizarse en el **frontend** como Signal derivado para respuesta inmediata, no en el servidor.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
