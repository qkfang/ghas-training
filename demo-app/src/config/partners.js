const acmeLogisticsApiKey = process.env.ACME_LOGISTICS_API_KEY;

if (!acmeLogisticsApiKey) {
  throw new Error('ACME_LOGISTICS_API_KEY environment variable is required');
}

module.exports = {
  partners: [
    { name: 'acme-logistics', apiKey: acmeLogisticsApiKey, baseUrl: 'https://logistics.acme.example' },
  ],
};
