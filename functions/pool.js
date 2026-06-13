const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { FieldValue, Timestamp, getFirestore } = require("firebase-admin/firestore");

const MONTHLY_TARGET = 99;
const ANNUAL_TARGET = 1000;
const MONTHLY_DAYS = 30;
const ANNUAL_DAYS = 365;

function istanbulStartOfDay(reference = new Date()) {
  const parts = reference.toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" }).split("-");
  return new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])));
}

function addDays(date, days) {
  const next = new Date(date.getTime());
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

function allowedContributionAmount(productId) {
  const match = String(productId || "").match(/\.pool\.(\d+)$/);
  if (!match) return null;
  const amount = Number.parseInt(match[1], 10);
  const allowed = [50, 100, 250, 500, 1000];
  return allowed.includes(amount) ? amount : null;
}

async function assertGroupMember(db, groupId, uid) {
  const groupRef = db.collection("groups").doc(groupId);
  const groupSnap = await groupRef.get();

  if (!groupSnap.exists) {
    throw new HttpsError("not-found", "group_not_found");
  }

  const memberSnap = await groupRef.collection("members").doc(uid).get();
  if (memberSnap.exists) {
    return { groupRef, groupSnap };
  }

  const membersByUserID = await groupRef.collection("members")
    .where("userID", "==", uid)
    .limit(1)
    .get();
  if (!membersByUserID.empty) {
    return { groupRef, groupSnap };
  }

  throw new HttpsError("permission-denied", "not_group_member");
}

function resolvePoolMode(data) {
  return data.poolMode === "annual" ? "annual" : "monthly";
}

function resolvePoolTarget(data, poolMode) {
  if (Number.isFinite(data.poolTarget)) {
    return Number(data.poolTarget);
  }
  return poolMode === "annual" ? ANNUAL_TARGET : MONTHLY_TARGET;
}

function computeSubscriptionDates(
  existingData,
  poolMode,
  periodCount = 1,
  today = istanbulStartOfDay()
) {
  const extensionDaysPerPeriod = poolMode === "annual" ? ANNUAL_DAYS : MONTHLY_DAYS;
  const totalExtensionDays = extensionDaysPerPeriod * Math.max(1, periodCount);
  const existingEnd = existingData.subscriptionEndDate?.toDate?.();
  let startDate = existingData.subscriptionStartDate?.toDate?.() || today;

  if (existingEnd) {
    const existingEndDay = istanbulStartOfDay(existingEnd);
    const base = existingEndDay >= today ? existingEndDay : today;
    return {
      startDate,
      endDate: addDays(base, totalExtensionDays),
    };
  }

  return {
    startDate: today,
    endDate: addDays(today, totalExtensionDays),
  };
}

function applyPoolCredit(groupData, poolMode, totalCollected) {
  const poolTarget = resolvePoolTarget(groupData, poolMode);
  const fullPeriods = Math.floor(totalCollected / poolTarget);
  const remainder = totalCollected % poolTarget;

  if (fullPeriods <= 0) {
    return {
      activated: false,
      poolCollected: totalCollected,
      subscriptionStartDate: null,
      subscriptionEndDate: null,
    };
  }

  const dates = computeSubscriptionDates(groupData, poolMode, fullPeriods);
  return {
    activated: true,
    poolCollected: remainder,
    subscriptionStartDate: dates.startDate,
    subscriptionEndDate: dates.endDate,
  };
}

async function recordPoolIAP(request) {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "auth_required");
  }

  const groupId = String(request.data?.groupId || "").trim();
  const productId = String(request.data?.productId || "").trim();
  const transactionId = String(request.data?.transactionId || "").trim();
  const contributionAmount = allowedContributionAmount(productId);

  if (!groupId || !productId || !transactionId || !contributionAmount) {
    throw new HttpsError("invalid-argument", "invalid_pool_payment_payload");
  }

  const db = getFirestore();
  const uid = request.auth.uid;
  const { groupRef, groupSnap } = await assertGroupMember(db, groupId, uid);
  const txRef = groupRef.collection("poolIAPTransactions").doc(transactionId);

  return db.runTransaction(async (tx) => {
    const [existingTx, freshGroup] = await Promise.all([
      tx.get(txRef),
      tx.get(groupRef),
    ]);

    if (existingTx.exists) {
      const groupData = freshGroup.data() || {};
      return {
        success: true,
        duplicate: true,
        poolCollected: groupData.poolCollected || 0,
        poolTarget: resolvePoolTarget(groupData, resolvePoolMode(groupData)),
      };
    }

    const groupData = freshGroup.data() || {};
    const poolMode = resolvePoolMode(groupData);
    const poolTarget = resolvePoolTarget(groupData, poolMode);
    const poolCollected = (groupData.poolCollected || 0) + contributionAmount;

    const updates = {
      poolCollected,
      poolMode,
      poolTarget,
      poolUpdatedAt: FieldValue.serverTimestamp(),
    };

    const credit = applyPoolCredit(groupData, poolMode, poolCollected);
    updates.poolCollected = credit.poolCollected;

    let activated = credit.activated;
    if (credit.activated) {
      updates.subscriptionStartDate = Timestamp.fromDate(credit.subscriptionStartDate);
      updates.subscriptionEndDate = Timestamp.fromDate(credit.subscriptionEndDate);
      updates.subscriptionUpdatedAt = FieldValue.serverTimestamp();
    }

    tx.set(groupRef, updates, { merge: true });
    tx.set(txRef, {
      uid,
      productId,
      contributionAmount,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      activated,
      poolCollected: updates.poolCollected,
      poolTarget,
      subscriptionEndDate: updates.subscriptionEndDate || groupData.subscriptionEndDate || null,
    };
  });
}

module.exports = {
  recordPoolIAP,
};
