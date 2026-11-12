// DEMO SECRET: matches the custom secret scanning pattern "ACME API key" described in
// demo-app/README.md. The value is fake but is treated as a LIVE production key in the scenario.
module.exports = {
  acmePaymentsApiKey: process.env.ACME_API_KEY || 'acme_live_7Hq2LmP9xZ4vT6nR1sK8wB3d',
  acmePaymentsUrl: 'https://payments.acme.example/v1',
};
