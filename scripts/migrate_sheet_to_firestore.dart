/// Migration script: Google Sheets → Firestore
///
/// Usage:
///   1. Export your Google Sheet as CSV
///   2. Place the CSV file as 'cofrades_data.csv' in this directory
///   3. Run: dart run scripts/migrate_sheet_to_firestore.dart
///
/// The CSV should have columns (matching your Google Sheet):
///   Nº, Nombre, Apellidos, Tutelado Digital, Fecha Nacimiento, Edad,
///   Género, Año Alta, Años Hermandad, Año Mayordomía, Estado,
///   Fecha Baja, Causa Baja, Domicilio, Localidad, Código Postal,
///   Teléfono Fijo, Teléfono Móvil, Email, Estatura, Talla,
///   ¿Cuota?, Cuota Metálico, Cuota Domiciliada, IBAN,
///   Titular IBAN, GDPR Firmado, Comentarios
///
/// This script reads the CSV and imports each row as a document
/// in the Firestore 'cofrades' collection.
///
/// NOTE: This script is meant to be run once for initial data migration.
/// After migration, the bidirectional sync Cloud Function keeps
/// Firestore and Google Sheets in sync.

import 'dart:io';
import 'dart:convert';

void main() async {
  final csvFile = File('scripts/cofrades_data.csv');

  if (!csvFile.existsSync()) {
    print('ERROR: No se encontró el archivo cofrades_data.csv');
    print('');
    print('Pasos para migrar los datos:');
    print('1. Abre tu Google Sheet con los datos de cofrades');
    print('2. Archivo → Descargar → Valores separados por comas (.csv)');
    print('3. Guarda el archivo como scripts/cofrades_data.csv');
    print('4. Vuelve a ejecutar este script');
    print('');
    print('El CSV debe tener estas columnas (en este orden):');
    print('Nº, Nombre, Apellidos, Tutelado Digital, Fecha Nacimiento,');
    print('Edad, Género, Año Alta, Años Hermandad, Año Mayordomía,');
    print('Estado, Fecha Baja, Causa Baja, Domicilio, Localidad,');
    print('Código Postal, Teléfono Fijo, Teléfono Móvil, Email,');
    print('Estatura, Talla, ¿Cuota?, Cuota Metálico, Cuota Domiciliada,');
    print('IBAN, Titular IBAN, GDPR Firmado, Comentarios');
    exit(1);
  }

  final lines = csvFile.readAsLinesSync();
  if (lines.isEmpty) {
    print('El archivo CSV está vacío.');
    exit(1);
  }

  // Skip header row
  final header = lines[0].split(',');
  print('Columnas detectadas: ${header.join(", ")}');
  print('Total filas de datos: ${lines.length - 1}');
  print('');

  final cofrades = <Map<String, dynamic>>[];

  for (int i = 1; i < lines.length; i++) {
    final values = _parseCsvLine(lines[i]);
    if (values.isEmpty || values.every((v) => v.trim().isEmpty)) continue;

    final cofrade = {
      'numero': int.tryParse(_getValue(values, 0)),
      'nombre': _getValue(values, 1),
      'apellidos': _getValue(values, 2),
      'tutelado_digital': _getValue(values, 3),
      'fecha_nacimiento': _getValue(values, 4),
      'edad': int.tryParse(_getValue(values, 5)),
      'genero': _getValue(values, 6),
      'anio_alta': int.tryParse(_getValue(values, 7)),
      'anios_hermandad': int.tryParse(_getValue(values, 8)),
      'anio_mayordomia': int.tryParse(_getValue(values, 9)),
      'estado': _getValue(values, 10, defaultValue: 'Activo'),
      'fecha_baja': _getValue(values, 11),
      'causa_baja': _getValue(values, 12),
      'domicilio': _getValue(values, 13),
      'localidad': _getValue(values, 14, defaultValue: 'Ocaña'),
      'codigo_postal': _getValue(values, 15),
      'telefono_fijo': _getValue(values, 16),
      'telefono_movil': _getValue(values, 17),
      'email': _getValue(values, 18),
      'estatura': int.tryParse(_getValue(values, 19)),
      'talla': _getValue(values, 20),
      'tiene_cuota': _getValue(values, 21).toLowerCase() == 'sí',
      'cuota_metalico': double.tryParse(_getValue(values, 22)),
      'cuota_domiciliada': double.tryParse(_getValue(values, 23)),
      'iban': _getValue(values, 24),
      'titular_iban': _getValue(values, 25),
      'gdpr_firmado': _getValue(values, 26).toLowerCase() == 'sí',
      'comentarios': _getValue(values, 27),
      'rol': 'cofrade',
    };

    cofrades.add(cofrade);
    print('  [$i] ${cofrade["nombre"]} ${cofrade["apellidos"]} - ${cofrade["email"]}');
  }

  print('');
  print('Se encontraron ${cofrades.length} cofrades para migrar.');
  print('');
  print('Para importar estos datos a Firestore, tienes dos opciones:');
  print('');
  print('OPCIÓN 1: Importar via Firebase Console');
  print('  1. Ve a console.firebase.google.com → Firestore');
  print('  2. Crea la colección "cofrades"');
  print('  3. Añade cada documento manualmente o usa la herramienta de importación');
  print('');
  print('OPCIÓN 2: Importar via script de Node.js con Firebase Admin SDK');
  print('  El archivo JSON generado se encuentra en: scripts/cofrades_export.json');
  print('  Puedes importarlo con el script functions/import_data.js');

  // Generate JSON export for Firebase import
  final jsonFile = File('scripts/cofrades_export.json');
  final encoder = JsonEncoder.withIndent('  ');
  jsonFile.writeAsStringSync(encoder.convert(cofrades));
  print('');
  print('Archivo JSON generado: scripts/cofrades_export.json');
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var current = StringBuffer();
  var inQuotes = false;

  for (int i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString().trim());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString().trim());
  return result;
}

String _getValue(List<String> values, int index, {String defaultValue = ''}) {
  if (index >= values.length) return defaultValue;
  final value = values[index].trim();
  return value.isEmpty ? defaultValue : value;
}
