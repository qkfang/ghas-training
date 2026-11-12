const express = require('express');
const { initDb } = require('./db');
const auth = require('./auth');
const products = require('./routes/products');
const files = require('./routes/files');
const admin = require('./routes/admin');
const reports = require('./routes/reports');
const orders = require('./routes/orders');
const reviews = require('./routes/reviews');
const account = require('./routes/account');
const integrations = require('./routes/integrations');

const app = express();
app.use(express.json());

app.post('/login', auth.login);
app.use('/products', products);
app.use('/files', files);
app.use('/reports', reports);
app.use('/orders', orders);
app.use('/reviews', reviews);
app.use('/account', account);
app.use('/integrations', integrations);
app.use('/admin', auth.requireAdmin, admin);

const port = process.env.PORT || 3000;

initDb().then(() => {
  app.listen(port, () => console.log(`acme-shop-demo listening on ${port}`));
});

module.exports = app;
