const ACME_KEY = process.env.ACME_API_KEY;

if (!ACME_KEY) {
  throw new Error('ACME_API_KEY environment variable is required');
}

console.log('Backfilling orders with configured ACME key…');
