# FlightPath

An AI study companion for UK student pilots, built in Flutter.

Learning to fly in the UK means passing nine written exams — air law, navigation, meteorology,
human performance and the rest — largely on your own, from material written for instructors rather
than for students. FlightPath turns that syllabus into something you can work through in the gaps
between lessons: structured exercises, progress measured against the real licence requirements,
and explanations when you get something wrong rather than a bare mark.

I built it while doing the training myself.

## What it does

- **Exercise engine** across the PPL theory syllabus, with per-topic progress tracked against the
  actual licence requirements rather than an arbitrary completion percentage.
- **Logbook and minimums** — hours logged against the thresholds the licence genuinely requires,
  so you can see what is still missing rather than just a running total.
- **AI explanations** for incorrect answers, grounded in the syllabus material. A confidently wrong
  answer about airspace is worse than no answer, so the explanation path is deliberately
  constrained rather than open-ended.
- **Goals and achievements**, because PPL theory is a long unsupervised slog and most people stall
  partway through.

## Stack

Flutter, targeting iOS and Android. Firebase for authentication and Firestore for data, with Cloud
Functions handling anything that must not be trusted to the client. Subscriptions validated
server-side.

## The security model, which is the part worth reading

`firestore.rules` is written so the client is never trusted with anything that decides access:

- Documents under `users/{uid}` are readable and writable only by their owner.
- The fields that control paid access — `has_purchased`, `subscription_status`, `granted_access`,
  `purchase_date` — are excluded from client writes by a rule that diffs the incoming document
  against the stored one and rejects the write if any of those keys are touched. They are set
  exclusively by Cloud Functions responding to a validated purchase webhook.

The effect is that a user cannot grant themselves a subscription by writing to their own document,
which is the obvious attack on a client-heavy Firebase app.

The Firebase keys in `lib/firebase_options.dart` are client identifiers, not credentials — they
ship inside every installed binary by design. The rules above are the actual security boundary.

## Running it

See `RUNNING.md`. You will need your own Firebase project; the configuration here points at mine.

## Status

Built between 2024 and 2026. Development is currently paused while I work on other things.

It is public because the security model and the exercise engine are worth reading, and because
people rarely get to see inside a finished app built entirely by one person.

## Licence

No open licence — published to be read, not reused. Ask if you want to do something with it.

Built by [Edward Radford](https://edwardradford.co.uk).
