# HU-06 — Calculadora de Parámetros de Liquidación (Inputs)

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** ingresar los parámetros de mi oferta (porcentaje de anticipo, tasa de interés y gastos) en un formulario que calcule los resultados al instante,
**Para** simular diferentes escenarios de rentabilidad antes de comprometer una oferta firme, sin necesidad de abrir una hoja de cálculo externa.

---

## Criterios de Aceptación

### CA-01 · Campo "Porcentaje de Anticipo"
- El campo debe ser un **input numérico combinado con un deslizador (slider)**.
- El rango permitido es de **10% a 100%**.
- El valor por defecto al cargar una factura es **100%**.
- Al mover el slider o cambiar el número, el sistema debe calcular y mostrar de inmediato:
  - **Monto a anticipar** = `Monto factura × % anticipo`.
  - **Excedente retenido** = `Monto factura × (100% − % anticipo)`.
- El "excedente retenido" representa el dinero que queda bloqueado hasta que el deudor pague. Debe mostrarse con esa etiqueta de forma visible.

### CA-02 · Campo "Tasa de Interés Mensual (%)"
- Input decimal con hasta **dos decimales** (ej: `2.35`).
- No puede ser negativo ni mayor al límite legal vigente (el máximo debe ser configurable por el administrador, no hardcodeado).
- Representa el costo del dinero por mes. Es la base para calcular la **Diferencia de Precio (Interés)**.

### CA-03 · Campos de Comisiones y Gastos
Los siguientes campos son inputs de monto en pesos chilenos ($), todos opcionales y con valor por defecto en `$0`:
- **Comisión de Estructuración ($)**
- **Gastos Operacionales ($)**
- **Gasto de Contrato ($)**
- **Gasto de Apertura ($)** *(aplica solo para clientes nuevos; puede venir pre-llenado por el sistema según el perfil del cliente)*

Todos estos campos deben aceptar solo valores numéricos positivos.

### CA-04 · Recálculo instantáneo (< 16 ms)
- Al modificar **cualquier campo** del formulario, los resultados de la Pre-Liquidación (Columna 3, sección inferior) deben actualizarse **en tiempo real**, sin hacer llamadas al servidor.
- El recálculo completo (incluyendo IVA, interés y giro líquido) debe reflejarse en pantalla antes de 16 milisegundos (un frame de animación a 60 fps).

### CA-05 · Validación del formulario
- Los campos no pueden quedar vacíos; si el usuario borra el valor, el sistema debe **restaurar el valor en 0** (no dejar el campo en blanco ni en estado inválido que rompa el cálculo).
- El sistema no debe permitir un porcentaje de anticipo que genere un monto anticipado mayor al cupo disponible del deudor (validación cruzada con HU-05).

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Gasto de apertura condicional** | ¿El sistema detecta automáticamente si el cliente es nuevo para pre-llenar el Gasto de Apertura, o la ejecutiva siempre lo ingresa manualmente? ¿Qué pasa si la ejecutiva lo borra manualmente? |
| EB-02 | **Tasa máxima legal** | ¿Cuál es la tasa máxima mensual permitida legalmente en Chile para este producto? Este valor debe quedar parametrizable en el sistema de administración, no en el código. |
| EB-03 | **Anticipo mínimo del 10%** | ¿Por qué el mínimo es 10%? ¿Es una regla de negocio propia o un mínimo regulatorio? Confirmarlo para documentarlo correctamente. |
| EB-04 | **Cambio de factura con formulario lleno** | Si la ejecutiva tiene todos los campos llenos y hace clic en otra factura del marketplace, ¿los valores del formulario se reinician o se conservan para la nueva factura? |
| EB-05 | **Comisión porcentual vs. monto fijo** | La especificación menciona "Comisión de Estructuración ($)". ¿Esta comisión puede ser también porcentual sobre el monto anticipado en lugar de un monto fijo? ¿La ejecutiva elige el modo? |
| EB-06 | **Plazo de la operación** | La Pre-Liquidación muestra "Plazo de la Operación: 45 días". ¿Este plazo es el de vencimiento de la factura según el OCR, o la ejecutiva puede modificarlo? |
| EB-07 | **Guardar simulación** | ¿La ejecutiva puede guardar o exportar los parámetros de una simulación sin enviar la oferta? (funcionalidad para análisis posterior o consulta con su jefe). |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Toda la lógica de cálculo debe vivir en el **frontend** usando **Angular Signals** para reactividad de alta performance.
- No se debe hacer un `HTTP request` al servidor para recalcular; el servidor solo interviene al momento de enviar la oferta firme.
- Los límites de campos (tasa máxima, anticipo mínimo) deben cargarse desde el backend como configuración al iniciar la sesión.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
