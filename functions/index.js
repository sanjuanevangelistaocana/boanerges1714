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
