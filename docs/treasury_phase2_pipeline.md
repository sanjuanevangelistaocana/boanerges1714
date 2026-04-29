# Tesorería fase 2: pipeline histórico y mapeo a Firestore

## Pipeline Apps Script

1. **Domiciliaciones**
   - Consume `Relación Cofrades`.
   - Filtra cofrades activos con cuota domiciliada.
   - Genera la hoja `Domiciliaciones` con número, nombre, apellidos, dirección, email, titular del IBAN e IBAN.

2. **Efectivo**
   - Consume `Relación Cofrades`.
   - Filtra cofrades activos con cuota en metálico.
   - Excluye altas de 2023.
   - Genera la hoja `Efectivo` con datos básicos de referencia y contacto.

3. **Remesa Tesorería**
   - Consume `Domiciliaciones`.
   - Agrupa por IBAN.
   - Calcula importe como número de cofrades del grupo por la cuota anual histórica.
   - Genera concepto con el año y la relación de cofrades incluidos.

4. **Facturas**
   - Consume `Remesa Tesorería`.
   - Genera la hoja `Facturas PDF`.
   - Enmascara IBAN y asigna número de factura secuencial.
   - Expande hasta 10 cofrades por factura para la plantilla documental.

5. **Relación Facturas**
   - Consume `Domiciliaciones` y `Facturas PDF`.
   - Relaciona cada cofrade domiciliado con su factura.
   - Usa titular/email para localizar la factura correspondiente.

6. **Generación Docs**
   - Consume `Facturas PDF`.
   - Copia una plantilla de Google Docs y sustituye placeholders.
   - No se migra en esta fase.

7. **Generación PDFs**
   - Convierte documentos generados a PDF.
   - No se migra en esta fase.

8. **Generación Remesa Santander**
   - Consume `Domiciliaciones` y `Facturas PDF`.
   - Reagrupa por IBAN y genera la estructura bancaria Santander.
   - No se migra en esta fase, pero se preservan `ibanHash`, `ibanMasked`, `invoiceNumber`, `holderName`, `concept` y líneas para soportarla después.

## Mapeo a Firestore

- `treasury_settings`: sustituye valores hardcodeados, especialmente cuota anual y año.
- `treasury_invoices`: representa cada factura agrupada.
  - Domiciliadas: una factura por IBAN agrupado.
  - Efectivo: una factura por cofrade.
  - No guarda IBAN completo; solo `ibanMasked` e `ibanHash`.
  - Numeración adaptada a `TES-{year}-{sequence}`.
- `treasury_invoice_lines`: representa el detalle por cofrade, sin límite de 10 líneas.
- `treasury_payments`: reservado para pagos posteriores, especialmente efectivo/cobros.
- `treasury_audit_logs`: registra generación, regeneración, aprobación y cancelación.

## Reglas migradas

- Solo se generan cuotas para cofrades activos con cuota.
- Domiciliados con IBAN se agrupan por IBAN normalizado.
- Domiciliados sin IBAN pasan a factura de efectivo con advertencia.
- Cofrades con cuota en metálico se facturan individualmente.
- Altas de 2023 en efectivo se excluyen, siguiendo el pipeline histórico.
- Las líneas nacen en estado `pending`.
- Las facturas nacen en estado `draft` y pueden aprobarse a `approved`.
- La regeneración cancela facturas activas anteriores y crea una nueva versión.

## Diferencias controladas

- La cuota ya no se hardcodea a 22; se lee desde `treasury_settings.annualFeeAmount`.
- El formato antiguo `SJ-{year}-{NNN}` se adapta a `TES-{year}-{NNNN}` para el módulo nuevo.
- Firestore permite más de 10 cofrades por factura; se genera advertencia si una agrupación supera ese límite porque la plantilla antigua solo contemplaba 10 columnas.
- El hash de IBAN es determinista para agrupar sin almacenar el dato completo en facturas.
