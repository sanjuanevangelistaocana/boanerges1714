# Boanerges 1714 — Cofradía de San Juan Evangelista de Ocaña

## Calendario litúrgico

La Home calcula localmente una selección del calendario romano general, sin
consultar servicios externos. La Pascua se obtiene para cada año mediante el
algoritmo gregoriano de Meeus y, a partir de ella, se derivan las celebraciones
móviles: Cuaresma, Semana Santa, Pascua, Pentecostés, Corpus Christi, Sagrado
Corazón, Cristo Rey y los domingos de Adviento. También se incluyen las
principales fechas fijas, incluida la solemnidad de San Juan Evangelista.
Para el contexto español se aplican los traslados de la Ascensión y del Corpus
Christi al domingo.

La utilidad genera años civiles consecutivos para que las próximas
celebraciones crucen correctamente el cambio de año entre Adviento, Navidad y
Epifanía. Es una referencia pastoral y no pretende ser exhaustiva: no modela
los calendarios propios diocesanos ni otros traslados de solemnidades.

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

## Módulo Galería

La Galería usa tres colecciones raíz de Firestore:

- `gallery_folders`: carpetas, orden, portada, contador `num_fotos`, visibilidad
  `publica`, borrado lógico y estado temporal `relocating`.
- `gallery_images`: fotografías con `folder_id`, metadatos, miniatura, orden,
  estado de moderación, visibilidad desnormalizada y campos preparados para
  tags, evento, año, autor y origen de una importación moderada.
- `gallery_upload_requests`: envíos ZIP de cofrades, con título, descripción,
  fecha del evento, autor, tamaño, número estimado de imágenes, estado,
  motivo de rechazo y carpetas destino.

Los originales y miniaturas se separan físicamente para que las reglas de
Storage puedan aplicar privacidad sin consultar Firestore:

```text
gallery/public/{folderId}/{fileName}
gallery/public/{folderId}/thumbs/{fileName}
gallery/private/{folderId}/{fileName}
gallery/private/{folderId}/thumbs/{fileName}
gallery/admin/{folderId}/{fileName}
gallery/admin/{folderId}/thumbs/{fileName}
gallery_uploads/{uid}/{fileName}.zip
```

La administración interna crea de forma idempotente las carpetas de sistema
`admin_root`, `banco_interno` y `carrusel_inicio`. El Banco interno usa el
prefijo `gallery/admin` y solo es legible por administradores. El Carrusel de
inicio permanece oculto de los listados de galería, pero sus imágenes se
guardan deliberadamente en `gallery/public` para que visitantes anónimos
puedan verlas en la Home; no debe cambiarse ese prefijo por `admin`.

El carrusel de inicio se alimenta de `watchCarouselImages()` y su orden se
controla desde `carrusel_inicio`; si no hay fotos, la Home conserva el hero
institucional de degradado.

Las carpetas e imágenes públicas aprobadas pueden leerse sin iniciar sesión.
El contenido privado requiere autenticación y las escrituras de carpetas e
imágenes requieren administración. Cada cofrade puede crear y consultar sus
propios envíos; la moderación es exclusiva del administrador.

Rutas principales:

- `/gallery`: carpetas públicas o todas las carpetas para usuarios autenticados.
- `/gallery/:folderId`: detalle paginado de una carpeta.
- `/gallery/upload`: envío de un ZIP por un cofrade.
- `/admin/galeria`: administración, importación y moderación.
- `/admin/evangelio`: recarga y edición manual del Evangelio del día.

Las miniaturas JPEG se generan en el cliente con calidad aproximada 80 y lado
máximo de 600 px. Los ZIP se inspeccionan y descomprimen en el navegador del
administrador, sin Cloud Functions nuevas. La importación permite asignar
fotografías a varias carpetas y guarda el origen para evitar duplicados al
reintentar una operación interrumpida. La pantalla de administración mantiene
una zona visual de subida basada en `file_picker`; el arrastre real queda
preparado como ampliación pendiente de una dependencia compatible y verificable.
La bandeja de moderación permite previsualizar, renombrar,
repartir por carpetas, importar con progreso y reanudar importaciones parciales.
El callable existente `sendNotification`
no se utiliza para avisos individuales: solo trabaja con topics. Un futuro
push individual requeriría gestionar tokens por dispositivo.

Límites configurables actuales:

- 15 MB por imagen.
- 50 MB por ZIP.
- 1000 imágenes por envío.
- 400 operaciones por batch de Firestore.

Las consultas paginadas requieren los índices definidos en
`firestore.indexes.json` (carpetas por visibilidad/orden, imágenes por
`folder_id`, visibilidad, estado y orden, carrusel por `carrusel`, `deleted` y
`orden`, y solicitudes propias por autor y fecha). El modelo ya deja espacio para tags, destacados, favoritos, búsqueda,
filtros por evento/año/autor, enlaces públicos, vídeos, comentarios y
reacciones.

### Evangelio del día y marca

La fecha civil del Evangelio se calcula siempre en `Europe/Madrid` y se usa
como clave `evangelio_dia/{YYYY-MM-DD}` y como fecha visible. El cliente
intenta recuperar la lectura desde Evangelizo cuando falta el documento o
contiene un placeholder; si un administrador puede acceder a la fuente, la
guarda para el resto de visitantes. La función programada depende de
facturación activa y la descarga directa desde Flutter Web puede quedar
bloqueada por CORS. `/admin/evangelio` permite recargar y editar manualmente.

El logotipo oficial ya está integrado en `assets/images/logo.png` (transparente)
y `assets/images/logo_bg.png` (fondo blanco). Los iconos web de `web/icons/`,
el favicon y los recursos `mipmap` de Android se han generado con margen de
seguridad; si se sustituye el logo, hay que regenerarlos de nuevo.

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
