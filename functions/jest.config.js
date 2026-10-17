/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/test'],
  testTimeout: 30000,
  moduleNameMapper: { '^jose$': '<rootDir>/test/stubs/jose.js' },
};
