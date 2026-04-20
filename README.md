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
