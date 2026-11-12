// Dev-only backfill script. DEMO SECRET (Session 3 secret campaign): a fake "live" ACME API key pasted
// into a script "just for a one-off run" - a very common real-world leak. Owner: team-checkout.
const ACME_KEY = 'acme_live_Pz7Hd2Ks9Lw4Qa6Vn1Ct8Xe3';

console.log(`Backfilling orders with key ${ACME_KEY.slice(0, 10)}…`);
