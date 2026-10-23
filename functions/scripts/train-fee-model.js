// Trains the fee model on data/market_trips.csv and saves the model file
// src/models/fee_model.json (weights, accuracy, sources). The server imports
// it and the Flutter app bundles it as an asset, so both price with one file.
// Run from functions/: npm run train:fees
const fs = require('fs');
const path = require('path');
const { fitFeeModel, parseTrips, predictSen } = require('../lib/domain/fee_model');

const root = path.join(__dirname, '..');
const csv = fs.readFileSync(path.join(root, 'data', 'market_trips.csv'), 'utf8');
const trips = parseTrips(csv);
const sourceOf = csv.trim().split(/\r?\n/).slice(1).map((l) => l.split(',')[1]);
const urls = JSON.parse(fs.readFileSync(path.join(root, 'data', 'market_sources.json'), 'utf8'));

function train(kind) {
  const idx = trips.map((t, i) => i).filter((i) => trips[i].kind === kind);
  const samples = idx.map((i) => trips[i]);
  const weights = fitFeeModel(samples);
  const err = samples.map((t) => Math.abs(predictSen(weights, t) - t.costSen));
  const sources = [...new Set(idx.map((i) => sourceOf[i]))];
  return {
    weights,
    samples: samples.length,
    maeSen: Math.round(err.reduce((a, b) => a + b, 0) / err.length),
    sources: Object.fromEntries(sources.map((s) => [s, urls[s] ?? []])),
  };
}

const model = {
  name: 'careway-fee-model',
  type: 'linear-regression',
  target: 'trip cost in sen',
  features: ['intercept', 'km', 'km in the peaks (7-10 AM, 5-8 PM)', 'km at night (10 PM-6 AM)'],
  timezone: 'UTC+8',
  trainedOn: 'data/market_trips.csv',
  trainedAt: new Date().toISOString().slice(0, 10),
  models: { ride: train('ride'), delivery: train('delivery') },
};
fs.mkdirSync(path.join(root, 'src', 'models'), { recursive: true });
fs.writeFileSync(path.join(root, 'src', 'models', 'fee_model.json'), JSON.stringify(model, null, 2) + '\n');

for (const k of ['ride', 'delivery']) console.log(k, model.models[k].weights, `MAE RM ${(model.models[k].maeSen / 100).toFixed(2)}`);
