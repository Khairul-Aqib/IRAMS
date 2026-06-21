const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const axios = require('axios');

initializeApp();
const db = getFirestore();

setGlobalOptions({ region: 'asia-southeast1', maxInstances: 10 });

const TOYYIBPAY_SECRET = defineSecret('TOYYIBPAY_SECRET');
const TOYYIBPAY_CATEGORY = defineSecret('TOYYIBPAY_CATEGORY');

const TOYYIBPAY_BASE = 'https://dev.toyyibpay.com';

// ToyyibPay returns the paying bank in a variety of field names depending on
// whether the data comes from the webhook payload or the getBillTransactions
// API. Normalise to a single label, e.g. 'Maybank'. Returns '' if none found.
function extractBankName(source) {
  if (!source || typeof source !== 'object') return '';
  const candidates = [
    source.payment_bank,
    source.paymentBank,
    source.bank,
    source.billpaymentBank,
    source.bill_payment_bank,
    source.payment_channel, // sometimes contains the bank name
  ];
  for (const c of candidates) {
    if (typeof c === 'string' && c.trim().length > 0) return c.trim();
  }
  return '';
}

function formatFpxPaymentMethod(bankName) {
  const b = (bankName || '').trim();
  return b.length > 0 && b.toUpperCase() !== 'FPX' ? `FPX - ${b}` : 'FPX';
}

// Calls ToyyibPay's getBillTransactions endpoint. Returns the parsed array
// (empty on any failure) so callers don't have to repeat error handling.
async function fetchBillTransactions(billCode, secretKey) {
  if (!billCode || !secretKey) return [];
  const params = new URLSearchParams();
  params.append('userSecretKey', secretKey);
  params.append('billCode', billCode);

  try {
    const resp = await axios.post(
      `${TOYYIBPAY_BASE}/index.php/api/getBillTransactions`,
      params,
      {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        timeout: 15000,
      },
    );
    return Array.isArray(resp.data) ? resp.data : [];
  } catch (err) {
    console.error('fetchBillTransactions error', err.message);
    return [];
  }
}

function callbackFunctionUrl() {
  const project = process.env.GCLOUD_PROJECT;
  return `https://asia-southeast1-${project}.cloudfunctions.net/toyyibPayCallback`;
}

function returnUrlFor(jobId) {
  const project = process.env.GCLOUD_PROJECT;
  return `https://${project}.web.app/payment/return?jobId=${encodeURIComponent(jobId)}`;
}

exports.createToyyibPayBill = onCall(
  { secrets: [TOYYIBPAY_SECRET, TOYYIBPAY_CATEGORY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign-in required.');
    }

    const { jobId, amount, userDetails } = request.data || {};
    if (!jobId || typeof jobId !== 'string') {
      throw new HttpsError('invalid-argument', 'jobId is required.');
    }
    if (typeof amount !== 'number' || amount <= 0) {
      throw new HttpsError('invalid-argument', 'amount must be a positive number (MYR).');
    }
    if (!userDetails || !userDetails.name || !userDetails.email || !userDetails.phone) {
      throw new HttpsError('invalid-argument', 'userDetails.name / email / phone are required.');
    }

    const returnUrl = returnUrlFor(jobId);

    const params = new URLSearchParams();
    params.append('userSecretKey', TOYYIBPAY_SECRET.value());
    params.append('categoryCode', TOYYIBPAY_CATEGORY.value());
    params.append('billName', `IRAMS Service - ${jobId}`.slice(0, 30));
    params.append('billDescription', `IRAMS Roadside Assistance (${jobId})`.slice(0, 100));
    params.append('billPriceSetting', '1');
    params.append('billPayorInfo', '1');
    params.append('billAmount', Math.round(amount * 100).toString());
    params.append('billReturnUrl', returnUrl);
    params.append('billCallbackUrl', callbackFunctionUrl());
    params.append('billExternalReferenceNo', jobId);
    params.append('billTo', userDetails.name);
    params.append('billEmail', userDetails.email);
    params.append('billPhone', userDetails.phone);
    params.append('billPaymentChannel', '2');

    let response;
    try {
      response = await axios.post(
        `${TOYYIBPAY_BASE}/index.php/api/createBill`,
        params,
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: 15000 },
      );
    } catch (err) {
      throw new HttpsError('unavailable', `ToyyibPay API error: ${err.message}`);
    }

    const body = response.data;
    console.log('ToyyibPay Raw Response:', JSON.stringify(body));

    const bill = Array.isArray(body) ? body[0] : body;

    if (bill && bill.status === 'error') {
      throw new HttpsError('internal', `ToyyibPay error: ${bill.msg}`);
    }

    if (!bill || !bill.BillCode) {
      throw new HttpsError(
        'internal',
        `ToyyibPay rejected bill creation. Raw: ${JSON.stringify(body)}`,
      );
    }

    await db.collection('Jobs').doc(jobId).set(
      {
        ToyyibPayBillCode: bill.BillCode,
        PaymentStatus: 'Pending',
        PaymentMethod: 'FPX',
        Status: 'Awaiting Payment',
        DateBillCreated: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      billCode: bill.BillCode,
      paymentUrl: `${TOYYIBPAY_BASE}/${bill.BillCode}`,
      returnUrl,
    };
  },
);

exports.verifyToyyibPayPayment = onCall(
  { secrets: [TOYYIBPAY_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign-in required.');
    }

    const { jobId, billCode: billCodeFromClient } = request.data || {};
    if (!jobId || typeof jobId !== 'string') {
      throw new HttpsError('invalid-argument', 'jobId is required.');
    }

    const jobRef = db.collection('Jobs').doc(jobId);
    const jobSnap = await jobRef.get();
    if (!jobSnap.exists) {
      return {
        paymentStatus: 'Error',
        detail: `No job record found for ${jobId}.`,
      };
    }
    const billCode =
      (typeof billCodeFromClient === 'string' && billCodeFromClient.length > 0)
        ? billCodeFromClient
        : jobSnap.get('ToyyibPayBillCode');
    if (!billCode) {
      return {
        paymentStatus: 'Error',
        detail: 'This job has no ToyyibPay bill attached. Please retry the payment.',
      };
    }

    const params = new URLSearchParams();
    params.append('userSecretKey', TOYYIBPAY_SECRET.value());
    params.append('billCode', billCode);

    let resp;
    try {
      resp = await axios.post(
        `${TOYYIBPAY_BASE}/index.php/api/getBillTransactions`,
        params,
        {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          timeout: 15000,
        },
      );
    } catch (err) {
      console.error('ToyyibPay getBillTransactions error', err.message);
      return {
        paymentStatus: 'Error',
        detail: `Could not reach ToyyibPay: ${err.message}`,
      };
    }

    const txns = Array.isArray(resp.data) ? resp.data : [];
    console.log(`getBillTransactions(${billCode}):`, JSON.stringify(txns));

    // Sandbox responses use payment_status; some production responses use
    // billpaymentStatus. Check both so we don't silently miss a success.
    const statusOf = (t) => (t.payment_status ?? t.billpaymentStatus ?? '').toString();

    if (txns.length === 0) {
      return {
        paymentStatus: 'NotFound',
        detail:
          'ToyyibPay has no transactions recorded for this bill yet. '
          + 'If you just paid, wait a few seconds and retry.',
      };
    }

    const successTxn = txns.find((t) => statusOf(t) === '1');
    const failedTxn = txns.find((t) => statusOf(t) === '3');

    if (successTxn) {
      // Full txn dump so we can see every field name ToyyibPay returns
      // (payment_bank vs bank vs paymentBank vs …) in the Firebase Logs.
      console.log('ToyyibPay Transaction Data:', JSON.stringify(successTxn));

      const bankName =
        successTxn.payment_bank
        || successTxn.bank
        || successTxn.paymentBank
        || extractBankName(successTxn)
        || 'FPX';
      const paymentMethod =
        bankName === 'FPX' ? 'FPX' : `FPX - ${bankName}`;

      await jobRef.set(
        {
          PaymentStatus: 'Paid',
          Status: 'Pending',
          PaymentMethod: paymentMethod,
          DatePaid: FieldValue.serverTimestamp(),
          ToyyibPayRefNo:
            successTxn.billpaymentInvoiceNo
            || successTxn.bill_payment_invoice_no
            || null,
          ManuallyVerifiedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return { paymentStatus: 'Paid', detail: 'Payment confirmed via ToyyibPay.' };
    }

    if (failedTxn) {
      await jobRef.set(
        {
          PaymentStatus: 'Failed',
          Status: 'Cancelled',
          DateCancelled: FieldValue.serverTimestamp(),
          ManuallyVerifiedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return {
        paymentStatus: 'Failed',
        detail: failedTxn.reason || 'ToyyibPay reported a failed transaction.',
      };
    }

    return {
      paymentStatus: 'Pending',
      detail: 'Transaction recorded but not yet confirmed by ToyyibPay.',
    };
  },
);

exports.toyyibPayCallback = onRequest(
  { invoker: 'public', secrets: [TOYYIBPAY_SECRET] },
  async (req, res) => {
  console.log('Callback Payload:', JSON.stringify(req.body));
  console.log('Callback Query:', JSON.stringify(req.query));
  console.log('Callback Method:', req.method, 'Content-Type:', req.get('content-type'));

  const bodyHasFields = req.body && Object.keys(req.body).length > 0;
  const payload = (req.method === 'POST' && bodyHasFields) ? req.body : req.query;

  const jobId = (
    payload.order_id ||
    payload.billExternalReferenceNo ||
    payload.billExternalReferenceNumber ||
    ''
  ).toString();

  const status = (payload.status || '').toString();
  const billCode = (payload.billcode || '').toString();
  const refno = (payload.refno || '').toString();
  const amountCents = Number(payload.amount || 0);
  const transactionId = (payload.transaction_id || '').toString();

  if (!jobId) {
    console.warn('toyyibPayCallback: missing jobId in payload', payload);
    res.status(400).send('Missing order_id');
    return;
  }

  const update = {
    LastCallbackAt: FieldValue.serverTimestamp(),
  };
  if (billCode) update.ToyyibPayBillCode = billCode;
  if (refno) update.ToyyibPayRefNo = refno;
  if (amountCents) update.ToyyibPayAmountCents = amountCents;
  if (transactionId) update.ToyyibPayTxnId = transactionId;

  if (status === '1') {
    update.PaymentStatus = 'Paid';
    update.Status = 'Pending';
    update.DatePaid = FieldValue.serverTimestamp();

    // Prefer the bank from the webhook payload; if ToyyibPay didn't include
    // it there, fall back to a quick getBillTransactions lookup.
    let bankName =
      payload.payment_bank
      || payload.bank
      || payload.paymentBank
      || extractBankName(payload)
      || '';

    if (!bankName && billCode) {
      const txns = await fetchBillTransactions(billCode, TOYYIBPAY_SECRET.value());
      console.log('ToyyibPay Transaction Data:', JSON.stringify(txns));
      const successTxn =
        txns.find((t) => (t.payment_status ?? t.billpaymentStatus ?? '').toString() === '1')
        || txns[0];
      if (successTxn) {
        bankName =
          successTxn.payment_bank
          || successTxn.bank
          || successTxn.paymentBank
          || extractBankName(successTxn)
          || '';
      }
    }

    const resolvedBank = bankName || 'FPX';
    update.PaymentMethod =
      resolvedBank === 'FPX' ? 'FPX' : `FPX - ${resolvedBank}`;
  } else if (status === '2') {
    update.PaymentStatus = 'Pending';
  } else if (status === '3') {
    update.PaymentStatus = 'Failed';
    update.Status = 'Cancelled';
    update.DateCancelled = FieldValue.serverTimestamp();
  }

  try {
    await db.collection('Jobs').doc(jobId).set(update, { merge: true });
    console.log(`toyyibPayCallback: Job ${jobId} updated — status=${status}`);
  } catch (err) {
    console.error('toyyibPayCallback write failed', err);
    res.status(500).send('Write failed');
    return;
  }

    res.status(200).send('OK');
  },
);

// =============================================================================
// FCM notifications — fired when Jobs/{jobId} transitions through key states
// =============================================================================

// Jobs store UserID as a string path (e.g. '/Users/U001'), set in
// UserFirestoreService.createJob. Older docs may hold a DocumentReference.
function resolveUserRef(userIdField) {
  if (!userIdField) return null;

  if (typeof userIdField === 'string') {
    const path = userIdField.startsWith('/') ? userIdField.slice(1) : userIdField;
    if (!path.startsWith('Users/') || path === 'Users/') return null;
    return db.doc(path);
  }

  if (typeof userIdField.path === 'string' && userIdField.path.startsWith('Users/')) {
    return userIdField;
  }

  return null;
}

async function fetchContractorName(contractorRef) {
  if (!contractorRef || typeof contractorRef.get !== 'function') {
    return 'Your contractor';
  }
  try {
    const snap = await contractorRef.get();
    if (!snap.exists) return 'Your contractor';
    const d = snap.data() || {};
    const name = (d.FullName || d.fullName || d.CompanyName || '').toString().trim();
    return name.length > 0 ? name : 'Your contractor';
  } catch (err) {
    console.error('fetchContractorName failed', err);
    return 'Your contractor';
  }
}

async function sendToUser(userRef, { title, body, data }) {
  let token;
  try {
    const snap = await userRef.get();
    if (!snap.exists) {
      console.log(`sendToUser: user doc ${userRef.path} not found`);
      return;
    }
    token = snap.get('fcmToken');
  } catch (err) {
    console.error(`sendToUser: read ${userRef.path} failed`, err);
    return;
  }

  if (typeof token !== 'string' || token.length === 0) {
    console.log(`sendToUser: no fcmToken on ${userRef.path}, skipping`);
    return;
  }

  const stringData = Object.fromEntries(
    Object.entries(data || {}).map(([k, v]) => [k, v == null ? '' : String(v)]),
  );

  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: { channelId: 'high_importance_channel', sound: 'default' },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    console.log(`FCM sent to ${userRef.path}: ${title}`);
  } catch (err) {
    console.error(`FCM send failed for ${userRef.path}: ${err.code || err.message}`);
    // Clear dead tokens so we don't keep hitting them
    if (
      err.code === 'messaging/registration-token-not-registered'
      || err.code === 'messaging/invalid-registration-token'
      || err.code === 'messaging/invalid-argument'
    ) {
      try {
        await userRef.update({ fcmToken: FieldValue.delete() });
      } catch (_) { /* non-fatal */ }
    }
  }
}

// Contractor-accepted trigger fires on transitions into any of these Status
// values. 'Driver Arriving' is the spec term; 'Accepted' is the wire value
// the contractor app actually writes today (see JobStatusWire.toWire).
const CONTRACTOR_ACCEPTED_STATUSES = new Set(['Driver Arriving', 'Accepted']);

exports.onJobUpdated = onDocumentUpdated('Jobs/{jobId}', async (event) => {
  const before = event.data?.before?.data() || {};
  const after = event.data?.after?.data() || {};
  const jobId = event.params.jobId;

  const userRef = resolveUserRef(after.UserID);
  if (!userRef) {
    console.log(`onJobUpdated: ${jobId} has no resolvable UserID`);
    return;
  }

  // Trigger 1: Payment just became 'Paid'
  if (before.PaymentStatus !== 'Paid' && after.PaymentStatus === 'Paid') {
    await sendToUser(userRef, {
      title: 'Payment Successful!',
      body: 'Payment Successful! We are finding a contractor for you.',
      data: { type: 'payment_success', jobId },
    });
  }

  // Trigger 2: Contractor just picked up the job
  const wasAccepted = CONTRACTOR_ACCEPTED_STATUSES.has(before.Status);
  const isAccepted = CONTRACTOR_ACCEPTED_STATUSES.has(after.Status);
  if (!wasAccepted && isAccepted) {
    const name = await fetchContractorName(after.ContractorAssigned);
    await sendToUser(userRef, {
      title: 'Help is on the way!',
      body: `Help is on the way! ${name} has accepted your request.`,
      data: { type: 'contractor_accepted', jobId, contractorName: name },
    });
  }
});
