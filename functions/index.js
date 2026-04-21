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
        console.log(`Cofrade ${cofradeId} deleted. Removing from sheet.`);
        await removeRowFromSheet(sheetId, cofradeId);
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
      ];

      await upsertRowInSheet(sheetId, cofradeId, row);
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
async function upsertRowInSheet(sheetId, cofradeId, rowData) {
  const sheets = await getSheetsClient();

  // Find existing row
  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: sheetId,
    range: `${SHEET_NAME}!A:A`,
  });

  const ids = response.data.values || [];
  let rowIndex = -1;

  for (let i = 0; i < ids.length; i++) {
    if (ids[i][0] === cofradeId) {
      rowIndex = i;
      break;
    }
  }

  if (rowIndex >= 0) {
    // Update existing row
    await sheets.spreadsheets.values.update({
      spreadsheetId: sheetId,
      range: `${SHEET_NAME}!A${rowIndex + 1}:AP${rowIndex + 1}`,
      valueInputOption: "RAW",
      requestBody: {values: [rowData]},
    });
    console.log(`Updated row ${rowIndex + 1} for cofrade ${cofradeId}`);
  } else {
    // Ensure header exists
    if (ids.length === 0) {
      await sheets.spreadsheets.values.append({
        spreadsheetId: sheetId,
        range: `${SHEET_NAME}!A1`,
        valueInputOption: "RAW",
        requestBody: {values: [HEADER_ROW]},
      });
    }
    // Append new row
    await sheets.spreadsheets.values.append({
      spreadsheetId: sheetId,
      range: `${SHEET_NAME}!A:AB`,
      valueInputOption: "RAW",
      requestBody: {values: [rowData]},
    });
    console.log(`Appended new row for cofrade ${cofradeId}`);
  }
}

/**
 * Remove a row from Google Sheets.
 */
async function removeRowFromSheet(sheetId, cofradeId) {
  const sheets = await getSheetsClient();

  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: sheetId,
    range: `${SHEET_NAME}!A:A`,
  });

  const ids = response.data.values || [];
  for (let i = 0; i < ids.length; i++) {
    if (ids[i][0] === cofradeId) {
      // Clear the row (don't delete to preserve row numbers)
      await sheets.spreadsheets.values.clear({
        spreadsheetId: sheetId,
        range: `${SHEET_NAME}!A${i + 1}:AP${i + 1}`,
      });
      console.log(`Cleared row ${i + 1} for deleted cofrade ${cofradeId}`);
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
        console.error("Error sending solicitud notification:", err);
      }
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

      const mailOptions = {
        from: `"Cofradía San Juan Evangelista" <${GMAIL_EMAIL}>`,
        to: GMAIL_EMAIL,
        replyTo: data.email,
        subject: `[Contacto Web] ${data.asunto || "Nuevo mensaje"} - ${data.nombre}`,
        html: `
          <h2>Nuevo mensaje de contacto</h2>
          <p><strong>Nombre:</strong> ${data.nombre || ""}</p>
          <p><strong>Email:</strong> ${data.email || ""}</p>
          <p><strong>Teléfono:</strong> ${data.telefono || "No proporcionado"}</p>
          <p><strong>Asunto:</strong> ${data.asunto || "Sin asunto"}</p>
          <hr/>
          <p>${(data.mensaje || "").replace(/\n/g, "<br/>")}</p>
          <hr/>
          <p><small>Enviado desde la web de la Cofradía - ${new Date().toLocaleString("es-ES", {timeZone: "Europe/Madrid"})}</small></p>
        `,
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
