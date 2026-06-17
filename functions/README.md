Background worker options for sending emails and push notifications:

1) Cloud Function (recommended)
   - Trigger: Firestore onCreate for `email_history` documents.
   - Action: send email via SMTP/SendGrid and update the doc status to 'Dihantar' or 'Gagal'.

2) Server process (Node/Python) run by the team that polls `email_history` and sends emails.

Example Cloud Function (Node) available if you want me to generate it.
