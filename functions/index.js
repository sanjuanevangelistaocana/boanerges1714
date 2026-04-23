const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {google} = require("googleapis");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// Google Sheets Bidirectional Sync
// ============================================================

// Google Sheet ID for bidirectional sync
const SPREADSHEET_ID = "1YoQh6kcRU7VVg4bbz4pUfEyqPSXgqpT9Lfq6VLfhGCQ";

// Gmail SMTP configuration
const GMAIL_EMAIL = "sanjuanevangelistaocana@gmail.com";
const GMAIL_APP_PASSWORD = "kjsuqnypocxblgtn";
const SHEET_NAME = "Relación Cofrades";
// Column indices matching the actual Google Sheet structure:
// 0:Nº 1:Nombre 2:Apellidos 3:Tutelado Digital 4:Fecha Nacimiento
// 5:Edad 6:Género 7:Año Alta 8:Años Hermandad 9:Año Mayordomía
// 10:Estado 11:Fecha Baja 12:Causa Baja 13:Domicilio 14:Localidad
// 15:Código Postal 16:Teléfono Fijo 17:Teléfono Móvil 18:Email
// 19:Estatura 20:Talla 21:¿Cuota? 22:Cuota Metálico 23:Cuota Domiciliada
// 24:IBAN 25:Titular IBAN 26:Raul 27:Check Data 28:GDPR Firmado
// 29:Comentarios 30+: new columns appended by the app
const EXISTING_SHEET_COLS = 30; // A through AD (columns already in user's Sheet)

/**
 * Parse a number that may use Spanish thousand separator ("1.991" → 1991).
 */
function parseSpanishInt(val) {
  if (!val) return null;
  const cleaned = String(val).replace(/\./g, "").replace(/,/g, ".");
  const num = parseInt(cleaned, 10);
  return isNaN(num) ? null : num;
}

/**
 * Parse a boolean from Sheet (handles TRUE/FALSE, Sí/No, SI/NO).
 */
function parseSheetBool(val) {
  if (!val) return false;
  const v = String(val).trim().toUpperCase();
  return v === "TRUE" || v === "SÍ" || v === "SI" || v === "1";
}

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

// New columns appended by the app (starting at column AE = index 30)
const NEW_COL_HEADERS = [
  "Email Secundario", "Teléfono Secundario", "DNI",
  "DNI Tutor", "Parentesco Tutor", "Cargo", "Tiene Túnica Propia",
];
const TOTAL_SHEET_COLS = EXISTING_SHEET_COLS + NEW_COL_HEADERS.length; // 37

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
        data.tutelado_digital ? "TRUE" : "FALSE",       // 3: Tutelado Digital
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
 * Scheduled function to sync Google Sheets → Firestore.
 * Runs every 15 minutes to pick up manual edits in the Sheet.
 */
exports.syncSheetToFirestore = functions
    .region("europe-west1")
    .pubsub.schedule("every 15 minutes")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      const sheetId = SPREADSHEET_ID;
      const sheets = await getSheetsClient();

      const response = await sheets.spreadsheets.values.get({
        spreadsheetId: sheetId,
        range: `${SHEET_NAME}!A:AP`,
      });

      const rows = response.data.values;
      if (!rows || rows.length <= 1) {
        console.log("No data rows found in sheet.");
        return null;
      }

      // Skip header row
      const batch = db.batch();
      let updateCount = 0;

      for (let i = 1; i < rows.length; i++) {
        const row = rows[i];
        if (!row[0] && !row[1]) continue; // Skip empty rows

        // Match by numero (Nº column) to find Firestore doc
        const numero = parseInt(row[0]) || null;
        if (!numero) continue;

        const sheetData = rowToFirestoreData(row, numero);

        // Find cofrade by numero field
        const snapshot = await db.collection("cofrades")
            .where("numero", "==", numero).limit(1).get();

        if (snapshot.empty) {
          // Create new cofrade from Sheet data
          sheetData.rol = "cofrade";
          sheetData.notificaciones_activas = true;
          const newRef = db.collection("cofrades").doc();
          batch.set(newRef, sheetData);
          updateCount++;
          console.log(`Creating new cofrade #${numero} from Sheet.`);
        } else {
          const cofradeRef = snapshot.docs[0].ref;
          const currentData = snapshot.docs[0].data();
          if (hasChanges(currentData, sheetData)) {
            batch.update(cofradeRef, sheetData);
            updateCount++;
          }
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        console.log(`Updated ${updateCount} cofrades from Google Sheet.`);
      } else {
        console.log("No changes detected in Google Sheet.");
      }

      return null;
    });

/**
 * Convert a Sheet row array to a Firestore data object.
 * Uses correct column indices matching the actual Google Sheet.
 */
function rowToFirestoreData(row, numero) {
  return {
    numero: numero,
    nombre: row[1] || "",
    apellidos: row[2] || "",
    tutelado_digital: row[3] || "",
    fecha_nacimiento_str: row[4] || "",
    edad: parseSpanishInt(row[5]),
    genero: row[6] || "",
    anio_alta: parseSpanishInt(row[7]),
    anios_hermandad: parseSpanishInt(row[8]),
    anio_mayordomia: parseSpanishInt(row[9]),
    estado: row[10] || "Activo",
    fecha_baja_str: row[11] || "",
    causa_baja: row[12] || "",
    domicilio: row[13] || "",
    localidad: row[14] || "",
    codigo_postal: row[15] || "",
    telefono_fijo: row[16] || "",
    telefono_movil: row[17] || "",
    email: row[18] || "",
    estatura: parseSpanishInt(row[19]),
    talla: row[20] || "",
    tiene_cuota: parseSheetBool(row[21]),
    cuota_metalico: parseSheetBool(row[22]),
    cuota_domiciliada: parseSheetBool(row[23]),
    iban: row[24] || "",
    titular_iban: row[25] || "",
    // 26: Raul (skip), 27: Check Data (skip)
    gdpr_firmado: parseSheetBool(row[28]),
    comentarios: row[29] || "",
    // New columns (AE-AK, indices 30-36)
    email_secundario: row[30] || "",
    telefono_secundario: row[31] || "",
    dni: row[32] || "",
    dni_tutor: row[33] || "",
    parentesco_tutor: row[34] || "",
    cargo: row[35] || "",
    tiene_tunica_propia: parseSheetBool(row[36]),
    fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
  };
}

/**
 * Check if sheet data has changes compared to Firestore data.
 */
function hasChanges(firestoreData, sheetData) {
  const fieldsToCompare = [
    "nombre", "apellidos", "email", "telefono_fijo", "telefono_movil",
    "domicilio", "localidad", "codigo_postal", "estado", "genero",
    "tutelado_digital", "talla", "iban", "titular_iban", "comentarios",
    "email_secundario", "telefono_secundario", "dni", "dni_tutor",
    "parentesco_tutor", "cargo",
  ];
  return fieldsToCompare.some(
      (field) => (firestoreData[field] || "") !== (sheetData[field] || ""),
  );
}

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
exports.onNewSolicitud = functions
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
      if (!GMAIL_APP_PASSWORD) {
        console.log("Gmail app password not configured. Skipping solicitud email.");
        return null;
      }

      try {
        const transporter = nodemailer.createTransport({
          service: "gmail",
          auth: {
            user: GMAIL_EMAIL,
            pass: GMAIL_APP_PASSWORD,
          },
        });

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
        bodyParts.push(`<p>Gestiona esta solicitud desde el <a href="https://boanerges1714.web.app/admin">panel de administración</a>.</p>`);

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
exports.onNewContactMessage = functions
    .region("europe-west1")
    .firestore.document("contacto/{messageId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      console.log(`New contact message from ${data.nombre} (${data.email})`);

      if (!GMAIL_APP_PASSWORD) {
        console.log("Gmail app password not configured. Skipping email.");
        return null;
      }

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: GMAIL_EMAIL,
          pass: GMAIL_APP_PASSWORD,
        },
      });

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
      try {
        const sheets = await getSheetsClient();
        const response = await sheets.spreadsheets.values.get({
          spreadsheetId: SPREADSHEET_ID,
          range: `${SHEET_NAME}!A:AP`,
        });

        const rows = response.data.values;
        if (!rows || rows.length <= 1) {
          res.json({status: "no_data", message: "No data rows found in sheet.", rowCount: rows ? rows.length : 0});
          return;
        }

        // Try to add new column headers (non-blocking if sheet is protected)
        const headerRow = rows[0];
        if (headerRow.length < TOTAL_SHEET_COLS) {
          try {
            const gridCols = await ensureGridColumns(
                sheets, SPREADSHEET_ID, TOTAL_SHEET_COLS,
            );
            if (gridCols >= TOTAL_SHEET_COLS) {
              const numExistingNew = Math.max(
                  0, headerRow.length - EXISTING_SHEET_COLS,
              );
              const missingHeaders = NEW_COL_HEADERS.slice(numExistingNew);
              if (missingHeaders.length > 0) {
                const startIdx = headerRow.length;
                const endIdx = startIdx + missingHeaders.length - 1;
                await sheets.spreadsheets.values.update({
                  spreadsheetId: SPREADSHEET_ID,
                  range: `${SHEET_NAME}!${colLetter(startIdx)}1:${colLetter(endIdx)}1`,
                  valueInputOption: "RAW",
                  requestBody: {values: [missingHeaders]},
                });
                console.log(
                    `Added ${missingHeaders.length} new column headers.`,
                );
              }
            } else {
              console.warn(
                  `Sheet has ${gridCols} cols, need ${TOTAL_SHEET_COLS}. ` +
                  "Add columns manually or remove sheet protection.",
              );
            }
          } catch (headerErr) {
            console.warn(
                "Could not add new headers (protected?):", headerErr.message,
            );
          }
        }

        const batch = db.batch();
        let createCount = 0;
        let updateCount = 0;
        const details = [];

        for (let i = 1; i < rows.length; i++) {
          const row = rows[i];
          if (!row[0] && !row[1]) continue;

          const numero = parseInt(row[0]) || null;
          if (!numero) {
            details.push(`Row ${i + 1}: skipped (no numero), col A = "${row[0]}"`);
            continue;
          }

          const sheetData = rowToFirestoreData(row, numero);

          const snapshot = await db.collection("cofrades")
              .where("numero", "==", numero).limit(1).get();

          if (snapshot.empty) {
            sheetData.rol = "cofrade";
            sheetData.notificaciones_activas = true;
            const newRef = db.collection("cofrades").doc();
            batch.set(newRef, sheetData);
            createCount++;
            details.push(`Row ${i + 1}: CREATE cofrade #${numero} - ${row[1]} ${row[2]}`);
          } else {
            const currentData = snapshot.docs[0].data();
            if (hasChanges(currentData, sheetData)) {
              batch.update(snapshot.docs[0].ref, sheetData);
              updateCount++;
              details.push(`Row ${i + 1}: UPDATE cofrade #${numero}`);
            } else {
              details.push(`Row ${i + 1}: NO CHANGES cofrade #${numero}`);
            }
          }
        }

        if (createCount > 0 || updateCount > 0) {
          await batch.commit();
        }

        res.json({
          status: "ok",
          totalRows: rows.length - 1,
          created: createCount,
          updated: updateCount,
          details: details,
        });
      } catch (err) {
        console.error("triggerSheetSync error:", err);
        res.status(500).json({status: "error", message: err.message, stack: err.stack});
      }
    });

exports.manageFcmTopics = functions
    .region("europe-west1")
    .firestore.document("cofrades/{cofradeId}")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();

      // Check if estado or rol changed
      if (before.estado === after.estado && before.rol === after.rol) {
        return null;
      }

      console.log(
          `Cofrade ${context.params.cofradeId} status changed: ` +
        `${before.estado}->${after.estado}, ${before.rol}->${after.rol}`,
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

      if (after.rol === "admin") {
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
      if (existing.exists) {
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
exports.sendBirthdayGreetings = functions
    .region("europe-west1")
    .pubsub.schedule("0 8 * * *")
    .timeZone("Europe/Madrid")
    .onRun(async () => {
      const today = new Date();
      const mm = today.getMonth() + 1;
      const dd = today.getDate();

      const cofradesSnap = await db.collection("cofrades")
          .where("estado", "==", "Activo")
          .get();

      const birthdayCofrades = [];
      cofradesSnap.docs.forEach((doc) => {
        const data = doc.data();
        if (data.fecha_nacimiento) {
          const fn = data.fecha_nacimiento.toDate();
          if (fn.getMonth() + 1 === mm && fn.getDate() === dd) {
            birthdayCofrades.push({...data, id: doc.id});
          }
        }
      });

      if (birthdayCofrades.length === 0) {
        console.log("No birthdays today.");
        return null;
      }

      if (!GMAIL_APP_PASSWORD) {
        console.log("Gmail not configured. Skipping birthday emails.");
        return null;
      }

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {user: GMAIL_EMAIL, pass: GMAIL_APP_PASSWORD},
      });

      for (const c of birthdayCofrades) {
        if (!c.email) continue;
        const age = today.getFullYear() - c.fecha_nacimiento.toDate()
            .getFullYear();
        try {
          await transporter.sendMail({
            from: `"Cofradía San Juan Evangelista" <${GMAIL_EMAIL}>`,
            to: c.email,
            subject: `¡Feliz cumpleaños, ${c.nombre}! 🎂`,
            html: `
              <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
                <div style="background:#6B1024;color:white;padding:24px;border-radius:8px 8px 0 0;text-align:center;">
                  <h1 style="margin:0;">🎂 ¡Feliz Cumpleaños!</h1>
                </div>
                <div style="padding:24px;border:1px solid #ddd;border-top:none;border-radius:0 0 8px 8px;">
                  <p style="font-size:16px;">Querido/a <strong>${c.nombre} ${c.apellidos || ""}</strong>,</p>
                  <p>La Cofradía de San Juan Evangelista de Ocaña te desea un muy feliz cumpleaños.</p>
                  <p>Hoy cumples <strong>${age} años</strong>. Esperamos que pases un día maravilloso rodeado/a de los tuyos.</p>
                  <p style="margin-top:20px;">Un abrazo fraternal,<br/><strong>Cofradía de San Juan Evangelista</strong><br/>Ocaña · Desde 1714</p>
                </div>
              </div>
            `,
          });
          console.log(`Birthday email sent to ${c.nombre} (${c.email})`);
        } catch (err) {
          console.error(`Error sending birthday email to ${c.email}:`,
              err.message);
        }
      }

      console.log(`Sent ${birthdayCofrades.length} birthday greetings.`);
      return null;
    });

// ============================================================
// Sugerencias Email Notification
// ============================================================

/**
 * Send email notification to admin when a new sugerencia is created.
 */
exports.onNewSugerencia = functions
    .region("europe-west1")
    .firestore.document("sugerencias/{sugerenciaId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      console.log(`New sugerencia from ${data.cofrade_nombre}: ${data.titulo}`);

      if (!GMAIL_APP_PASSWORD) {
        console.log("Gmail app password not configured. Skipping email.");
        return null;
      }

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: GMAIL_EMAIL,
          pass: GMAIL_APP_PASSWORD,
        },
      });

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
