const acmePaymentsApiKey = process.env.ACME_API_KEY;

if (!acmePaymentsApiKey) {
  throw new Error('ACME_API_KEY environment variable is required');
}

module.exports = {
  acmePaymentsApiKey,
  acmePaymentsUrl: 'https://payments.acme.example/v1',
};
