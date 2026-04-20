const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {google} = require("googleapis");

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// Google Sheets Bidirectional Sync
// ============================================================

// Configuration - set these in Firebase environment config:
// firebase functions:config:set sheets.id="YOUR_GOOGLE_SHEET_ID"
// firebase functions:config:set sheets.service_email="YOUR_SERVICE_ACCOUNT_EMAIL"
const SHEET_NAME = "Cofrades";
const HEADER_ROW = [
  "Nº", "Nombre", "Apellidos", "Tutelado Digital",
  "Fecha Nacimiento", "Edad", "Género", "Año Alta",
  "Años Hermandad", "Año Mayordomía", "Estado",
  "Fecha Baja", "Causa Baja", "Domicilio", "Localidad",
  "Código Postal", "Teléfono Fijo", "Teléfono Móvil",
  "Email", "Estatura", "Talla", "¿Cuota?",
  "Cuota Metálico", "Cuota Domiciliada", "IBAN",
  "Titular IBAN", "GDPR Firmado", "Comentarios",
];

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
      const sheetId = functions.config().sheets?.id;
      if (!sheetId) {
        console.log("Google Sheets ID not configured. Skipping sync.");
        return null;
      }

      const cofradeId = context.params.cofradeId;

      // Handle deletion
      if (!change.after.exists) {
        console.log(`Cofrade ${cofradeId} deleted. Removing from sheet.`);
        await removeRowFromSheet(sheetId, cofradeId);
        return null;
      }

      const data = change.after.data();
      const row = [
        data.numero || "",
        data.nombre || "",
        data.apellidos || "",
        data.tutelado_digital || "",
        data.fecha_nacimiento ?
          new Date(data.fecha_nacimiento.seconds * 1000)
              .toLocaleDateString("es-ES") : "",
        data.edad || "",
        data.genero || "",
        data.anio_alta || "",
        data.anios_hermandad || "",
        data.anio_mayordomia || "",
        data.estado || "",
        data.fecha_baja ?
          new Date(data.fecha_baja.seconds * 1000)
              .toLocaleDateString("es-ES") : "",
        data.causa_baja || "",
        data.domicilio || "",
        data.localidad || "",
        data.codigo_postal || "",
        data.telefono_fijo || "",
        data.telefono_movil || "",
        data.email || "",
        data.estatura || "",
        data.talla || "",
        data.tiene_cuota ? "Sí" : "No",
        data.cuota_metalico || "",
        data.cuota_domiciliada || "",
        data.iban || "",
        data.titular_iban || "",
        data.gdpr_firmado ? "Sí" : "No",
        data.comentarios || "",
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
      const sheetId = functions.config().sheets?.id;
      if (!sheetId) {
        console.log("Google Sheets ID not configured. Skipping sync.");
        return null;
      }

      const sheets = await getSheetsClient();

      const response = await sheets.spreadsheets.values.get({
        spreadsheetId: sheetId,
        range: `${SHEET_NAME}!A:AB`,
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

        // Find cofrade by numero field
        const snapshot = await db.collection("cofrades")
            .where("numero", "==", numero).limit(1).get();
        if (snapshot.empty) continue;

        const cofradeRef = snapshot.docs[0].ref;

        const sheetData = {
          numero: numero,
          nombre: row[1] || "",
          apellidos: row[2] || "",
          tutelado_digital: row[3] || "",
          edad: parseInt(row[5]) || null,
          genero: row[6] || "",
          anio_alta: parseInt(row[7]) || null,
          anios_hermandad: parseInt(row[8]) || null,
          anio_mayordomia: parseInt(row[9]) || null,
          estado: row[10] || "Activo",
          causa_baja: row[12] || "",
          domicilio: row[13] || "",
          localidad: row[14] || "",
          codigo_postal: row[15] || "",
          telefono_fijo: row[16] || "",
          telefono_movil: row[17] || "",
          email: row[18] || "",
          estatura: parseInt(row[19]) || null,
          talla: row[20] || "",
          tiene_cuota: (row[21] || "").toLowerCase() === "sí",
          cuota_metalico: parseFloat(row[22]) || null,
          cuota_domiciliada: parseFloat(row[23]) || null,
          iban: row[24] || "",
          titular_iban: row[25] || "",
          gdpr_firmado: (row[26] || "").toLowerCase() === "sí",
          comentarios: row[27] || "",
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        };

        const currentData = cofradeRef ? snapshot.docs[0].data() : null;
        if (currentData && hasChanges(currentData, sheetData)) {
          batch.update(cofradeRef, sheetData);
          updateCount++;
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
 * Check if sheet data has changes compared to Firestore data.
 */
function hasChanges(firestoreData, sheetData) {
  const fieldsToCompare = [
    "nombre", "apellidos", "email", "telefono_fijo", "telefono_movil",
    "domicilio", "localidad", "codigo_postal", "estado", "genero",
    "tutelado_digital", "talla", "iban", "titular_iban", "comentarios",
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
      range: `${SHEET_NAME}!A${rowIndex + 1}:AB${rowIndex + 1}`,
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
        range: `${SHEET_NAME}!A${i + 1}:AB${i + 1}`,
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

      const callerDoc = await db
          .collection("cofrades")
          .doc(context.auth.uid)
          .get();
      if (!callerDoc.exists || callerDoc.data().rol !== "admin") {
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
