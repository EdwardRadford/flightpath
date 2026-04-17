/**
 * FlightPath — Firestore quiz-data seed script
 *
 * Writes all quiz questions from flightpath-seed/seed.js to the
 * quiz_questions Firestore collection. Documents are keyed by question ID
 * (e.g. 'ex_01_q1'). Each document matches the schema expected by
 * QuizQuestion.fromFirestore() in the Flutter app:
 *
 *   id            : String  — document ID (e.g. 'ex_01_q1')
 *   exercise_id   : String  — parent exercise (e.g. 'ex_01')
 *   sub_exercise  : String? — only present for ex_10_10a / ex_10_10b etc.
 *   question_text : String
 *   question_type : 'multiple_choice' | 'true_false'
 *   options       : Array<String>  — 4 or 2 display strings
 *   correct_answer: String  — full matching string from options[]
 *   explanation   : String
 *   difficulty    : 'EASY' | 'MEDIUM' | 'HARD'
 *   subject       : String  — CAP 1298 taxonomy
 *
 * PREREQUISITES:
 *   cd functions && npm install
 *   Place a serviceAccountKey.json in this directory (git-ignored):
 *     Firebase Console → Project Settings → Service Accounts → Generate New Private Key
 *
 * USAGE:
 *   node seedQuizData.js             — writes all questions to Firestore
 *   node seedQuizData.js --dry-run   — prints what would be written, no writes
 *   node seedQuizData.js --exercise ex_01  — seed one exercise only
 *
 * NOTES:
 *   - Safe to re-run: uses set() (not create()), so existing docs are overwritten.
 *   - Firestore batches are capped at 500 ops; this script chunks at 400.
 *   - Run from the functions/ directory so the relative require path resolves.
 */

'use strict';

const path = require('path');
const admin = require('firebase-admin');

// ---------------------------------------------------------------------------
// Parse CLI flags
// ---------------------------------------------------------------------------

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const exerciseFilter = (() => {
  const idx = args.indexOf('--exercise');
  return idx !== -1 ? args[idx + 1] : null;
})();

// ---------------------------------------------------------------------------
// Load quiz data from the seed script (no side-effects when required as module)
// ---------------------------------------------------------------------------

// Resolve relative to this file so the script works from any cwd.
const seedPath = path.resolve(__dirname, '../flightpath-seed/seed.js');
let quizQuestions;
try {
  ({ quizQuestions } = require(seedPath));
} catch (err) {
  console.error('Failed to load quiz data from', seedPath);
  console.error(err.message);
  process.exit(1);
}

if (!Array.isArray(quizQuestions) || quizQuestions.length === 0) {
  console.error('quiz_questions array is empty or missing in seed.js');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Apply optional exercise filter
// ---------------------------------------------------------------------------

const questions = exerciseFilter
  ? quizQuestions.filter((q) => q.exercise_id === exerciseFilter)
  : quizQuestions;

if (questions.length === 0) {
  console.error(`No questions found for exercise_id "${exerciseFilter}"`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Initialise Firebase Admin (skipped in dry-run)
// ---------------------------------------------------------------------------

let db;
if (!DRY_RUN) {
  const serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.json');
  let serviceAccount;
  try {
    serviceAccount = require(serviceAccountPath);
  } catch {
    console.error(
      'serviceAccountKey.json not found in functions/.\n' +
      'Download it from Firebase Console → Project Settings → Service Accounts.'
    );
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  db = admin.firestore();
}

// ---------------------------------------------------------------------------
// Seed
// ---------------------------------------------------------------------------

const BATCH_SIZE = 400;

async function seedQuizData() {
  if (DRY_RUN) {
    console.log('[DRY RUN] Would write the following documents to quiz_questions:\n');
    for (const q of questions) {
      console.log(`  ${q.id}  (exercise_id: ${q.exercise_id})`);
    }
    console.log(`\n[DRY RUN] Total: ${questions.length} documents. No writes performed.`);
    return;
  }

  console.log(`Seeding ${questions.length} quiz_questions documents to Firestore...`);

  for (let i = 0; i < questions.length; i += BATCH_SIZE) {
    const chunk = questions.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const doc of chunk) {
      const ref = db.collection('quiz_questions').doc(doc.id);
      batch.set(ref, doc);
    }
    await batch.commit();
    const end = Math.min(i + BATCH_SIZE, questions.length);
    console.log(`  Batch ${Math.floor(i / BATCH_SIZE) + 1}: wrote questions ${i + 1}–${end}`);
  }

  console.log(`\nDone. ${questions.length} documents written to quiz_questions.`);
  process.exit(0);
}

seedQuizData().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
