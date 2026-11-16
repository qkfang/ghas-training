// DEMO SECRET (secret scanning example): fake credentials in the format of supported provider patterns
// (Slack bot token, Stripe live key). They are not real, but are meant to trigger secret scanning alerts
// (and push protection, which may require a bypass to push). Owner: team-platform.
module.exports = {
  slackBotToken: '1111-123456789012-1234567890123-AbCdEfGhIjKlMnOpQrStUvWx',
  stripeSecretKey: 'sk_live_4eC39HqLyjWDarjtT1zdp7dc',
  slackChannel: '#alerts',
};
