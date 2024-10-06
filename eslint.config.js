const js = require('@eslint/js');
const globals = require('globals');
const pluginPrettier = require('eslint-plugin-prettier');
const configPrettier = require('eslint-config-prettier');
const pluginJest = require('eslint-plugin-jest');

module.exports = [
  {
    files: ['**/*.js'], // Apply these rules to all .js files
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module', // Enable ES6 modules
      globals: {
        ...globals.node, // Node.js global variables
      },
    },
    plugins: {
      jest: pluginJest,
      prettier: pluginPrettier, // Add Prettier as a plugin
    },
    rules: {
      'no-console': 'off', // Allow console.log for CLI
      'no-var': 'error', // Enforce let/const over var
      'prefer-const': 'error', // Suggest const where possible
      quotes: ['error', 'single'], // Enforce single quotes
      semi: ['error', 'always'], // Enforce semicolons
      eqeqeq: 'error', // Enforce strict equality
      'prettier/prettier': 'error', // Run Prettier as an ESLint rule
    },
  },
  {
    files: ['tests/**/*.js'], // Apply these rules specifically to test files
    languageOptions: {
      globals: {
        ...globals.jest, // Jest global variables
      },
    },
    rules: {
      'no-unused-expressions': 'off', // Allow unused expressions in tests (e.g., expect())
    },
  },
];
