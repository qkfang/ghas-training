// Dev-time CLI helper. Uses minimist to parse arguments - relevant when triaging the
// minimist prototype-pollution Dependabot alert (only trusted local CLI input reaches it).
const argv = require('minimist')(process.argv.slice(2));

const count = Number(argv.products || 10);
console.log(`Would seed ${count} products`);
