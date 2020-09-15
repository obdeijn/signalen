const merge = require('lodash.merge');
const fs = require('fs');

const [baseConfigPath, appConfigPath, destConfigPath] = process.argv.slice(2);

if (!baseConfigPath || !appConfigPath || !destConfigPath) {
  throw new Error('Arguments baseConfigPath, appConfigPath and destConfigPath are required.');
}

let baseConfig;
let appConfig;

try {
  baseConfig = JSON.parse(fs.readFileSync(baseConfigPath));
} catch {
  throw new Error('Argument baseConfigPath should be a valid path and point to a JSON file');
}

try {
  appConfig = JSON.parse(fs.readFileSync(appConfigPath));
} catch {
  throw new Error('Argument appConfig should be a valid path and point to a JSON file');
}

const mergedConfig = merge(baseConfig, appConfig);

try {
  fs.writeFileSync(destConfigPath, JSON.stringify(mergedConfig));
} catch {
  throw new Error('Argument destConfigPath should point to a writable file location');
}
