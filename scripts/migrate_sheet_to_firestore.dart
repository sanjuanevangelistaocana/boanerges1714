/// Migration script: Google Sheets → Firestore
///
/// Usage:
///   1. Export your Google Sheet as CSV
///   2. Place the CSV file as 'cofrades_data.csv' in this directory
///   3. Run: dart run scripts/migrate_sheet_to_firestore.dart
///
/// The CSV should have columns:
///   Nombre, Apellidos, Email, Teléfono, Dirección, Localidad,
///   Código Postal, Fecha Ingreso, Cargo, Estado
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
    print('Nombre, Apellidos, Email, Teléfono, Dirección, Localidad,');
    print('Código Postal, Fecha Ingreso, Cargo, Estado');
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
      'nombre': _getValue(values, 0),
      'apellidos': _getValue(values, 1),
      'email': _getValue(values, 2),
      'telefono': _getValue(values, 3),
      'direccion': _getValue(values, 4),
      'localidad': _getValue(values, 5, defaultValue: 'Ocaña'),
      'codigo_postal': _getValue(values, 6),
      'fecha_ingreso': _getValue(values, 7),
      'cargo': _getValue(values, 8, defaultValue: 'Cofrade'),
      'estado': _getValue(values, 9, defaultValue: 'activo'),
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
