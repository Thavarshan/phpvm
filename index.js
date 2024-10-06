#!/usr/bin/env node

const { program } = require('commander');
const { installPHP } = require('./lib/commands/install');
const { uninstallPHP } = require('./lib/commands/uninstall');
const { listPHPVersions } = require('./lib/commands/list');
const { usePHPVersion } = require('./lib/commands/use');
const { autoSwitchPHPVersion } = require('./lib/commands/phpvmrc');
const packageJson = require('./package.json');

autoSwitchPHPVersion(); // Auto-switch PHP version based on .phpvmrc

/**
 * Configure the output for the program.
 */
program.configureOutput({
  writeOut: (str) => process.stdout.write(str),
  writeErr: (str) => process.stderr.write(str),
  outputError: (str) => process.stderr.write(`Error: ${str}`), // More descriptive error output
});

/**
 * Set the program name, description, and version.
 */
program
  .name(packageJson.name)
  .description(packageJson.description)
  .version(packageJson.version);

/**
 * Command to install a specific PHP version.
 */
program
  .command('install <version>')
  .alias('i')
  .description('Install a specific PHP version')
  .action((version) => installPHP(version));

/**
 * Command to uninstall a specific PHP version.
 */
program
  .command('uninstall <version>')
  .alias('rm')
  .description('Uninstall a specific PHP version')
  .action((version) => uninstallPHP(version, program));

/**
 * Command to list all installed PHP versions.
 */
program
  .command('list')
  .alias('ls')
  .description('List installed PHP versions')
  .action(() => listPHPVersions(program));

/**
 * Command to switch to a specific PHP version.
 */
program
  .command('use <version>')
  .alias('switch')
  .description('Switch to a specific PHP version')
  .action((version) => {
    try {
      usePHPVersion(version, program);
      console.log(`Switched to PHP ${version}`);
    } catch (err) {
      console.error(`Failed to switch PHP version: ${err.message}`);
      process.exit(1); // Exit with an error code on failure
    }
  });

/**
 * Command to simulate an error.
 */
program
  .command('error')
  .description('Simulate an error')
  .action(() => {
    process.stderr.write('Something went wrong!\n');
    process.exit(1); // Exit with error code 1 to indicate failure
  });

/**
 * Global error handling for invalid commands.
 */
program.on('command:*', (invalidCommand) => {
  process.stderr.write(`Invalid command: ${invalidCommand.join(' ')}\n`);
  program.outputHelp(); // Suggest available commands
  process.exit(1); // Exit with error code
});

/**
 * Parse the command-line arguments.
 */
program.parse(process.argv);
