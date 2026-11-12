const sqlite3 = require('sqlite3');

const db = new sqlite3.Database(':memory:');

function initDb() {
  return new Promise((resolve, reject) => {
    db.serialize(() => {
      db.run('CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price REAL)');
      db.run('CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, role TEXT)');
      db.run('CREATE TABLE orders (id INTEGER PRIMARY KEY, product_id INTEGER, qty INTEGER, status TEXT)');
      db.run('CREATE TABLE reviews (id INTEGER PRIMARY KEY, product_id INTEGER, rating INTEGER, body TEXT)');
      db.run("INSERT INTO orders (product_id, qty, status) VALUES (1, 2, 'shipped'), (2, 1, 'pending')");
      db.run("INSERT INTO products (name, price) VALUES ('Widget', 9.99), ('Gadget', 19.99)");
      db.run("INSERT INTO users (username, role) VALUES ('alice', 'admin')", (err) =>
        err ? reject(err) : resolve()
      );
    });
  });
}

module.exports = { db, initDb };
