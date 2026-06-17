const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');

admin.initializeApp();
const db = admin.firestore();

// Set SENDGRID_API_KEY in functions config or env
sgMail.setApiKey(process.env.SENDGRID_API_KEY || functions.config().sendgrid.key);

exports.processEmailHistory = functions.firestore
  .document('email_history/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;
    const id = context.params.docId;
    const recipients = data.recipients || [];
    const subject = data.subject || 'Amaran Kehadiran Pelajar';
    const body = data.body || '';

    if (!recipients.length) {
      await db.collection('email_history').doc(id).set({ status: 'Tiada Penerima' }, { merge: true });
      return null;
    }

    try {
      const msg = {
        to: recipients,
        from: 'no-reply@institusi.edu.my',
        subject,
        text: body,
      };
      await sgMail.send(msg);
      await db.collection('email_history').doc(id).set({ status: 'Dihantar', sentAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      return null;
    } catch (e) {
      await db.collection('email_history').doc(id).set({ status: 'Gagal', error: e.toString() }, { merge: true });
      return null;
    }
  });

exports.notifyOnNotificationCreate = functions.firestore
  .document('notifications/{docId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;
    const recipients = data.recipients || [];
    const title = `Amaran Kehadiran: ${data.studentName || ''}`;
    const body = `${data.studentName || ''} (${data.matricNo || ''}) - ${data.warningLabel || ''} (${(data.attendancePercentage||0).toFixed(1)}%)`;

    // If you use topic or device tokens stored in users, fetch them here.
    // This example writes a simple 'push' collection that your client can listen to and display.
    const pushes = recipients.map(id => ({ userId: id, title, body, createdAt: admin.firestore.FieldValue.serverTimestamp() }));
    const batch = db.batch();
    pushes.forEach(p => {
      const r = db.collection('push_notifications').doc();
      batch.set(r, p);
    });
    await batch.commit();
    return null;
  });
