const crypto = require("crypto");
const Iyzipay = require("iyzipay");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

const SUBSCRIPTION_PAYMENTS = "subscriptionPayments";

function getConfig() {
  return {
    apiKey: process.env.IYZICO_API_KEY || "",
    secretKey: process.env.IYZICO_SECRET_KEY || "",
    merchantId: process.env.IYZICO_MERCHANT_ID || "",
    baseUrl: process.env.IYZICO_BASE_URL || "https://sandbox-api.iyzipay.com",
    publicBaseUrl: process.env.PUBLIC_BASE_URL || "https://mika.technology",
    price: process.env.SUBSCRIPTION_PRICE || "299.00",
    subscriptionDays: Number.parseInt(process.env.SUBSCRIPTION_DAYS || "30", 10),
  };
}

function createIyzipayClient() {
  const config = getConfig();
  return new Iyzipay({
    apiKey: config.apiKey,
    secretKey: config.secretKey,
    uri: config.baseUrl,
  });
}

function promisifyIyzipay(method, request) {
  return new Promise((resolve, reject) => {
    method(request, (error, result) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(result);
    });
  });
}

function clientIp(req) {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.length > 0) {
    return forwarded.split(",")[0].trim();
  }
  return req.ip || "127.0.0.1";
}

function istanbulStartOfDay(reference = new Date()) {
  const key = reference.toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
  return new Date(`${key}T00:00:00+03:00`);
}

function addDays(date, days) {
  const copy = new Date(date.getTime());
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function formatIyzicoDate(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

async function ensureGroupExists(db, groupId) {
  const snapshot = await db.collection("groups").doc(groupId).get();
  if (!snapshot.exists) {
    throw new Error("group_not_found");
  }
  return snapshot.data() || {};
}

async function initializeCheckout(db, req) {
  const config = getConfig();
  if (!config.apiKey || !config.secretKey) {
    throw new Error("iyzico_not_configured");
  }

  const groupId = String(req.query.groupId || req.body?.groupId || "").trim();
  if (!groupId) {
    throw new Error("missing_group_id");
  }

  const group = await ensureGroupExists(db, groupId);
  const conversationId = `${groupId.slice(0, 8)}-${Date.now()}`;
  const ip = clientIp(req);
  const now = new Date();
  const groupName = String(group.name || "Shuttle Live").slice(0, 64);

  const paymentPayload = {
    groupId,
    status: "pending",
    price: config.price,
    createdAt: FieldValue.serverTimestamp(),
  };

  await db
    .collection("groups")
    .doc(groupId)
    .collection(SUBSCRIPTION_PAYMENTS)
    .doc(conversationId)
    .set(paymentPayload);

  await db.collection("subscriptionPaymentIndex").doc(conversationId).set({
    groupId,
    createdAt: FieldValue.serverTimestamp(),
  });

  const request = {
    locale: Iyzipay.LOCALE.TR,
    conversationId,
    price: config.price,
    paidPrice: config.price,
    currency: Iyzipay.CURRENCY.TRY,
    basketId: groupId,
    paymentGroup: Iyzipay.PAYMENT_GROUP.SUBSCRIPTION,
    callbackUrl: `${config.publicBaseUrl}/api/subscribe/callback`,
    enabledInstallments: [1],
    buyer: {
      id: groupId,
      name: "Shuttle Live",
      surname: "Abonelik",
      gsmNumber: "+905555555555",
      email: "hello@mika.technology",
      identityNumber: "11111111111",
      lastLoginDate: formatIyzicoDate(now),
      registrationDate: formatIyzicoDate(now),
      registrationAddress: "Turkey",
      ip,
      city: "Istanbul",
      country: "Turkey",
      zipCode: "34000",
    },
    shippingAddress: {
      contactName: groupName,
      city: "Istanbul",
      country: "Turkey",
      address: "Turkey",
      zipCode: "34000",
    },
    billingAddress: {
      contactName: groupName,
      city: "Istanbul",
      country: "Turkey",
      address: "Turkey",
      zipCode: "34000",
    },
    basketItems: [
      {
        id: "BT-SUB-1",
        name: "Shuttle Live Sürücü Aboneliği (1 ay)",
        category1: "Subscription",
        itemType: Iyzipay.BASKET_ITEM_TYPE.VIRTUAL,
        price: config.price,
      },
    ],
  };

  const iyzipay = createIyzipayClient();
  const result = await promisifyIyzipay(
    iyzipay.checkoutFormInitialize.create.bind(iyzipay.checkoutFormInitialize),
    request
  );

  if (result.status !== "success" || !result.paymentPageUrl) {
    await db
      .collection("groups")
      .doc(groupId)
      .collection(SUBSCRIPTION_PAYMENTS)
      .doc(conversationId)
      .set(
        {
          status: "failed",
          error: result.errorMessage || result.errorCode || "initialize_failed",
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    throw new Error(result.errorMessage || "initialize_failed");
  }

  await db
    .collection("groups")
    .doc(groupId)
    .collection(SUBSCRIPTION_PAYMENTS)
    .doc(conversationId)
    .set(
      {
        token: result.token,
        paymentPageUrl: result.paymentPageUrl,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  return {
    groupId,
    conversationId,
    token: result.token,
    paymentPageUrl: result.paymentPageUrl,
  };
}

async function computeSubscriptionDates(db, groupId) {
  const config = getConfig();
  const groupRef = db.collection("groups").doc(groupId);
  const snapshot = await groupRef.get();
  const data = snapshot.data() || {};

  const today = istanbulStartOfDay();
  let startDate = today;
  const existingEnd = data.subscriptionEndDate?.toDate?.();

  if (existingEnd && istanbulStartOfDay(existingEnd) >= today) {
    startDate = data.subscriptionStartDate?.toDate?.() || today;
    const extendedEnd = addDays(istanbulStartOfDay(existingEnd), config.subscriptionDays);
    return {
      startDate: Timestamp.fromDate(istanbulStartOfDay(startDate)),
      endDate: Timestamp.fromDate(extendedEnd),
      renewed: true,
    };
  }

  const endDate = addDays(today, config.subscriptionDays);
  return {
    startDate: Timestamp.fromDate(today),
    endDate: Timestamp.fromDate(endDate),
    renewed: false,
  };
}

async function markPaymentAndApplySubscription(db, {
  groupId,
  conversationId,
  paymentId,
  token,
  source,
}) {
  if (!groupId) {
    throw new Error("missing_group_id");
  }

  await ensureGroupExists(db, groupId);

  const paymentRef = conversationId
    ? db.collection("groups").doc(groupId).collection(SUBSCRIPTION_PAYMENTS).doc(conversationId)
    : null;

  if (paymentRef) {
    const paymentDoc = await paymentRef.get();
    if (paymentDoc.exists && paymentDoc.data()?.status === "paid") {
      return { alreadyApplied: true };
    }
  }

  const dates = await computeSubscriptionDates(db, groupId);
  const batch = db.batch();
  const groupRef = db.collection("groups").doc(groupId);

  batch.set(
    groupRef,
    {
      subscriptionStartDate: dates.startDate,
      subscriptionEndDate: dates.endDate,
      subscriptionUpdatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  if (paymentRef) {
    batch.set(
      paymentRef,
      {
        status: "paid",
        paymentId: paymentId || null,
        token: token || null,
        source,
        paidAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  await batch.commit();
  return { alreadyApplied: false, renewed: dates.renewed };
}

async function resolveGroupIdFromConversation(db, conversationId) {
  if (!conversationId) {
    return null;
  }
  const indexDoc = await db.collection("subscriptionPaymentIndex").doc(conversationId).get();
  if (indexDoc.exists) {
    return indexDoc.data()?.groupId || null;
  }
  return null;
}

async function retrieveAndApplyCheckout(db, token, conversationIdHint) {
  const iyzipay = createIyzipayClient();
  const result = await promisifyIyzipay(
    iyzipay.checkoutForm.retrieve.bind(iyzipay.checkoutForm),
    {
      locale: Iyzipay.LOCALE.TR,
      conversationId: conversationIdHint || "retrieve",
      token,
    }
  );

  if (result.status !== "success" || result.paymentStatus !== "SUCCESS") {
    return { ok: false, result };
  }

  const conversationId = result.conversationId || conversationIdHint;
  let groupId = result.basketId || null;
  if (!groupId) {
    groupId = await resolveGroupIdFromConversation(db, conversationId);
  }

  await markPaymentAndApplySubscription(db, {
    groupId,
    conversationId,
    paymentId: result.paymentId,
    token,
    source: "callback",
  });

  return { ok: true, result, groupId };
}

function verifyHppWebhookSignature(payload, signature, secretKey) {
  if (!signature || !secretKey) {
    return false;
  }
  const key =
    secretKey +
    String(payload.iyziEventType || "") +
    String(payload.iyziPaymentId ?? "") +
    String(payload.token || "") +
    String(payload.paymentConversationId || "") +
    String(payload.status || "");
  const expected = crypto.createHmac("sha256", secretKey).update(key).digest("hex");
  return expected === signature;
}

async function handleWebhook(db, req) {
  const config = getConfig();
  const payload = req.body || {};
  const signature = req.get("x-iyz-signature-v3") || req.get("X-IYZ-SIGNATURE-V3");

  if (signature && !verifyHppWebhookSignature(payload, signature, config.secretKey)) {
    throw new Error("invalid_signature");
  }

  if (payload.status !== "SUCCESS") {
    return { handled: false, reason: "not_success" };
  }

  if (payload.token) {
    await retrieveAndApplyCheckout(db, payload.token, payload.paymentConversationId);
    return { handled: true, via: "token" };
  }

  const groupId = await resolveGroupIdFromConversation(db, payload.paymentConversationId);
  if (groupId) {
    await markPaymentAndApplySubscription(db, {
      groupId,
      conversationId: payload.paymentConversationId,
      paymentId: payload.paymentId || payload.iyziPaymentId,
      token: payload.token,
      source: "webhook",
    });
    return { handled: true, via: "conversation" };
  }

  return { handled: false, reason: "unresolved" };
}

function sendJson(res, statusCode, body) {
  res.status(statusCode).set("Cache-Control", "no-store").json(body);
}

async function handleSubscribeInit(db, req, res) {
  try {
    const result = await initializeCheckout(db, req);
    sendJson(res, 200, result);
  } catch (error) {
    const message = error.message || "init_failed";
    const statusCode =
      message === "missing_group_id" || message === "group_not_found" ? 400 : 500;
    sendJson(res, statusCode, { error: message });
  }
}

async function handleSubscribeCallback(db, req, res) {
  const config = getConfig();
  const token = req.body?.token || req.query?.token;

  if (!token) {
    res.redirect(`${config.publicBaseUrl}/subscribe/complete?status=error`);
    return;
  }

  try {
    const outcome = await retrieveAndApplyCheckout(
      db,
      token,
      req.body?.conversationId || req.query?.conversationId
    );
    const status = outcome.ok ? "success" : "failure";
    res.redirect(`${config.publicBaseUrl}/subscribe/complete?status=${status}`);
  } catch (error) {
    console.error("[subscribeCallback]", error);
    res.redirect(`${config.publicBaseUrl}/subscribe/complete?status=error`);
  }
}

async function handleSubscribeWebhook(db, req, res) {
  try {
    await handleWebhook(db, req);
    res.status(200).send("OK");
  } catch (error) {
    console.error("[subscribeWebhook]", error);
    res.status(error.message === "invalid_signature" ? 401 : 500).send("ERR");
  }
}

module.exports = {
  handleSubscribeInit,
  handleSubscribeCallback,
  handleSubscribeWebhook,
};
