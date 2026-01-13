This folder now hosts the callable function that forwards bug reports from
the quiz app to your inbox via Gmail.

## Development

- Run `npm install` inside `functions/` to install the dependencies.
- Use `firebase emulators:start --only functions` for local testing.
- Run `npm run lint` (optional) before deploying.

## Configuration & deployment

1.  Set the Gmail credentials using the Firebase CLI:
		```bash
		firebase functions:config:set \
			bugreport.user="your@gmail.com" \
			bugreport.password="your-app-password" \
			bugreport.destination="youremail@gmail.com"
		```
		`bugreport.destination` defaults to `bugreport.user` if omitted.
2.  Deploy with `npm run deploy` (which runs `firebase deploy --only functions`).

## Runtime

The callable function `sendBugReport` expects a payload like
`{ title, description, screen, userId }`. It sends an email subject
prefixed with `[Bug]` and includes the user metadata plus the description in
the body. By default reports go to nepomucenodiether0606@gmail.com unless you
override `bugreport.destination` with a different address when configuring
the function.
