const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const {google} = require("googleapis");
const APP_BASE_URL = (
  process.env.APP_BASE_URL || "https://sanjuanevangelistaocana.com"
).replace(/\/+$/, "");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();
const galleryBucket = admin.storage().bucket();

function galleryDownloadUrl(path, token) {
  return "https://firebasestorage.googleapis.com/v0/b/" +
      `${galleryBucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

async function copyGalleryFile(sourcePath, destinationPath) {
  if (!sourcePath || sourcePath === destinationPath) {
    return {path: destinationPath, url: null};
  }
  const source = galleryBucket.file(sourcePath);
  const destination = galleryBucket.file(destinationPath);
  await source.copy(destination);
  const [metadata] = await destination.getMetadata();
  const token = metadata.metadata?.firebaseStorageDownloadTokens ||
      crypto.randomUUID();
  if (!metadata.metadata?.firebaseStorageDownloadTokens) {
    await destination.setMetadata({
      metadata: {firebaseStorageDownloadTokens: token},
    });
  }
  return {path: destinationPath, url: galleryDownloadUrl(destinationPath, token)};
}

async function moveGalleryImageDocument(imageRef, image, folder) {
  const imagePublic = folder.publica && image.publica && !image.solo_admin;
  const prefix = folder.solo_admin ?
    "admin" : (imagePublic ? "public" : "private");
  const base = `gallery/${prefix}/${folder.id}`;
  const originalName = image.storage_path.split("/").pop();
  const thumbName = image.thumb_path ?
    image.thumb_path.split("/").pop() : null;
  const originalPath = `${base}/${originalName}`;
  const thumbPath = thumbName ? `${base}/thumbs/${thumbName}` : null;
  if (image.storage_path === originalPath &&
      (!image.thumb_path || image.thumb_path === thumbPath) &&
      image.publica === imagePublic &&
      image.solo_admin === folder.solo_admin) {
    await imageRef.update({
      publica: image.publica === true,
      solo_admin: folder.solo_admin,
    });
    return;
  }

  const original = await copyGalleryFile(image.storage_path, originalPath);
  let thumbnail = null;
  try {
    thumbnail = thumbPath ?
      await copyGalleryFile(image.thumb_path, thumbPath) : null;
    const changes = {
      storage_path: original.path,
      url: original.url || image.url,
      thumb_path: thumbnail?.path || null,
      thumb_url: thumbnail?.url || null,
      publica: image.publica === true,
      solo_admin: folder.solo_admin,
    };
    await imageRef.update(changes);
  } catch (error) {
    await galleryBucket.file(originalPath).delete().catch(() => {});
    if (thumbPath) await galleryBucket.file(thumbPath).delete().catch(() => {});
    throw error;
  }
  if (image.storage_path !== originalPath) {
    await galleryBucket.file(image.storage_path).delete();
  }
  if (image.thumb_path && image.thumb_path !== thumbPath) {
    await galleryBucket.file(image.thumb_path).delete().catch(() => {});
  }
}

async function requireGalleryAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated", "Debes iniciar sesión.");
  }
  const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
  if (!(context.auth.token.admin === true ||
      context.auth.token.superadmin === true || adminDoc.exists)) {
    throw new functions.https.HttpsError(
        "permission-denied", "No tienes permisos de administración.");
  }
}

function normalizedDiagnosticText(value) {
  return value === null || value === undefined ?
    "" : String(value).trim().toLowerCase();
}

function normalizedDiagnosticDni(value) {
  return String(value || "").toUpperCase()
      .replace(/[\s\-_.]/g, "").trim();
}

function diagnosticDateKey(value) {
  if (value === null || value === undefined || value === "") return null;
  let date = null;
  if (value instanceof Date) {
    date = value;
  } else if (value && typeof value.toDate === "function") {
    date = value.toDate();
  } else if (typeof value === "string") {
    const text = value.trim();
    let match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
    if (match) {
      const year = Number(match[1]);
      const month = Number(match[2]);
      const day = Number(match[3]);
      date = new Date(Date.UTC(
          year, month - 1, day));
      if (date.getUTCFullYear() !== year ||
          date.getUTCMonth() + 1 !== month ||
          date.getUTCDate() !== day) return null;
    } else {
      match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(text);
      if (match) {
        const year = Number(match[3]);
        const month = Number(match[2]);
        const day = Number(match[1]);
        date = new Date(Date.UTC(
            year, month - 1, day));
        if (date.getUTCFullYear() !== year ||
            date.getUTCMonth() + 1 !== month ||
            date.getUTCDate() !== day) return null;
      }
    }
  }
  if (!date || Number.isNaN(date.getTime())) return null;
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + 1;
  const day = date.getUTCDate();
  const valid = new Date(Date.UTC(year, month - 1, day));
  if (valid.getUTCFullYear() !== year ||
      valid.getUTCMonth() + 1 !== month ||
      valid.getUTCDate() !== day) {
    return null;
  }
  return `${year.toString().padStart(4, "0")}-` +
      `${month.toString().padStart(2, "0")}-` +
      `${day.toString().padStart(2, "0")}`;
}

function diagnosticBoolean(value) {
  if (typeof value === "boolean") return value;
  const normalized = normalizedDiagnosticText(value);
  if (["true", "1", "si", "sí", "yes"].includes(normalized)) return true;
  if (["false", "0", "no"].includes(normalized)) return false;
  return null;
}

// ============================================================
// Google Sheets Bidirectional Sync
// ============================================================

// Google Sheet ID for bidirectional sync
const SPREADSHEET_ID = "1YoQh6kcRU7VVg4bbz4pUfEyqPSXgqpT9Lfq6VLfhGCQ";

// Gmail SMTP configuration
const GMAIL_EMAIL = "sanjuanevangelistaocana@gmail.com";
const withEmailSecret = functions.runWith({secrets: ["GMAIL_APP_PASSWORD"]});
const SHEET_NAME = "Relación Cofrades";
// Column indices matching the actual Google Sheet structure:
// 0:Nº 1:Nombre 2:Apellidos 3:Tutelado Digital 4:Fecha Nacimiento
// 5:Edad 6:Género 7:Año Alta 8:Años Hermandad 9:Año Mayordomía
// 10:Estado 11:Fecha Baja 12:Causa Baja 13:Domicilio 14:Localidad
// 15:Código Postal 16:Teléfono Fijo 17:Teléfono Móvil 18:Email
// 19:Estatura 20:Talla 21:¿Cuota? 22:Cuota Metálico 23:Cuota Domiciliada
// 24:IBAN 25:Titular IBAN 26:Raul 27:Check Data 28:GDPR Firmado
// 29:Comentarios 30+: new columns appended by the app
const TOTAL_SHEET_COLS = 37; // A through AK

function normalizeSearchText(value) {
  return String(value || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim()
      .replace(/\s+/g, " ");
}

function normalizeDni(value) {
  return String(value || "")
      .toUpperCase()
      .replace(/[\s\-_.]/g, "")
      .trim();
}

function createEmailTransport() {
  const password = process.env.GMAIL_APP_PASSWORD;
  if (!password) return null;
  return nodemailer.createTransport({
    service: "gmail",
    auth: {user: GMAIL_EMAIL, pass: password},
  });
}

function parseBirthDate(value) {
  if (value && typeof value.toDate === "function") value = value.toDate();
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;
    return new Date(value.getFullYear(), value.getMonth(), value.getDate());
  }
  if (typeof value === "number" && Number.isInteger(value)) {
    return parseBirthDate(new Date(value));
  }
  if (typeof value !== "string") return null;
  const match = value.trim().match(/^(\d{1,4})[\/-](\d{1,2})[\/-](\d{1,4})$/);
  if (!match) return null;
  const first = Number(match[1]);
  const second = Number(match[2]);
  const third = Number(match[3]);
  const year = first > 31 ? first : third;
  const month = second;
  const day = first > 31 ? third : first;
  if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year &&
      date.getMonth() === month - 1 &&
      date.getDate() === day ? date : null;
}

function escapeHtml(value) {
  return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
}

function parseAltaYear(value) {
  if (value && typeof value.toDate === "function") value = value.toDate();
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.getFullYear();
  }
  if (typeof value === "number" && Number.isInteger(value)) {
    return value >= 1900 && value <= 2100 ? value : null;
  }
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (/^\d{4}$/.test(text)) {
    const year = Number(text);
    return year >= 1900 && year <= 2100 ? year : null;
  }
  const date = parseBirthDate(text);
  return date ? date.getFullYear() : null;
}

function birthdayGenderData(value) {
  const normalized = String(value || "").trim().toUpperCase();
  if (["H", "HOMBRE", "MASCULINO"].includes(normalized)) {
    return {hero: "un héroe", sanJuanito: "SanJuanito"};
  }
  if (["M", "MUJER", "F", "FEMENINO"].includes(normalized)) {
    return {hero: "una heroína", sanJuanito: "SanJuanita"};
  }
  return null;
}

function birthdayEmailData(cofrade, today) {
  const birth = parseBirthDate(cofrade.fecha_nacimiento) ||
      parseBirthDate(cofrade.fecha_nacimiento_str);
  const age = birth ? today.year - birth.getFullYear() : null;
  const altaYear = parseAltaYear(cofrade.anio_alta);
  const yearsInCofradia = altaYear == null ? null : today.year - altaYear;
  const gender = birthdayGenderData(cofrade.genero);
  return {
    plainFirstName: String(cofrade.nombre || "Cofrade"),
    firstName: escapeHtml(cofrade.nombre || "Cofrade"),
    age: Number.isInteger(age) && age >= 0 ? age : null,
    yearsInCofradia: Number.isInteger(yearsInCofradia) &&
        yearsInCofradia >= 0 ? yearsInCofradia : null,
    gender,
  };
}

function birthdayTenureText(years, gender) {
  if (years == null) return null;
  const role = gender ? ` como ${gender.sanJuanito}` : " en la Cofradía";
  if (years === 0) return `Felicidades también por tus primeros meses${role} 🔴🦅`;
  if (years === 1) return `Felicidades también por tu primer año${role} 🔴🦅`;
  return `Felicidades también por tus ${years} años${role} 🔴🦅`;
}

function madridToday() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Madrid",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    year: Number(values.year),
    month: Number(values.month),
    day: Number(values.day),
  };
}

async function syncPublicBirthday(cofradeId, data) {
  const ref = db.collection("cumpleanos_publicos").doc(cofradeId);
  const birthday = publicBirthdayData(cofradeId, data);
  if (!birthday) {
    await ref.delete().catch(() => {});
    return;
  }
  await ref.set(birthday);
}

function publicBirthdayData(cofradeId, data) {
  const birth = parseBirthDate(data.fecha_nacimiento) ||
      parseBirthDate(data.fecha_nacimiento_str);
  const active = data.estado === "Activo" && data.isActive !== false;
  if (!birth || !active || data.cumpleanos_visible === false) {
    return null;
  }
  return {
    id: cofradeId,
    nombre: `${data.nombre || ""} ${data.apellidos || ""}`.trim(),
    dia: birth.getDate(),
    mes: birth.getMonth() + 1,
    visible: true,
  };
}

async function rebuildPublicBirthdayIndex() {
  const snapshot = await db.collection("cofrades").get();
  const existing = await db.collection("cumpleanos_publicos").get();
  const existingIds = new Set(existing.docs.map((doc) => doc.id));
  const validIds = new Set();
  let batch = db.batch();
  let pending = 0;
  let indexed = 0;
  let deleted = 0;
  const cofradeIds = new Set(snapshot.docs.map((doc) => doc.id));

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const ref = db.collection("cumpleanos_publicos").doc(doc.id);
    const birthday = publicBirthdayData(doc.id, data);
    if (!birthday) {
      batch.delete(ref);
      if (existingIds.has(doc.id)) deleted++;
    } else {
      validIds.add(doc.id);
      batch.set(ref, birthday);
      indexed++;
    }
    pending++;
    if (pending === 450) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }

  for (const doc of existing.docs) {
    if (!validIds.has(doc.id) &&
        !cofradeIds.has(doc.id)) {
      batch.delete(doc.ref);
      deleted++;
      pending++;
      if (pending === 450) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
  }
  if (pending > 0) await batch.commit();
  return {indexed, deleted};
}

exports.syncCofradePublicBirthday = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onWrite(async (change, context) => {
      await syncPublicBirthday(
          context.params.cofradeId,
          change.after.exists ? change.after.data() : {},
      );
      return null;
    });

/**
 * Convert a column index to a letter (0=A, 25=Z, 26=AA, etc.).
 */
function colLetter(index) {
  let result = "";
  let i = index;
  while (i >= 0) {
    result = String.fromCharCode(65 + (i % 26)) + result;
    i = Math.floor(i / 26) - 1;
  }
  return result;
}

/**
 * Get authenticated Google Sheets client using service account.
 */
async function getSheetsClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/spreadsheets"],
  });
  const authClient = await auth.getClient();
  return google.sheets({version: "v4", auth: authClient});
}

/**
 * Sync Firestore → Google Sheets when a cofrade document is created or updated.
 * Triggered on every write to the cofrades collection.
 */
exports.syncCofradeToSheet = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onWrite(async (change, context) => {
      const sheetId = SPREADSHEET_ID;
      const cofradeId = context.params.cofradeId;

      // Handle deletion
      if (!change.after.exists) {
        const beforeData = change.before.data();
        console.log(`Cofrade ${cofradeId} (#${beforeData.numero}) deleted.`);
        await removeRowFromSheet(sheetId, beforeData.numero);
        return null;
      }

      const data = change.after.data();
      // Build row matching the actual Sheet column order (A-AD = 30 cols)
      const row = [
        data.numero || "",                              // 0: Nº
        data.nombre || "",                              // 1: Nombre
        data.apellidos || "",                           // 2: Apellidos
        data.tutelado_digital || "",                      // 3: Tutelado Digital
        data.fecha_nacimiento ?
          new Date(data.fecha_nacimiento.seconds * 1000)
              .toLocaleDateString("es-ES") : "",       // 4: Fecha Nacimiento
        data.edad || "",                                // 5: Edad
        data.genero || "",                              // 6: Género
        data.anio_alta || "",                           // 7: Año Alta
        data.anios_hermandad || "",                     // 8: Años Hermandad
        data.anio_mayordomia || "",                     // 9: Año Mayordomía
        data.estado || "",                              // 10: Estado
        data.fecha_baja ?
          new Date(data.fecha_baja.seconds * 1000)
              .toLocaleDateString("es-ES") : "",       // 11: Fecha Baja
        data.causa_baja || "",                          // 12: Causa Baja
        data.domicilio || "",                           // 13: Domicilio
        data.localidad || "",                           // 14: Localidad
        data.codigo_postal || "",                       // 15: Código Postal
        data.telefono_fijo || "",                       // 16: Teléfono Fijo
        data.telefono_movil || "",                      // 17: Teléfono Móvil
        data.email || "",                               // 18: Email
        data.estatura || "",                            // 19: Estatura
        data.talla || "",                               // 20: Talla
        data.tiene_cuota ? "TRUE" : "FALSE",            // 21: ¿Cuota?
        data.cuota_metalico ? "TRUE" : "FALSE",         // 22: Cuota Metálico
        data.cuota_domiciliada ? "TRUE" : "FALSE",      // 23: Cuota Domiciliada
        data.iban || "",                                // 24: IBAN
        data.titular_iban || "",                        // 25: Titular IBAN
        "",                                            // 26: Raul (existing col)
        "",                                            // 27: Check Data (existing col)
        data.gdpr_firmado ? "TRUE" : "FALSE",           // 28: GDPR Firmado
        data.comentarios || "",                         // 29: Comentarios
        // New columns (AE-AK)
        data.email_secundario || "",                   // 30: Email Secundario
        data.telefono_secundario || "",                // 31: Teléfono Secundario
        data.dni || "",                                // 32: DNI
        data.dni_tutor || "",                          // 33: DNI Tutor
        data.parentesco_tutor || "",                   // 34: Parentesco Tutor
        data.cargo || "",                              // 35: Cargo
        data.tiene_tunica_propia ? "TRUE" : "FALSE",   // 36: Tiene Túnica Propia
      ];

      await upsertRowInSheet(sheetId, data.numero, row);
      return null;
    });

/**
 * Maintain a minimal cofrade search index for app autocomplete.
 * This avoids exposing sensitive cofrades fields such as DNI, IBAN, phones,
 * cuota data, GDPR flags, comments, etc. to normal authenticated users.
 */
exports.syncCofradeSearchIndex = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onWrite(async (change, context) => {
      const indexRef = db
          .collection("cofrades_busqueda")
          .doc(context.params.cofradeId);

      if (!change.after.exists) {
        await indexRef.delete().catch(() => {});
        return null;
      }

      const data = change.after.data();
      const nombre = data.nombre || "";
      const apellidos = data.apellidos || "";
      const numero = data.numero || null;
      const estado = data.estado || "Activo";
      const nombreCompleto = `${nombre} ${apellidos}`.trim();
      const searchText = normalizeSearchText(
          [
            nombre,
            apellidos,
            nombreCompleto,
            `${apellidos} ${nombre}`.trim(),
            numero != null ? String(numero) : "",
          ].join(" "),
      );

      await indexRef.set({
        nombre,
        apellidos,
        nombre_completo: nombreCompleto,
        nombre_busqueda: searchText,
        numero,
        estado,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    });

/**
 * Keep a normalized DNI field on cofrade documents.
 * This is used by DNI login while preserving the original display value.
 */
exports.syncCofradeDniNormalizado = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onWrite(async (change) => {
      if (!change.after.exists) return null;
      const data = change.after.data();
      const normalized = normalizeDni(data.dni);
      if ((data.dni_normalizado || "") === normalized) return null;
      await change.after.ref.update({dni_normalizado: normalized});
      return null;
    });

/**
 * Resolve a cofrade email from a DNI/NIE for login.
 * Firestore rules do not allow unauthenticated users to query cofrades, so
 * this callable performs the lookup server-side and returns only the email.
 */
exports.lookupEmailByDni = functions
    .region("europe-west1")
    .https.onCall(async (data) => {
      const dni = normalizeDni(data && data.dni);
      if (!dni) {
        throw new functions.https.HttpsError(
            "invalid-argument", "Introduce un DNI/NIE.",
        );
      }

      let snapshot = await db.collection("cofrades")
          .where("dni_normalizado", "==", dni)
          .limit(1)
          .get();

      if (snapshot.empty) {
        // Migration fallback for existing documents before dni_normalizado exists.
        const all = await db.collection("cofrades").select("dni", "email").get();
        const match = all.docs.find((doc) => normalizeDni(doc.data().dni) === dni);
        snapshot = match ? {empty: false, docs: [match]} : {empty: true, docs: []};
      }

      if (snapshot.empty) {
        throw new functions.https.HttpsError(
            "not-found", "No se encontró ningún cofrade con ese DNI/NIE.",
        );
      }

      const cofrade = snapshot.docs[0].data();
      if (!cofrade.email) {
        throw new functions.https.HttpsError(
            "failed-precondition",
            "El cofrade existe, pero no tiene email asociado. Contacta con la Junta.",
        );
      }

      return {email: cofrade.email};
    });

/**
 * Scheduled function to sync Google Sheets → Firestore.
 * Disabled intentionally: Firestore is the source of truth for cofrades.
 * The Sheet is kept as a mirror by syncCofradeToSheet, but manual edits in
 * the Sheet must not overwrite data edited from the app or Firebase console.
 */
exports.syncSheetToFirestore = functions
    .region("europe-west1")
    .pubsub.schedule("every 15 minutes")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      console.log(
          "Sheet → Firestore sync skipped: Firestore is the source of truth.",
      );
      return null;
    });

/**
 * Insert or update a row in Google Sheets.
 */
async function ensureGridColumns(sheets, sheetId, requiredCols) {
  try {
    const meta = await sheets.spreadsheets.get({
      spreadsheetId: sheetId,
      fields: "sheets(properties(sheetId,title,gridProperties))",
    });
    const sheetMeta = meta.data.sheets.find(
        (s) => s.properties.title === SHEET_NAME,
    );
    if (sheetMeta) {
      const currentCols = sheetMeta.properties.gridProperties.columnCount;
      if (currentCols < requiredCols) {
        await sheets.spreadsheets.batchUpdate({
          spreadsheetId: sheetId,
          requestBody: {
            requests: [{
              appendDimension: {
                sheetId: sheetMeta.properties.sheetId,
                dimension: "COLUMNS",
                length: requiredCols - currentCols,
              },
            }],
          },
        });
        console.log(`Expanded grid by ${requiredCols - currentCols} columns.`);
      }
      return currentCols;
    }
    return requiredCols;
  } catch (err) {
    console.warn("Could not expand grid (sheet may be protected):", err.message);
    try {
      const meta = await sheets.spreadsheets.get({
        spreadsheetId: sheetId,
        fields: "sheets(properties(sheetId,title,gridProperties))",
      });
      const sheetMeta = meta.data.sheets.find(
          (s) => s.properties.title === SHEET_NAME,
      );
      return sheetMeta ?
        sheetMeta.properties.gridProperties.columnCount : requiredCols;
    } catch (e) {
      return requiredCols;
    }
  }
}

async function upsertRowInSheet(sheetId, numero, rowData) {
  const sheets = await getSheetsClient();

  // Ensure grid has enough columns; get actual column count
  const gridCols = await ensureGridColumns(sheets, sheetId, rowData.length);

  // Truncate row data if grid couldn't be expanded (e.g. protected sheet)
  const safeRow = gridCols < rowData.length ? rowData.slice(0, gridCols) : rowData;

  // Find existing row by numero (column A)
  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: sheetId,
    range: `${SHEET_NAME}!A:A`,
  });

  const col = response.data.values || [];
  let rowIndex = -1;

  for (let i = 0; i < col.length; i++) {
    if (String(col[i][0]).trim() === String(numero).trim()) {
      rowIndex = i;
      break;
    }
  }

  const endCol = colLetter(safeRow.length - 1);

  if (rowIndex >= 0) {
    // Update existing row
    await sheets.spreadsheets.values.update({
      spreadsheetId: sheetId,
      range: `${SHEET_NAME}!A${rowIndex + 1}:${endCol}${rowIndex + 1}`,
      valueInputOption: "RAW",
      requestBody: {values: [safeRow]},
    });
    console.log(`Updated row ${rowIndex + 1} for cofrade #${numero}`);
  } else {
    // Append new row
    await sheets.spreadsheets.values.append({
      spreadsheetId: sheetId,
      range: `${SHEET_NAME}!A:${endCol}`,
      valueInputOption: "RAW",
      requestBody: {values: [safeRow]},
    });
    console.log(`Appended new row for cofrade #${numero}`);
  }
}

/**
 * Remove a row from Google Sheets.
 */
async function removeRowFromSheet(sheetId, numero) {
  const sheets = await getSheetsClient();

  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: sheetId,
    range: `${SHEET_NAME}!A:A`,
  });

  const col = response.data.values || [];
  for (let i = 0; i < col.length; i++) {
    if (String(col[i][0]).trim() === String(numero).trim()) {
      const endCol = colLetter(TOTAL_SHEET_COLS - 1);
      await sheets.spreadsheets.values.clear({
        spreadsheetId: sheetId,
        range: `${SHEET_NAME}!A${i + 1}:${endCol}${i + 1}`,
      });
      console.log(`Cleared row ${i + 1} for deleted cofrade #${numero}`);
      break;
    }
  }
}

// ============================================================
// Push Notification Cloud Function
// ============================================================

/**
 * Send push notification to all cofrades (or filtered group).
 * Called from the admin panel via HTTPS callable function.
 */
exports.sendNotification = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      // Verify admin role
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated", "Debes iniciar sesión.",
        );
      }

      // Look up admin by auth_uid field (not doc ID)
      const callerSnap = await db
          .collection("cofrades")
          .where("auth_uid", "==", context.auth.uid)
          .where("rol", "==", "admin")
          .limit(1)
          .get();
      if (callerSnap.empty) {
        throw new functions.https.HttpsError(
            "permission-denied", "Solo los administradores pueden enviar notificaciones.",
        );
      }

      const {titulo, mensaje, destinatario} = data;

      if (!titulo || !mensaje) {
        throw new functions.https.HttpsError(
            "invalid-argument", "Título y mensaje son obligatorios.",
        );
      }

      // Build the FCM message
      const notification = {
        title: titulo,
        body: mensaje,
      };

      let topic = "all_cofrades";
      if (destinatario === "activos") {
        topic = "cofrades_activos";
      } else if (destinatario === "junta") {
        topic = "junta_directiva";
      }

      const message = {
        notification: notification,
        topic: topic,
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          type: "general_notification",
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`Notification sent to topic ${topic}: ${response}`);

      return {success: true, messageId: response};
    });

// ============================================================
// Auto-assign FCM topics on cofrade status change
// ============================================================

/**
 * Notify admins when a new solicitud de alta is created.
 */
exports.onNewSolicitud = withEmailSecret
    .region("europe-west1")
    .firestore.document("solicitudes/{solicitudId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      console.log(`New solicitud from ${data.nombre} ${data.apellidos}`);

      // 1. Send push notification to junta_directiva
      try {
        const message = {
          notification: {
            title: "Nueva solicitud de alta",
            body: `${data.nombre} ${data.apellidos} quiere ser cofrade.`,
          },
          topic: "junta_directiva",
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "nueva_solicitud",
            solicitud_id: context.params.solicitudId,
          },
        };
        await admin.messaging().send(message);
        console.log("Solicitud notification sent to junta_directiva");
      } catch (err) {
        console.error("Error sending solicitud push notification:", err);
      }

      // 2. Send email notification to cofradía gmail
      const transporter = createEmailTransport();
      if (!transporter) {
        console.warn("Gmail secret not configured. Skipping solicitud email.");
        return null;
      }

      try {

        const bodyParts = [];
        bodyParts.push(`<p><strong>Nombre:</strong> ${data.nombre} ${data.apellidos}</p>`);
        if (data.email) bodyParts.push(`<p><strong>Email:</strong> ${data.email}</p>`);
        if (data.telefono) bodyParts.push(`<p><strong>Teléfono:</strong> ${data.telefono}</p>`);
        if (data.dni) bodyParts.push(`<p><strong>DNI:</strong> ${data.dni}</p>`);
        if (data.fecha_nacimiento) {
          const fn = data.fecha_nacimiento.toDate
            ? data.fecha_nacimiento.toDate().toLocaleDateString("es-ES")
            : data.fecha_nacimiento;
          bodyParts.push(`<p><strong>Fecha nacimiento:</strong> ${fn}</p>`);
        }
        if (data.domicilio) bodyParts.push(`<p><strong>Domicilio:</strong> ${data.domicilio}</p>`);
        if (data.localidad) bodyParts.push(`<p><strong>Localidad:</strong> ${data.localidad}</p>`);
        if (data.codigo_postal) bodyParts.push(`<p><strong>C.P.:</strong> ${data.codigo_postal}</p>`);
        if (data.motivacion) {
          bodyParts.push("<hr/>");
          bodyParts.push(`<p><strong>Motivación:</strong></p><p>${data.motivacion.replace(/\n/g, "<br/>")}</p>`);
        }
        bodyParts.push("<hr/>");
        bodyParts.push(`<p><small>Recibida el ${new Date().toLocaleString("es-ES", {timeZone: "Europe/Madrid"})} desde la web de la Cofradía.</small></p>`);
        bodyParts.push(`<p>Gestiona esta solicitud desde el <a href="${APP_BASE_URL}/admin">panel de administración</a>.</p>`);

        const mailOptions = {
          from: `"Cofradía San Juan Evangelista" <${GMAIL_EMAIL}>`,
          to: GMAIL_EMAIL,
          replyTo: data.email || GMAIL_EMAIL,
          subject: `[Nueva Solicitud de Alta] ${data.nombre} ${data.apellidos}`,
          html: `<h2>Nueva solicitud de alta de cofrade</h2>${bodyParts.join("\n")}`,
        };

        await transporter.sendMail(mailOptions);
        console.log("Solicitud email sent successfully");
        await snap.ref.update({email_enviado: true});
      } catch (err) {
        console.error("Error sending solicitud email:", err);
        await snap.ref.update({email_enviado: false, email_error: err.message});
      }

      return null;
    });

/**
 * Notify all cofrades when a new convocatoria is created.
 */
exports.onNewConvocatoria = functions
    .region("europe-west1")
    .firestore.document("convocatorias/{convocatoriaId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      console.log(`New convocatoria: ${data.titulo}`);

      try {
        const message = {
          notification: {
            title: data.titulo,
            body: data.descripcion.substring(0, 100),
          },
          topic: "all_cofrades",
          data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "nueva_convocatoria",
            convocatoria_id: context.params.convocatoriaId,
          },
        };
        await admin.messaging().send(message);
        console.log("Convocatoria notification sent to all_cofrades");
      } catch (err) {
        console.error("Error sending convocatoria notification:", err);
      }
    });

/**
 * Send email notification when a new contact message is submitted.
 */
exports.onNewContactMessage = withEmailSecret
    .region("europe-west1")
    .firestore.document("contacto/{messageId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      console.log(`New contact message from ${data.nombre} (${data.email})`);

      const transporter = createEmailTransport();
      if (!transporter) {
        console.warn("Gmail secret not configured. Skipping contact email.");
        return null;
      }

      const bodyParts = [];
      if (data.nombre) bodyParts.push(`<p><strong>Nombre:</strong> ${data.nombre}</p>`);
      if (data.email) bodyParts.push(`<p><strong>Email:</strong> ${data.email}</p>`);
      if (data.telefono) bodyParts.push(`<p><strong>Teléfono:</strong> ${data.telefono}</p>`);
      bodyParts.push("<hr/>");
      if (data.mensaje) bodyParts.push(`<p>${data.mensaje.replace(/\n/g, "<br/>")}</p>`);
      bodyParts.push("<hr/>");
      bodyParts.push(`<p><small>Enviado desde la web de la Cofradía - ${new Date().toLocaleString("es-ES", {timeZone: "Europe/Madrid"})}</small></p>`);

      const mailOptions = {
        from: `"Cofradía San Juan Evangelista" <${GMAIL_EMAIL}>`,
        to: GMAIL_EMAIL,
        replyTo: data.email,
        subject: `[Contacto Web] Nuevo mensaje - ${data.nombre}`,
        html: `<h2>Nuevo mensaje de contacto</h2>${bodyParts.join("\n")}`,
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log("Contact email sent successfully");
        await snap.ref.update({email_enviado: true});
      } catch (err) {
        console.error("Error sending contact email:", err);
        await snap.ref.update({email_enviado: false, email_error: err.message});
      }

      return null;
    });

/**
 * Manual trigger for Sheet → Firestore sync (for testing/debugging).
 * Call via: https://europe-west1-boanerges1714.cloudfunctions.net/triggerSheetSync
 */
exports.triggerSheetSync = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      res.status(409).json({
        status: "disabled",
        message: "Sheet → Firestore sync is disabled. Edit cofrades from the app or Firebase; Firestore mirrors changes to Sheets.",
      });
      return;

    });

/**
 * Rebuild the minimal search index for existing cofrades.
 * Usage: POST /rebuildCofradeSearchIndex with body { "secret": "boanerges2024" }
 */
exports.rebuildCofradeSearchIndex = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        return res.status(204).send("");
      }

      try {
        const {secret} = req.body || {};
        if (secret !== "boanerges2024") {
          return res.status(403).json({status: "error", message: "Invalid secret."});
        }

        const snapshot = await db.collection("cofrades").get();
        let batch = db.batch();
        let count = 0;
        let pending = 0;

        for (const doc of snapshot.docs) {
          const data = doc.data();
          const nombre = data.nombre || "";
          const apellidos = data.apellidos || "";
          const numero = data.numero || null;
          const estado = data.estado || "Activo";
          const nombreCompleto = `${nombre} ${apellidos}`.trim();
          const searchText = normalizeSearchText(
              [
                nombre,
                apellidos,
                nombreCompleto,
                `${apellidos} ${nombre}`.trim(),
                numero != null ? String(numero) : "",
              ].join(" "),
          );

          batch.set(db.collection("cofrades_busqueda").doc(doc.id), {
            nombre,
            apellidos,
            nombre_completo: nombreCompleto,
            nombre_busqueda: searchText,
            numero,
            estado,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          count++;
          pending++;

          if (pending === 450) {
            await batch.commit();
            batch = db.batch();
            pending = 0;
          }
        }

        if (pending > 0) {
          await batch.commit();
        }

        return res.json({status: "success", indexed: count});
      } catch (error) {
        console.error("Error rebuilding cofrade search index:", error);
        return res.status(500).json({status: "error", message: error.message});
      }
    });

/**
 * Rebuild public birthday documents after migration or rule changes.
 */
exports.rebuildPublicBirthdayIndex = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated", "Debes iniciar sesión.");
      }
      const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
      const isAdmin = context.auth.token.admin === true ||
          context.auth.token.superadmin === true || adminDoc.exists;
      if (!isAdmin) {
        throw new functions.https.HttpsError(
            "permission-denied", "No tienes permisos de administración.");
      }
      try {
        return await rebuildPublicBirthdayIndex();
      } catch (error) {
        console.error("Error rebuilding public birthday index:", error);
        throw new functions.https.HttpsError(
            "internal", "No se pudo reconstruir el índice de cumpleaños.");
      }
    });

/**
 * Normalize legacy gallery documents so visibility and lifecycle fields are
 * always present for Firestore queries.
 */
exports.normalizeGalleryDocuments = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated", "Debes iniciar sesión.");
      }
      const adminDoc = await db.collection("admins").doc(context.auth.uid).get();
      const isAdmin = context.auth.token.admin === true ||
          context.auth.token.superadmin === true || adminDoc.exists;
      if (!isAdmin) {
        throw new functions.https.HttpsError(
            "permission-denied", "No tienes permisos de administración.");
      }

      const summary = {
        foldersScanned: 0,
        foldersUpdated: 0,
        coversCleared: 0,
        imagesScanned: 0,
        imagesUpdated: 0,
      };
      try {
        const galleryImages = await db.collection("gallery_images").get();
        const imagesById = new Map(
            galleryImages.docs.map((doc) => [doc.id, doc.data()]),
        );
        for (const collection of ["gallery_folders", "gallery_images"]) {
          const snapshot = await db.collection(collection).get();
          let batch = db.batch();
          let pending = 0;
          for (const doc of snapshot.docs) {
            const current = doc.data();
            const defaults = collection === "gallery_folders" ? {
              publica: false,
              solo_admin: false,
              deleted: false,
              relocating: false,
              orden: 0,
              num_fotos: 0,
            } : {
              publica: false,
              solo_admin: false,
              carrusel: false,
              deleted: false,
              estado: "aprobada",
              orden: 0,
            };
            const changes = {};
            for (const [field, value] of Object.entries(defaults)) {
              if (!Object.prototype.hasOwnProperty.call(current, field)) {
                changes[field] = value;
              }
            }
            if (collection === "gallery_folders" &&
                current.publica === true &&
                current.cover_image_id) {
              const cover = imagesById.get(current.cover_image_id);
              const safeCover = cover &&
                  cover.publica === true &&
                  cover.solo_admin !== true &&
                  cover.deleted !== true &&
                  cover.estado === "aprobada";
              if (!safeCover) {
                changes.cover_image_id = null;
                changes.cover_image_url = null;
                summary.coversCleared++;
              }
            }
            if (collection === "gallery_folders") {
              summary.foldersScanned++;
            } else {
              summary.imagesScanned++;
            }
            if (Object.keys(changes).length === 0) continue;
            batch.update(doc.ref, changes);
            pending++;
            if (collection === "gallery_folders") {
              summary.foldersUpdated++;
            } else {
              summary.imagesUpdated++;
            }
            if (pending === 400) {
              await batch.commit();
              batch = db.batch();
              pending = 0;
            }
          }
          if (pending > 0) await batch.commit();
        }
        return summary;
      } catch (error) {
        console.error("Error normalizing gallery documents:", error);
        throw new functions.https.HttpsError(
            "internal", "No se pudo normalizar la galería.");
      }
    });

/**
 * Report contradictory cofrade aliases without modifying any document.
 */
exports.diagnoseCofradeConflicts = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      await requireGalleryAdmin(context);
      const conflictTypes = [
        "rol_role",
        "auth_uid_authUid",
        "fecha_nacimiento",
        "tutor_requiere",
        "tutor_email",
        "tutor_dni",
        "tutor_parentesco",
        "tiene_cuota_cuotaActiva",
        "fecha_baja",
        "dni_normalizado",
        "estado_actividad",
      ];
      const counts = Object.fromEntries(
          conflictTypes.map((type) => [type, 0]),
      );
      const samples = Object.fromEntries(
          conflictTypes.map((type) => [type, []]),
      );
      let scanned = 0;
      let fichasConConflictos = 0;
      const snapshot = await db.collection("cofrades").get();

      const report = (type, id) => {
        counts[type]++;
        if (samples[type].length < 10) samples[type].push(id);
      };

      for (const doc of snapshot.docs) {
        scanned++;
        const value = doc.data();
        let hasConflict = false;
        const compareText = (type, first, second) => {
          if (first === undefined || first === null ||
              second === undefined || second === null) return;
          if (normalizedDiagnosticText(first) === "" ||
              normalizedDiagnosticText(second) === "") return;
          if (normalizedDiagnosticText(first) !==
              normalizedDiagnosticText(second)) {
            report(type, doc.id);
            hasConflict = true;
          }
        };
        const compareDate = (type, first, second) => {
          if (first === undefined || first === null ||
              second === undefined || second === null) return;
          const firstKey = diagnosticDateKey(first);
          const secondKey = diagnosticDateKey(second);
          if (firstKey && secondKey && firstKey !== secondKey) {
            report(type, doc.id);
            hasConflict = true;
          }
        };
        const compareBoolean = (type, first, second) => {
          const firstValue = diagnosticBoolean(first);
          const secondValue = diagnosticBoolean(second);
          if (firstValue !== null && secondValue !== null &&
              firstValue !== secondValue) {
            report(type, doc.id);
            hasConflict = true;
          }
        };

        compareText("rol_role", value.rol, value.role);
        compareText("auth_uid_authUid", value.auth_uid, value.authUid);
        compareDate(
            "fecha_nacimiento",
            value.fecha_nacimiento,
            value.fecha_nacimiento_str,
        );
        compareBoolean(
            "tutor_requiere",
            value.requiresDigitalTutor,
            value.tutelado_digital,
        );
        compareText(
            "tutor_email",
            value.digitalTutorEmail,
            value.tutelado_digital_email,
        );
        compareText("tutor_dni", value.digitalTutorDni, value.dni_tutor);
        compareText(
            "tutor_parentesco",
            value.digitalTutorRelationship,
            value.parentesco_tutor,
        );
        compareBoolean(
            "tiene_cuota_cuotaActiva",
            value.tiene_cuota,
            value.cuotaActiva,
        );
        compareDate("fecha_baja", value.fecha_baja, value.fecha_baja_str);
        if (value.dni !== undefined && value.dni_normalizado !== undefined &&
            normalizedDiagnosticDni(value.dni) !== "" &&
            normalizedDiagnosticDni(value.dni_normalizado) !== "" &&
            normalizedDiagnosticDni(value.dni) !==
                normalizedDiagnosticDni(value.dni_normalizado)) {
          report("dni_normalizado", doc.id);
          hasConflict = true;
        }

        const estado = normalizedDiagnosticText(value.estado);
        const status = normalizedDiagnosticText(value.status);
        const active = typeof value.isActive === "boolean" ?
          value.isActive : null;
        const estadoBaja = estado === "baja";
        const estadoActivo = estado === "activo" || estado === "activa";
        const statusBaja = ["baja", "inactive", "inactivo"].includes(status);
        const statusActivo = ["active", "activo", "activa"].includes(status);
        const impossibleState =
            (estadoBaja && active === true) ||
            (estadoActivo && active === false) ||
            (estadoBaja && statusActivo) ||
            (estadoActivo && statusBaja) ||
            (statusBaja && active === true) ||
            (statusActivo && active === false);
        if (impossibleState) {
          report("estado_actividad", doc.id);
          hasConflict = true;
        }
        if (hasConflict) fichasConConflictos++;
      }

      console.log("Cofrade conflict diagnosis completed", {
        scanned,
        fichasConConflictos,
        counts,
      });
      return {
        scanned,
        fichasConConflictos,
        counts,
        samples,
        sampleLimit: 10,
        writesPerformed: 0,
      };
    });

exports.setGalleryImageVisibility = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      await requireGalleryAdmin(context);
      const imageId = String(data?.imageId || "");
      if (!imageId || typeof data?.publica !== "boolean") {
        throw new functions.https.HttpsError(
            "invalid-argument", "Faltan datos de visibilidad.");
      }
      try {
        const imageRef = db.collection("gallery_images").doc(imageId);
        const imageSnapshot = await imageRef.get();
        if (!imageSnapshot.exists) {
          throw new functions.https.HttpsError(
              "not-found", "La fotografía no existe.");
        }
        const image = imageSnapshot.data();
        const folderSnapshot = await db.collection("gallery_folders")
            .doc(image.folder_id).get();
        if (!folderSnapshot.exists) {
          throw new functions.https.HttpsError(
              "failed-precondition", "La carpeta de la fotografía no existe.");
        }
        await moveGalleryImageDocument(
            imageRef,
            {...image, publica: data.publica},
            {id: folderSnapshot.id, ...folderSnapshot.data()},
        );
        return {updated: 1};
      } catch (error) {
        if (error instanceof functions.https.HttpsError) throw error;
        console.error("Error changing gallery image visibility:", error);
        throw new functions.https.HttpsError(
            "internal", "No se pudo cambiar la visibilidad.");
      }
    });

exports.setGalleryFolderVisibility = functions
    .runWith({timeoutSeconds: 540})
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      await requireGalleryAdmin(context);
      const folderId = String(data?.folderId || "");
      if (!folderId || typeof data?.publica !== "boolean") {
        throw new functions.https.HttpsError(
            "invalid-argument", "Faltan datos de visibilidad.");
      }
      let previousPublica = false;
      let folder;
      const movedImages = [];
      try {
        const folderRef = db.collection("gallery_folders").doc(folderId);
        const folderSnapshot = await folderRef.get();
        if (!folderSnapshot.exists) {
          throw new functions.https.HttpsError(
              "not-found", "La carpeta no existe.");
        }
        folder = {id: folderId, ...folderSnapshot.data()};
        if (folder.sistema && folder.sistema !== "ninguno") {
          throw new functions.https.HttpsError(
              "failed-precondition",
              "Las carpetas de sistema no cambian de visibilidad.");
        }
        previousPublica = folder.publica === true;
        await folderRef.update({
          publica: data.publica,
          relocating: true,
        });
        const images = await db.collection("gallery_images")
            .where("folder_id", "==", folderId)
            .where("deleted", "==", false)
            .get();
        let updated = 0;
        for (const imageSnapshot of images.docs) {
          const image = imageSnapshot.data();
          await moveGalleryImageDocument(
              imageSnapshot.ref,
              image,
              {...folder, publica: data.publica},
          );
          movedImages.push({ref: imageSnapshot.ref, data: image});
          updated++;
        }
        await folderRef.update({
          relocating: false,
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {updated};
      } catch (error) {
        console.error("Error changing gallery folder visibility:", error);
        // A failed batch must not leave earlier files in the new prefix.
        // The original document data is retained in movedImages when a move
        // completes, allowing best-effort rollback before exposing the old
        // folder visibility again.
        for (const moved of [...movedImages].reverse()) {
            try {
              await moveGalleryImageDocument(
                  moved.ref,
                  moved.data,
                  {...folder, publica: previousPublica},
              );
            } catch (rollbackError) {
              console.error("Gallery visibility rollback failed:",
                  rollbackError);
            }
        }
        try {
          await db.collection("gallery_folders").doc(folderId).update({
            publica: previousPublica,
            relocating: false,
          });
        } catch (_) {}
        if (error instanceof functions.https.HttpsError) throw error;
        throw new functions.https.HttpsError(
            "internal", "No se pudo cambiar la visibilidad de la carpeta.");
      }
    });

/**
 * Rebuild identifiable lottery fractions for existing sheets/assignments.
 * Usage: POST /rebuildDecimosLoteria with body { "secret": "boanerges2024" }
 */
exports.rebuildDecimosLoteria = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        return res.status(204).send("");
      }

      try {
        const {secret} = req.body || {};
        if (secret !== "boanerges2024") {
          return res.status(403).json({status: "error", message: "Invalid secret."});
        }

        let batch = db.batch();
        let pending = 0;
        let created = 0;
        let assigned = 0;
        let missingSerie = 0;

        async function commitIfNeeded(force = false) {
          if (pending > 0 && (force || pending >= 450)) {
            await batch.commit();
            batch = db.batch();
            pending = 0;
          }
        }

        const sabanasSnap = await db.collection("sabanas").get();
        for (const sabanaDoc of sabanasSnap.docs) {
          const sabana = sabanaDoc.data();
          const existing = await db
              .collection("decimos_loteria")
              .where("sabana_id", "==", sabanaDoc.id)
              .limit(1)
              .get();
          if (!existing.empty) continue;

          const totalDecimos = Number(sabana.total_decimos || 10);
          const rawSerie = String(sabana.serie || "").trim();
          const serie = rawSerie || "PENDIENTE";
          if (!rawSerie) {
            missingSerie++;
            batch.update(sabanaDoc.ref, {serie});
            pending++;
          }

          for (let i = 1; i <= totalDecimos; i++) {
            const decimoRef = db.collection("decimos_loteria").doc();
            batch.set(decimoRef, {
              campana_id: sabana.campana_id || "",
              sabana_id: sabanaDoc.id,
              numero_loteria: Number(sabana.numero_loteria || 0),
              serie,
              numero_decimo: i,
              precio_venta: Number(sabana.precio_venta_unidad || 0),
              estado: "disponible",
              vendedor_id: null,
              cofrade_id: null,
              fecha_asignacion: null,
              fecha_venta: null,
            });
            pending++;
            created++;
            await commitIfNeeded();
          }
        }
        await commitIfNeeded(true);

        const asignacionesSnap = await db.collection("asignaciones_loteria").get();
        for (const asignacionDoc of asignacionesSnap.docs) {
          const asignacion = asignacionDoc.data();
          if (!asignacion.sabana_id || !asignacion.vendedor_id) continue;

          const alreadyAssigned = await db
              .collection("decimos_loteria")
              .where("sabana_id", "==", asignacion.sabana_id)
              .where("vendedor_id", "==", asignacion.vendedor_id)
              .limit(1)
              .get();
          if (!alreadyAssigned.empty) continue;

          const vendedorDoc = await db
              .collection("vendedores_loteria")
              .doc(asignacion.vendedor_id)
              .get();
          const vendedor = vendedorDoc.exists ? vendedorDoc.data() : {};
          const totalAsignados = Number(asignacion.decimos_asignados || 0);
          const vendidos = Number(asignacion.decimos_vendidos || 0);
          const devueltos = Number(asignacion.decimos_devueltos || 0);
          if (totalAsignados <= 0) continue;

          const decimosSnap = await db
              .collection("decimos_loteria")
              .where("sabana_id", "==", asignacion.sabana_id)
              .where("estado", "==", "disponible")
              .get();
          const decimos = decimosSnap.docs
              .sort((a, b) => Number(a.data().numero_decimo || 0) - Number(b.data().numero_decimo || 0))
              .slice(0, totalAsignados);

          for (let i = 0; i < decimos.length; i++) {
            let estado = "asignado";
            if (i < vendidos) {
              estado = "vendido";
            } else if (i < vendidos + devueltos) {
              estado = "devuelto";
            }
            batch.update(decimos[i].ref, {
              estado,
              vendedor_id: asignacion.vendedor_id,
              cofrade_id: vendedor.cofrade_id || null,
              fecha_asignacion: asignacion.fecha_asignacion ||
                  asignacion.fecha_entrega ||
                  admin.firestore.FieldValue.serverTimestamp(),
              fecha_venta: estado === "vendido" ?
                (asignacion.fecha_venta || admin.firestore.FieldValue.serverTimestamp()) :
                null,
            });
            pending++;
            assigned++;
            await commitIfNeeded();
          }
        }
        await commitIfNeeded(true);

        return res.json({
          status: "success",
          decimosCreated: created,
          decimosAssigned: assigned,
          sabanasWithoutSerie: missingSerie,
        });
      } catch (error) {
        console.error("Error rebuilding lottery fractions:", error);
        return res.status(500).json({status: "error", message: error.message});
      }
    });

exports.manageFcmTopics = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();

      // Check if estado or rol changed
      if (before.estado === after.estado && before.rol === after.rol &&
          before.role === after.role) {
        return null;
      }

      console.log(
          `Cofrade ${context.params.cofradeId} status changed: ` +
        `${before.estado}->${after.estado}, ` +
        `${before.rol || before.role}->${after.rol || after.role}`,
      );

      // Topic management would need the device FCM token
      // which is stored separately. This is a placeholder for
      // the full implementation using token-based subscriptions.
      return null;
    });

/**
 * Sync admin role to a separate admins collection for Firestore rules.
 * Firestore rules cannot query fields, so we maintain admins/{auth_uid}
 * documents that rules can check with exists().
 */
exports.syncAdminRole = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onWrite(async (change, context) => {
      const after = change.after.exists ? change.after.data() : null;
      const before = change.before.exists ? change.before.data() : null;

      // On deletion, remove admin doc if it existed
      if (!after && before && before.auth_uid) {
        await db.collection("admins").doc(before.auth_uid).delete()
            .catch(() => {});
        return null;
      }

      if (!after || !after.auth_uid) return null;

      const afterRole = String(after.rol || after.role || "").toLowerCase();
      const afterRoles = Array.isArray(after.roles) ?
        after.roles.map((item) => String(item).toLowerCase()) : [];
      if (afterRole === "admin" || afterRole === "superadmin" ||
          afterRoles.includes("admin") || afterRoles.includes("superadmin")) {
        await db.collection("admins").doc(after.auth_uid).set({
          cofrade_id: context.params.cofradeId,
          updated: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`Admin doc created for ${after.auth_uid}`);
      } else {
        // Not admin — remove admin doc if exists
        await db.collection("admins").doc(after.auth_uid).delete()
            .catch(() => {});
      }
      return null;
    });

/**
 * Backfill/sync the current user's admin rules document on login.
 *
 * Migrated cofrade documents use COF-000xxx IDs, so Firestore rules cannot
 * authorize admin access with request.auth.uid == resource.id. The app may
 * still identify the user as admin from cofrades.rol; this callable bridges
 * that model into admins/{auth_uid}, which rules can check cheaply.
 */
exports.ensureAdminRoleForCurrentUser = functions
    .region("europe-west1")
    .https.onCall(async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Debes iniciar sesión para sincronizar permisos de administración.",
        );
      }

      const uid = context.auth.uid;
      const rawEmail = context.auth.token.email || "";
      const email = rawEmail.toLowerCase();
      const matches = new Map();

      const byAuthUid = await db.collection("cofrades")
          .where("auth_uid", "==", uid)
          .get();
      byAuthUid.forEach((doc) => matches.set(doc.id, doc));

      if (email) {
        const byEmail = await db.collection("cofrades")
            .where("email", "==", email)
            .get();
        byEmail.forEach((doc) => matches.set(doc.id, doc));

        if (rawEmail !== email) {
          const byRawEmail = await db.collection("cofrades")
              .where("email", "==", rawEmail)
              .get();
          byRawEmail.forEach((doc) => matches.set(doc.id, doc));
        }
      }

      let adminDoc = null;
      for (const doc of matches.values()) {
        const role = String(doc.data().rol || doc.data().role || "")
            .toLowerCase();
        const roles = Array.isArray(doc.data().roles) ?
          doc.data().roles.map((item) => String(item).toLowerCase()) : [];
        if (role === "admin" || role === "superadmin" ||
            roles.includes("admin") || roles.includes("superadmin")) {
          adminDoc = doc;
          break;
        }
      }

      if (!adminDoc) {
        await db.collection("admins").doc(uid).delete().catch(() => {});
        return {
          isAdmin: false,
          matchedCofrades: matches.size,
        };
      }

      await db.collection("admins").doc(uid).set({
        cofrade_id: adminDoc.id,
        source: "ensureAdminRoleForCurrentUser",
        updated: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      return {
        isAdmin: true,
        cofradeId: adminDoc.id,
        matchedCofrades: matches.size,
      };
    });

// ============================================================
// Set Admin Role by Cofrade Number (HTTPS endpoint)
// ============================================================

/**
 * HTTPS endpoint to set a cofrade as admin by their numero.
 * Usage: POST /setAdminByNumero with body { "numero": 73, "secret": "boanerges2024" }
 */
exports.setAdminByNumero = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        return res.status(204).send("");
      }

      try {
        const {numero, secret} = req.body || {};

        if (secret !== "boanerges2024") {
          return res.status(403).json({status: "error", message: "Invalid secret."});
        }
        if (!numero) {
          return res.status(400).json({status: "error", message: "numero is required."});
        }

        const snapshot = await db.collection("cofrades")
            .where("numero", "==", parseInt(numero))
            .limit(1)
            .get();

        if (snapshot.empty) {
          return res.status(404).json({status: "error", message: `Cofrade #${numero} not found.`});
        }

        const cofradeRef = snapshot.docs[0].ref;
        const cofradeData = snapshot.docs[0].data();

        await cofradeRef.update({
          rol: "admin",
          role: "admin",
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (cofradeData.auth_uid) {
          await db.collection("admins").doc(cofradeData.auth_uid).set({
            cofrade_id: snapshot.docs[0].id,
            updated: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        return res.json({
          status: "success",
          message: `Cofrade #${numero} (${cofradeData.nombre} ${cofradeData.apellidos}) is now admin.`,
        });
      } catch (error) {
        console.error("Error setting admin:", error);
        return res.status(500).json({status: "error", message: error.message});
      }
    });

// ============================================================
// Auto-Cleanup: Delete eventos and noticias older than 1 year
// ============================================================

/**
 * Scheduled function that runs daily at 3:00 AM (Madrid time).
 * Deletes eventos and noticias documents older than 1 year.
 * Does NOT delete convocatorias, cofrades, cuotas, or other data.
 */
exports.cleanupOldData = functions
    .region("europe-west1")
    .pubsub.schedule("every day 03:00")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
      const oneYearAgoTimestamp = admin.firestore.Timestamp.fromDate(oneYearAgo);

      let totalDeleted = 0;

      // Delete old eventos
      const eventosSnap = await db.collection("eventos")
          .where("fecha", "<", oneYearAgoTimestamp)
          .get();

      if (!eventosSnap.empty) {
        const batch = db.batch();
        eventosSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        totalDeleted += eventosSnap.size;
        console.log(`Deleted ${eventosSnap.size} eventos older than 1 year.`);
      }

      // Delete old noticias
      const noticiasSnap = await db.collection("noticias")
          .where("fecha", "<", oneYearAgoTimestamp)
          .get();

      if (!noticiasSnap.empty) {
        const batch = db.batch();
        noticiasSnap.docs.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        totalDeleted += noticiasSnap.size;
        console.log(`Deleted ${noticiasSnap.size} noticias older than 1 year.`);
      }

      console.log(`Cleanup complete. Total documents deleted: ${totalDeleted}`);
      return null;
    });

// ============================================================
// Evangelio del Día - Daily Gospel
// ============================================================

/**
 * Scheduled function to populate the evangelio_dia collection daily.
 * Fetches the daily gospel reading and stores it in Firestore.
 * Runs every day at 6:00 AM Madrid time.
 */
exports.fetchEvangelioDelDia = functions
    .region("europe-west1")
    .pubsub.schedule("0 6 * * *")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      const today = new Date();
      const yyyy = today.getFullYear();
      const mm = String(today.getMonth() + 1).padStart(2, "0");
      const dd = String(today.getDate()).padStart(2, "0");
      const fechaStr = `${yyyy}-${mm}-${dd}`;

      // Check if already exists
      const existing = await db.collection("evangelio_dia").doc(fechaStr).get();
      const existingData = existing.exists ? existing.data() : null;
      const placeholder = existingData &&
        existingData.fuente === "manual" &&
        (!existingData.texto ||
          existingData.texto.toLowerCase().includes("no se pudo"));
      if (existing.exists && !placeholder) {
        console.log(`Evangelio for ${fechaStr} already exists.`);
        return null;
      }

      try {
        // Fetch from Vatican API (daily readings)
        const fetch = (await import("node-fetch")).default;
        const url = `https://publication.evangelizo.ws/SP/days/${fechaStr}`;
        const resp = await fetch(url, {headers: {"Accept": "application/json"}});

        if (resp.ok) {
          const data = await resp.json();
          const readings = data.data || data;
          const gospel = readings.readings ?
            readings.readings.find((r) => r.type === "gospel" || r.reading_code === "gospel") : null;

          await db.collection("evangelio_dia").doc(fechaStr).set({
            fecha: fechaStr,
            titulo: gospel ? (gospel.title || "Evangelio del día") : "Evangelio del día",
            texto: gospel ? (gospel.text || JSON.stringify(readings).substring(0, 2000)) :
              JSON.stringify(readings).substring(0, 2000),
            referencia: gospel ? (gospel.reference || "") : "",
            fuente: "evangelizo.ws",
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`Evangelio for ${fechaStr} saved.`);
        } else {
          // Fallback: create placeholder entry
          await db.collection("evangelio_dia").doc(fechaStr).set({
            fecha: fechaStr,
            titulo: "Evangelio del día",
            texto: "No se pudo obtener el evangelio automáticamente. Un administrador puede editarlo manualmente.",
            referencia: "",
            fuente: "manual",
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`Evangelio placeholder for ${fechaStr} created (API status: ${resp.status}).`);
        }
      } catch (err) {
        console.error("Error fetching evangelio:", err);
        await db.collection("evangelio_dia").doc(fechaStr).set({
          fecha: fechaStr,
          titulo: "Evangelio del día",
          texto: "No se pudo obtener el evangelio automáticamente.",
          referencia: "",
          fuente: "manual",
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return null;
    });

/**
 * Removes evangelios outside the seven-day retention window.
 * Documents without a trustworthy, matching fecha are preserved.
 */
exports.cleanupOldEvangelios = functions
    .region("europe-west1")
    .pubsub.schedule("30 3 * * *")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      const todayKey = new Intl.DateTimeFormat("en-CA", {
        timeZone: "Europe/Madrid",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      }).format(new Date());
      const todayUtc = new Date(`${todayKey}T00:00:00Z`);
      const firstRetained = new Date(todayUtc);
      firstRetained.setUTCDate(firstRetained.getUTCDate() - 6);
      const firstRetainedKey = firstRetained.toISOString().slice(0, 10);
      const snapshot = await db.collection("evangelio_dia").get();
      const omitted = {};
      const deletions = [];

      const omit = (reason) => {
        omitted[reason] = (omitted[reason] || 0) + 1;
      };
      const parseFecha = (value) => {
        if (value && typeof value.toDate === "function") {
          return new Intl.DateTimeFormat("en-CA", {
            timeZone: "Europe/Madrid",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
          }).format(value.toDate());
        }
        if (value instanceof Date && !Number.isNaN(value.getTime())) {
          return new Intl.DateTimeFormat("en-CA", {
            timeZone: "Europe/Madrid",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
          }).format(value);
        }
        if (typeof value !== "string" ||
            !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
          return null;
        }
        const parsed = new Date(`${value}T00:00:00Z`);
        return parsed.toISOString().slice(0, 10) === value ? value : null;
      };

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const fecha = parseFecha(data.fecha);
        if (!fecha) {
          omit("fecha_ausente_o_formato_no interpretable");
          continue;
        }
        if (!/^\d{4}-\d{2}-\d{2}$/.test(doc.id)) {
          omit("id_no_es_fecha");
          continue;
        }
        if (fecha !== doc.id) {
          omit("fecha_no_coincide_con_id");
          continue;
        }
        if (fecha >= firstRetainedKey) {
          omit("dentro_de_retencion");
          continue;
        }
        deletions.push(doc.ref);
      }

      let deleted = 0;
      for (let index = 0; index < deletions.length; index += 400) {
        const batch = db.batch();
        deletions.slice(index, index + 400).forEach((ref) => batch.delete(ref));
        await batch.commit();
        deleted += Math.min(400, deletions.length - index);
      }
      console.log("Evangelio cleanup complete:", {
        todayKey,
        firstRetainedKey,
        scanned: snapshot.size,
        deleted,
        omitted,
      });
      return null;
    });

// ============================================================
// Manual Evangelio Trigger (for admins)
// ============================================================

/**
 * HTTPS endpoint to manually trigger fetching the evangelio del dia.
 * Useful when the scheduled function hasn't run yet or failed.
 */
exports.triggerFetchEvangelio = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      if (req.method === "OPTIONS") return res.status(204).send("");

      const today = new Date();
      const yyyy = today.getFullYear();
      const mm = String(today.getMonth() + 1).padStart(2, "0");
      const dd = String(today.getDate()).padStart(2, "0");
      const fechaStr = `${yyyy}-${mm}-${dd}`;

      try {
        const fetch = (await import("node-fetch")).default;
        const url = `https://publication.evangelizo.ws/SP/days/${fechaStr}`;
        const resp = await fetch(url, {headers: {"Accept": "application/json"}});

        if (resp.ok) {
          const data = await resp.json();
          const readings = data.data || data;
          const gospel = readings.readings ?
            readings.readings.find((r) =>
              r.type === "gospel" || r.reading_code === "gospel") : null;

          await db.collection("evangelio_dia").doc(fechaStr).set({
            fecha: fechaStr,
            titulo: gospel ? (gospel.title || "Evangelio del día") :
              "Evangelio del día",
            texto: gospel ? (gospel.text ||
              JSON.stringify(readings).substring(0, 2000)) :
              JSON.stringify(readings).substring(0, 2000),
            referencia: gospel ? (gospel.reference || "") : "",
            fuente: "evangelizo.ws",
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          });
          return res.json({
            status: "success",
            message: `Evangelio for ${fechaStr} saved.`,
          });
        } else {
          await db.collection("evangelio_dia").doc(fechaStr).set({
            fecha: fechaStr,
            titulo: "Evangelio del día",
            texto: "No se pudo obtener el evangelio automáticamente.",
            referencia: "",
            fuente: "manual",
            fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
          });
          return res.json({
            status: "fallback",
            message: `API returned ${resp.status}. Placeholder created.`,
          });
        }
      } catch (err) {
        console.error("Error fetching evangelio:", err);
        return res.status(500).json({
          status: "error", message: err.message,
        });
      }
    });

// ============================================================
// Birthday Email Notification (daily at 8 AM)
// ============================================================

/**
 * Sends birthday greeting emails to cofrades whose birthday is today.
 */
exports.sendBirthdayGreetings = withEmailSecret
    .region("europe-west1")
    .pubsub.schedule("0 8 * * *")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      const today = madridToday();
      const cofradesSnap = await db.collection("cofrades")
          .where("estado", "==", "Activo").get();
      const transporter = createEmailTransport();
      if (!transporter) {
        console.warn("Gmail secret not configured. Skipping birthday emails.");
        return null;
      }
      let sent = 0;
      let skipped = 0;
      let failed = 0;

      for (const doc of cofradesSnap.docs) {
        const c = doc.data();
        try {
          const birth = parseBirthDate(c.fecha_nacimiento) ||
              parseBirthDate(c.fecha_nacimiento_str);
          if (!birth || birth.getMonth() + 1 !== today.month ||
              birth.getDate() !== today.day) {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: not today or invalid date`);
            continue;
          }
          if (c.isActive === false) {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: inactive`);
            continue;
          }
          if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(c.email || ""))) {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: invalid email`);
            continue;
          }
          if (c.notificaciones_activas === false) {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: notifications disabled`);
            continue;
          }
          if (c.gdprDigitalRevoked === true ||
              c.gdpr_digital_revoked === true ||
              c.gdprDigitalStatus === "revoked" ||
              c.gdpr_digital_status === "revoked") {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: GDPR revoked`);
            continue;
          }
          if (c.communications_consent === false) {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: explicit communication refusal`);
            continue;
          }
          if (c.communications_consent == null) {
            console.log(`Birthday consent absent ${doc.id}: legacy record; continuing`);
          }
          const sendRef = db.collection("birthday_email_sends")
              .doc(`${doc.id}_${today.year}`);
          const sendResult = await db.runTransaction(async (tx) => {
            const existing = await tx.get(sendRef);
            if (existing.exists && existing.data().status === "sent") {
              return false;
            }
            tx.set(sendRef, {
              cofrade_id: doc.id,
              year: today.year,
              status: "pending",
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
              error: null,
            }, {merge: true});
            return true;
          });
          if (!sendResult) {
            skipped++;
            console.log(`Birthday skipped ${doc.id}: already sent`);
            continue;
          }
          try {
            const emailData = birthdayEmailData(c, today);
            const greetingText = emailData.age == null
              ? "Hoy celebras un día muy especial 🎉"
              : emailData.gender
              ? `Hoy ${emailData.gender.hero} de capa blanca celebra ` +
                `${emailData.age} vueltas al Sol 🎉`
              : `Hoy celebras ${emailData.age} vueltas al Sol 🎉`;
            const tenureText = birthdayTenureText(
                emailData.yearsInCofradia, emailData.gender);
            const paragraphs = [
              `¡Hola ${emailData.plainFirstName}!`,
              greetingText,
              "Te deseamos un día lleno de risas, de los tuyos y de " +
                "momentos que merezca la pena recordar. Que este nuevo año " +
                "de vida te traiga aventuras, salud y fuerzas para alcanzar " +
                "todo lo que te propongas.",
              "Disfrútalo al máximo. ¡Que cumplas muchos más!",
              "Un abrazo fraternal,\n" +
                "Cofradía de San Juan Evangelista · Ocaña · Desde 1714",
            ];
            if (tenureText) paragraphs.push(`P.D. ${tenureText}`);
            const htmlParagraphs = [
              `<p style="margin:0 0 18px;font-size:16px;">¡Hola ` +
                `<strong>${emailData.firstName}</strong>!</p>`,
              `<p style="margin:0 0 18px;">${escapeHtml(greetingText)}</p>`,
              `<p style="margin:0 0 18px;">Te deseamos un día lleno de risas, ` +
                `de los tuyos y de momentos que merezca la pena recordar. ` +
                `Que este nuevo año de vida te traiga aventuras, salud y ` +
                `fuerzas para alcanzar todo lo que te propongas.</p>`,
              `<p style="margin:0 0 18px;">Disfrútalo al máximo. ` +
                `¡Que cumplas muchos más!</p>`,
              `<p style="margin:0 0 18px;">Un abrazo fraternal,<br/>` +
                `<strong>Cofradía de San Juan Evangelista</strong><br/>` +
                `Ocaña · Desde 1714</p>`,
            ];
            if (tenureText) {
              htmlParagraphs.push(
                  `<p style="margin:0;">P.D. ${escapeHtml(tenureText)}</p>`);
            }
            await transporter.sendMail({
              from: `"Cofradía San Juan Evangelista" <${GMAIL_EMAIL}>`,
              to: c.email,
              subject: `¡Feliz cumpleaños, ${c.nombre || ""}! 🎂`,
              text: paragraphs.join("\n\n"),
              html: `
                <div style="font-family:Arial,sans-serif;max-width:600px;` +
                `margin:0 auto;color:#222;line-height:1.55;">
                  <div style="background:#6B1024;color:white;padding:24px;border-radius:8px 8px 0 0;text-align:center;">
                    <h1 style="margin:0;">¡Feliz cumpleaños!</h1>
                  </div>
                  <div style="padding:24px;border:1px solid #ddd;border-top:none;border-radius:0 0 8px 8px;">
                    ${htmlParagraphs.join("\n                    ")}
                  </div>
                </div>
              `,
            });
            await sendRef.update({
              status: "sent",
              sent_at: admin.firestore.FieldValue.serverTimestamp(),
              error: null,
            });
            sent++;
            console.log(`Birthday email sent to ${doc.id} (${c.email})`);
          } catch (err) {
            failed++;
            await sendRef.set({
              status: "failed",
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
              error: err.message,
            }, {merge: true});
            console.error(`Birthday email failed ${doc.id}:`, err.message);
          }
        } catch (err) {
          failed++;
          console.error(`Birthday processing failed ${doc.id}:`, err.message);
        }
      }
      console.log(`Birthday summary: sent=${sent}, skipped=${skipped}, failed=${failed}`);
      return null;
    });

// ============================================================
// Sugerencias Email Notification
// ============================================================

/**
 * Send email notification to admin when a new sugerencia is created.
 */
exports.onNewSugerencia = withEmailSecret
    .region("europe-west1")
    .firestore.document("sugerencias/{sugerenciaId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      console.log(`New sugerencia from ${data.cofrade_nombre}: ${data.titulo}`);

      const transporter = createEmailTransport();
      if (!transporter) {
        console.warn("Gmail secret not configured. Skipping sugerencia email.");
        return null;
      }

      const tipoLabel = data.tipo === "peticion" ? "Petición" : "Sugerencia";
      const mailOptions = {
        from: `"Cofradía San Juan Evangelista" <${GMAIL_EMAIL}>`,
        to: GMAIL_EMAIL,
        subject: `[${tipoLabel}] ${data.titulo} - ${data.cofrade_nombre}`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: #6B1024; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
              <h2 style="margin: 0;">Nueva ${tipoLabel}</h2>
            </div>
            <div style="padding: 20px; border: 1px solid #ddd; border-top: none; border-radius: 0 0 8px 8px;">
              <p><strong>De:</strong> ${data.cofrade_nombre || "Anónimo"}</p>
              <p><strong>Tipo:</strong> ${tipoLabel}</p>
              <p><strong>Título:</strong> ${data.titulo || "Sin título"}</p>
              <hr/>
              <p>${(data.descripcion || "").replace(/\n/g, "<br/>")}</p>
              <hr/>
              <p style="color: #666; font-size: 12px;">
                Enviado desde la app de la Cofradía el ${new Date().toLocaleString("es-ES", {timeZone: "Europe/Madrid"})}
              </p>
              <p style="color: #666; font-size: 12px;">
                Puedes responder desde el panel de administración.
              </p>
            </div>
          </div>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log("Sugerencia email sent successfully");
        await snap.ref.update({email_enviado: true});
      } catch (err) {
        console.error("Error sending sugerencia email:", err);
        await snap.ref.update({email_enviado: false, email_error: err.message});
      }

      return null;
    });

// ============================================================
// Admin Dashboard: Convocatorias Summary API
// ============================================================

/**
 * HTTPS endpoint that returns a summary of all convocatorias
 * with response statistics for the admin dashboard drilldown.
 */
exports.getConvocatoriasSummary = functions
    .region("europe-west1")
    .https.onRequest(async (req, res) => {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "GET, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
      if (req.method === "OPTIONS") return res.status(204).send("");

      try {
        const convocatoriasSnap = await db.collection("convocatorias")
            .orderBy("fecha_limite", "desc")
            .get();

        const summary = [];
        for (const doc of convocatoriasSnap.docs) {
          const data = doc.data();
          const respuestasSnap = await db.collection("convocatorias")
              .doc(doc.id).collection("respuestas").get();

          const respuestas = {};
          let totalResp = 0;
          respuestasSnap.docs.forEach((r) => {
            const rData = r.data();
            const valor = rData.respuesta || "sin_respuesta";
            respuestas[valor] = (respuestas[valor] || 0) + 1;
            totalResp++;
          });

          summary.push({
            id: doc.id,
            titulo: data.titulo || "",
            tipo: data.tipo || "",
            fecha_limite: data.fecha_limite ?
              data.fecha_limite.toDate().toISOString() : null,
            total_respuestas: totalResp,
            respuestas_desglose: respuestas,
            opciones: data.opciones || [],
            estado: data.fecha_limite &&
              data.fecha_limite.toDate() > new Date() ? "activa" : "cerrada",
          });
        }

        return res.json({status: "success", data: summary});
      } catch (error) {
        console.error("Error getting convocatorias summary:", error);
        return res.status(500).json({status: "error", message: error.message});
      }
    });
