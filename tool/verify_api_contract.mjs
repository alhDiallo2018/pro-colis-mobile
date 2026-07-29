#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const toolDirectory = path.dirname(fileURLToPath(import.meta.url));
const mobileRoot = path.resolve(toolDirectory, '..');
const apiRoot = path.resolve(
  process.env.PROCOLIS_API_DIR || path.join(mobileRoot, '../../Web/ProColis-Api'),
);

function walk(directory, predicate, output = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (
      ['.dart_tool', '.git', 'build', 'node_modules'].includes(entry.name) ||
      entry.name.startsWith('Procolis Design ')
    ) {
      continue;
    }
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      walk(entryPath, predicate, output);
    } else if (predicate(entryPath)) {
      output.push(entryPath);
    }
  }
  return output;
}

function normalizeRoute(route) {
  return (
    route
      .replace(/^https?:\/\/[^/]+/, '')
      .replace(/\$\{[^}]+\}|\$[A-Za-z_]\w*/g, ':param')
      .replace(/:[^/]+/g, ':param')
      .replace(/\?.*$/, '')
      .replace(/\/+/g, '/')
      .replace(/\/$/, '') || '/'
  );
}

function contract(method, route) {
  return `${method.toUpperCase()} ${normalizeRoute(route)}`;
}

if (!fs.existsSync(path.join(apiRoot, 'src/app.js'))) {
  console.error(
    `API ProColis introuvable dans ${apiRoot}. ` +
      'Définissez PROCOLIS_API_DIR vers le dépôt backend.',
  );
  process.exit(2);
}

// Les préfixes sont ceux montés dans src/app.js. Le nom du Router constitue
// une clé plus stable que le chemin du fichier, notamment pour les deux routers
// de notifications qui partagent le même module.
const routerPrefixes = new Map([
  ['healthRouter', '/health'],
  ['authRouter', '/auth'],
  ['garageRouter', '/public/garages'],
  ['notificationRouter', '/notifications'],
  ['adminNotificationRouter', '/admin/notifications'],
  ['uploadRouter', '/upload'],
  ['zoneRouter', ''],
  ['supportRouter', ''],
  ['mobileRouter', ''],
]);

const backendContracts = new Set();
const routerCallPattern =
  /(\w+Router)\.(get|post|put|patch|delete)\(\s*(['"])(.*?)\3/gs;

for (const file of walk(path.join(apiRoot, 'src'), (item) =>
  item.endsWith('.routes.js'),
)) {
  const source = fs.readFileSync(file, 'utf8');
  let match;
  while ((match = routerCallPattern.exec(source)) !== null) {
    const [, routerName, method, , route] = match;
    const prefix = routerPrefixes.get(routerName);
    if (prefix === undefined) continue;
    backendContracts.add(contract(method, `${prefix}/${route}`));
  }
}

const mobileContracts = new Map();
const directCallPattern =
  /(?:_dio|client\.dio|\bdio)\.(get|post|put|patch|delete)\(\s*(['"])(.*?)\2/gs;

for (const file of walk(path.join(mobileRoot, 'lib'), (item) =>
  item.endsWith('.dart'),
)) {
  const source = fs.readFileSync(file, 'utf8');
  let match;
  while ((match = directCallPattern.exec(source)) !== null) {
    const [, method, , route] = match;
    if (/^https?:/.test(route)) continue;
    const key = contract(method, route);
    mobileContracts.set(key, path.relative(mobileRoot, file));
  }
}

// Ces appels passent par des wrappers typés (`_load`, `_get`, `_send`) ou par
// des endpoints calculés depuis le rôle. Ils ne sont donc pas visibles dans le
// motif des appels Dio directs, mais font pleinement partie du contrat mobile.
const indirectContracts = [
  ['GET', '/users/stats'],
  ['GET', '/client/bids/stats'],
  ['GET', '/driver/stats'],
  ['GET', '/garage-admin/stats'],
  ['GET', '/super-admin/stats'],
  ['GET', '/advertisements/stats'],
  ['GET', '/support-technique/stats'],
  ['GET', '/support-technique/tickets'],
  ['PATCH', '/support-technique/tickets/:ticketId'],
  ['GET', '/support-technique/incidents'],
  ['POST', '/support-technique/incidents'],
  ['PATCH', '/support-technique/incidents/:incidentId'],
  ['GET', '/support-commercial/stats'],
  ['GET', '/support-commercial/leads'],
  ['PATCH', '/support-commercial/leads/:leadId'],
  ['GET', '/support-commercial/coverage'],
];

for (const scope of [
  'client',
  'driver',
  'garage-admin',
  'support-technique',
  'support-commercial',
  'super-admin',
]) {
  indirectContracts.push(['PUT', `/${scope}/profile`]);
  indirectContracts.push(['GET', `/${scope}/parcels/:parcelId`]);
}

for (const step of [
  'confirm',
  'pickup',
  'transit',
  'arrived',
  'out-for-delivery',
  'deliver',
]) {
  indirectContracts.push(['PUT', `/driver/parcels/:parcelId/${step}`]);
}

// Remplace le patron dynamique générique de `advanceParcel` par ses six valeurs
// autorisées ci-dessus : aucune autre étape ne doit être considérée valide.
mobileContracts.delete('PUT /driver/parcels/:param/:param');
for (const [method, route] of indirectContracts) {
  mobileContracts.set(contract(method, route), 'contrat indirect typé');
}

const missing = [...mobileContracts.entries()]
  .filter(([key]) => !backendContracts.has(key))
  .map(([key, source]) => ({ contract: key, source }));

if (missing.length > 0) {
  console.error('Contrats mobiles sans route API correspondante :');
  for (const item of missing) {
    console.error(`- ${item.contract} (${item.source})`);
  }
  process.exit(1);
}

console.log(
  `Contrat API OK : ${mobileContracts.size} appels mobiles couverts par ` +
    `${backendContracts.size} routes backend.`,
);
