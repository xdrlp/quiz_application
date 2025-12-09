This folder previously contained a Postmark-based Cloud Function to send
Firebase email verification links. You chose to use Firebase's built-in
verification instead; the function has been removed and replaced with
placeholders.

If you later want to reintroduce a transactional provider for verification
emails (SendGrid, Postmark, SES, etc.) you can recreate this folder and
add the proper implementation.
