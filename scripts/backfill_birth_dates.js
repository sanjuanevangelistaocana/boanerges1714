/**
 * MANUAL MIGRATION — DO NOT RUN FROM THE APP OR CI.
 *
 * Run from a trusted Firebase Admin environment after reviewing the
 * documents and taking a Firestore backup:
 *   node scripts/backfill_birth_dates.js
 */
const admin = require("../functions/node_modules/firebase-admin");

admin.initializeApp();
const db = admin.firestore();

function parse(value) {
  if (value && typeof value.toDate === "function") value = value.toDate();
  if (value instanceof Date) return value;
  if (Number.isInteger(value)) return new Date(value);
  if (typeof value !== "string") return null;
  const match = value.trim().match(/^(\d{1,4})[\/-](\d{1,2})[\/-](\d{1,4})$/);
  if (!match) return null;
  const first = Number(match[1]);
  const second = Number(match[2]);
  const third = Number(match[3]);
  const year = first > 31 ? first : third;
  const month = second;
  const day = first > 31 ? third : first;
  const date = new Date(year, month - 1, day);
  if (year < 1900 || date.getFullYear() !== year ||
      date.getMonth() !== month - 1 || date.getDate() !== day) {
    return null;
  }
  return date;
}

async function main() {
  const snapshot = await db.collection("cofrades").get();
  let batch = db.batch();
  let pending = 0;
  let normalized = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (data.fecha_nacimiento != null) continue;
    const date = parse(data.fecha_nacimiento_str);
    if (!date || date > new Date()) continue;
    batch.update(doc.ref, {
      fecha_nacimiento: admin.firestore.Timestamp.fromDate(date),
      fecha_nacimiento_str: `${String(date.getDate()).padStart(2, "0")}/` +
        `${String(date.getMonth() + 1).padStart(2, "0")}/${date.getFullYear()}`,
    });
    normalized++;
    pending++;
    if (pending === 450) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  console.log(`Normalized ${normalized} birth dates.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
