# Boanerges 1714 — Cofradía de San Juan Evangelista de Ocaña

App multiplataforma (Android, iOS/PWA, Web) para la Cofradía de San Juan Evangelista de Ocaña.

## Stack Tecnológico

- **Frontend:** Flutter (Dart) — Android + Web + PWA (iOS)
- **Backend:** Firebase (Authentication, Firestore, Cloud Messaging, Hosting, Storage)
- **Sync:** Google Sheets bidireccional via Cloud Functions

## Estructura del Proyecto

```
lib/
├── config/          # Configuración (Firebase, tema, rutas)
├── models/          # Modelos de datos (Cofrade, Evento, Noticia, Cuota, Documento)
├── services/        # Servicios (Auth, Firestore, Notificaciones)
├── screens/
│   ├── public/      # Pantallas públicas (Home, Historia, Eventos, Noticias, Galería, Contacto)
│   ├── private/     # Pantallas privadas (Dashboard, Perfil, Cuotas, Documentos, Login, Registro)
│   └── admin/       # Panel de administración (Gestión cofrades, eventos, noticias, notificaciones)
├── widgets/         # Widgets reutilizables
└── main.dart        # Punto de entrada
```

## Requisitos

- Flutter SDK >= 3.0.0
- Cuenta Firebase con proyecto configurado
- Dart SDK >= 3.0.0

## Setup

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en modo desarrollo (web)
flutter run -d chrome

# Ejecutar en modo desarrollo (Android)
flutter run -d android

# Compilar para web
flutter build web

# Compilar APK Android
flutter build apk
```

## Firebase

El proyecto usa el proyecto Firebase `boanerges1714`. La configuración está en `lib/config/firebase_config.dart`.

### Servicios utilizados:
- **Authentication** — Login email/password
- **Cloud Firestore** — Base de datos (cofrades, cuotas, eventos, noticias, documentos)
- **Cloud Messaging (FCM)** — Notificaciones push
- **Hosting** — Hosting web + PWA
- **Storage** — Archivos y fotos

## Métricas del dashboard privado

La sección **Tu Cofradía en Cifras** calcula sus indicadores en el cliente a partir
del stream de cofrades activos; no requiere cambios en Firebase ni en el backend.

- **Activos** y **Altas <año actual>** cuentan cofrades con estado activo y alta
  en el año en curso, respectivamente.
- **Media de edad** y la distribución por edad ignoran edades nulas o iguales a
  cero. La distribución usa como denominador únicamente las edades conocidas y
  muestra aparte los activos sin dato.
- **Antigüedad máxima** calcula `año actual - mínimo anioAlta` entre altas
  plausibles (1700–año actual). Si no hay ninguna, usa `aniosHermandad` como
  respaldo solo cuando está entre 1 y 120 años. La antigüedad media usa el mismo
  filtro de altas plausibles.
- **GDPR firmado** cuenta cofrades con consentimiento en papel o digital; el
  texto secundario conserva el desglose por canal y muestra los pendientes. El
  recuento de papel incluye `gdpr_firmado` y los alias `gdpr_papel`/`gdprFirmadoPapel`.
- **Relevo generacional** indica el porcentaje de activos menores de 30 y de 18
  años, usando como denominador las edades conocidas.

La distribución por edad oculta tramos vacíos al principio y al final para evitar
ruido visual. En pantallas estrechas cambia a barras horizontales (tramo,
porcentaje y absoluto); en anchas usa barras verticales. La paleta emplea
intensidades monocromas de los granates de la marca y las tarjetas mantienen
elevación cero, radio 12 y borde gris claro.

## Despliegue

### Web (Firebase Hosting)
```bash
flutter build web
firebase deploy --only hosting
```

### Android (Google Play)
```bash
flutter build appbundle
# Subir el .aab a Google Play Console
```

### iOS (PWA)
La web se instala como PWA en iOS: Safari → Compartir → Añadir a pantalla de inicio.

## Licencia

Propiedad de la Cofradía de San Juan Evangelista de Ocaña.
