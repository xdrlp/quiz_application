const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const CONFIG_KEY = "bugreport";
const DEFAULT_DESTINATION = "nepomucenodiether0606@gmail.com";

// Helper to get mail configuration
function resolveConfig() {
  const config = functions.config()[CONFIG_KEY] || {};
  // We only throw inside callable functions to return proper HttpsError.
  // For background triggers, we'll just return null if config is missing.
  return {
    user: config.user,
    password: config.password,
    destination: config.destination || DEFAULT_DESTINATION,
  };
}

// Helper to create transporter
function createTransporter(config) {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: config.user,
      pass: config.password,
    },
  });
}

exports.sendBugReport = functions.https.onCall(async (data, context) => {
	const title = (data?.title ?? "").toString().trim();
	const description = (data?.description ?? "").toString().trim();
	const name = (data?.name ?? "Not provided").toString().trim();
	const email = (data?.email ?? "Not provided").toString().trim();
	
	if (!title || !description) {
		throw new functions.https.HttpsError("invalid-argument", "Title and description are required.");
	}

	const screen = data?.screen ?? "unknown";
	const userId = data?.userId ?? context.auth?.uid ?? "anonymous";
	const metadata = data?.metadata ?? {};

	const config = resolveConfig();
  if (!config.user || !config.password) {
		throw new functions.https.HttpsError(
			"failed-precondition",
			"Missing Gmail credentials for bug report delivery. Run `firebase functions:config:set bugreport.user=... bugreport.password=...`."
		);
	}

	const transporter = createTransporter(config);

	const subject = `[Bug] ${title}`;
	const bodyLines = [
		`Reporter Name: ${name}`,
		`Reporter Email: ${email}`,
		`Screen: ${screen}`,
		`User ID: ${userId}`,
		`Metadata: ${JSON.stringify(metadata)}`,
		"",
		"Description:",
		description,
	];

	await transporter.sendMail({
		from: `"Quiz App" <${config.user}>`,
		to: config.destination,
		subject,
		text: bodyLines.join("\n"),
	});

	return { success: true };
});

exports.checkEmailExists = functions.https.onCall(async (data, context) => {
	const email = (data?.email ?? "").toString().trim();
	if (!email) {
		throw new functions.https.HttpsError("invalid-argument", "Email is required.");
	}
	try {
		await admin.auth().getUserByEmail(email);
		return { exists: true };
	} catch (error) {
		if (error.code === 'auth/user-not-found') {
			return { exists: false };
		}
		throw new functions.https.HttpsError("internal", "Error checking email.", error);
	}
});

/**
 * 3. Notify Teacher on Submission (Firestore Trigger)
 * Trigger: /quizzes/{quizId}/attempts/{attemptId} created
 */
exports.onAttemptCreated = functions.firestore
  .document("quizzes/{quizId}/attempts/{attemptId}")
  .onCreate(async (snap, context) => {
    const attempt = snap.data();
    const quizId = context.params.quizId;

    try {
      // Get the Quiz to find the author
      const quizDoc = await admin.firestore().collection("quizzes").doc(quizId).get();
      if (!quizDoc.exists) return null;
      
      const quiz = quizDoc.data();
      const authorId = quiz.authorId;
      if (!authorId) return null;

      // Get the Author (Teacher)
      const authorDoc = await admin.firestore().collection("users").doc(authorId).get();
      if (!authorDoc.exists) return null;

      const author = authorDoc.data();
      // Check preference - Default to true if field is missing
      const shouldNotify = author.notifySubmission !== false; 
      
      if (!shouldNotify) {
        console.log(`Instructor ${authorId} has disabled submission notifications.`);
        return null; // Silent fail
      }

      const fcmToken = author.fcmToken;
      if (!fcmToken) {
        console.log(`No FCM token for instructor ${authorId}`);
        return null;
      }

      const studentName = attempt.participantName || "A student";
      
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: `New Submission: ${quiz.title}`,
          body: `${studentName} has submitted an attempt.`,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'quiz_results',
          quizId: quizId,
          attemptId: context.params.attemptId,
        },
      });

      console.log(`Push notification sent to instructor ${authorId} for quiz ${quizId}`);
      return null;
    } catch (e) {
      console.error("Error sending submission notification:", e);
      return null;
    }
  });

/**
 * 4. Notify Student on Result Update (Firestore Trigger)
 * Trigger: /quizzes/{quizId}/attempts/{attemptId} updated
 */
exports.onAttemptUpdated = functions.firestore
  .document("quizzes/{quizId}/attempts/{attemptId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    // Check if score changed or status became 'graded'
    const scoreChanged = newData.score !== oldData.score;
    const justGraded = newData.status === 'graded' && oldData.status !== 'graded';

    if (!scoreChanged && !justGraded) {
      return null;
    }

    const userId = newData.userId; // Student ID
    if (!userId) return null;

    try {
      // Get Student's User settings
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) return null;

      const student = userDoc.data();
      // Check preference - Default to true
      const shouldNotify = student.notifyResultUpdate !== false; 

      if (!shouldNotify) {
        console.log(`Student ${userId} has disabled result notifications.`);
        return null;
      }

      const fcmToken = student.fcmToken;
      if (!fcmToken) {
        console.log(`No FCM token for student ${userId}`);
        return null;
      }

      // Get Quiz Title for context
      const quizId = context.params.quizId;
      const quizDoc = await admin.firestore().collection("quizzes").doc(quizId).get();
      const quizTitle = quizDoc.exists ? quizDoc.data().title : "Quiz";
      
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: `Results Updated: ${quizTitle}`,
          body: `Your new score is ${newData.score}. Tap to view.`,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          screen: 'attempt_detail',
          quizId: quizId,
          attemptId: context.params.attemptId,
        },
      });

      console.log(`Push notification sent to student ${userId} for quiz ${quizId}`);
      return null;
    } catch (e) {
      console.error("Error sending result notification:", e);
      return null;
    }
  });
