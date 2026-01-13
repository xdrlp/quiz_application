const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

const CONFIG_KEY = "bugreport";
const DEFAULT_DESTINATION = "nepomucenodiether0606@gmail.com";

function resolveConfig() {
	const config = functions.config()[CONFIG_KEY] || {};
	if (!config.user || !config.password) {
		throw new functions.https.HttpsError(
			"failed-precondition",
			"Missing Gmail credentials for bug report delivery. Run `firebase functions:config:set bugreport.user=... bugreport.password=...`."
		);
	}
	return {
		user: config.user,
		password: config.password,
		destination: config.destination || DEFAULT_DESTINATION,
	};
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
	const transporter = nodemailer.createTransport({
		service: "gmail",
		auth: {
			user: config.user,
			pass: config.password,
		},
	});

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
