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
  "ID", "Nombre", "Apellidos", "Email", "Teléfono",
  "Dirección", "Localidad", "Código Postal",
  "Fecha Ingreso", "Cargo", "Estado", "Rol",
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
        cofradeId,
        data.nombre || "",
        data.apellidos || "",
        data.email || "",
        data.telefono || "",
        data.direccion || "",
        data.localidad || "",
        data.codigo_postal || "",
        data.fecha_ingreso ?
          new Date(data.fecha_ingreso.seconds * 1000)
              .toLocaleDateString("es-ES") : "",
        data.cargo || "",
        data.estado || "",
        data.rol || "",
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
        range: `${SHEET_NAME}!A:L`,
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
        if (!row[0]) continue; // Skip rows without ID

        const cofradeId = row[0];
        const cofradeRef = db.collection("cofrades").doc(cofradeId);
        const existing = await cofradeRef.get();

        const sheetData = {
          nombre: row[1] || "",
          apellidos: row[2] || "",
          email: row[3] || "",
          telefono: row[4] || "",
          direccion: row[5] || "",
          localidad: row[6] || "",
          codigo_postal: row[7] || "",
          cargo: row[9] || "",
          estado: row[10] || "activo",
          rol: row[11] || "cofrade",
          fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (existing.exists) {
          const currentData = existing.data();
          // Only update if sheet data differs from Firestore
          if (hasChanges(currentData, sheetData)) {
            batch.update(cofradeRef, sheetData);
            updateCount++;
          }
        }
        // Note: We don't create new cofrades from sheet
        // (they must register through the app for proper auth setup)
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
    "nombre", "apellidos", "email", "telefono",
    "direccion", "localidad", "codigo_postal", "cargo", "estado", "rol",
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
      range: `${SHEET_NAME}!A${rowIndex + 1}:L${rowIndex + 1}`,
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
      range: `${SHEET_NAME}!A:L`,
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
        range: `${SHEET_NAME}!A${i + 1}:L${i + 1}`,
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
