#!/usr/bin/env node

const { Command } = require('commander');
const { installPHP } = require('./lib/commands/install');
const { uninstallPHP } = require('./lib/commands/uninstall');
const { listPHPVersions } = require('./lib/commands/list');
const { usePHPVersion } = require('./lib/commands/use');
const packageJson = require('./package.json');

// Initialize the command-line program
const program = new Command();

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
 *
 * Usage: phpvm install <version>
 * Example: phpvm install 7.4.10
 */
program
  .command('install <version>')
  .alias('i') // Alias for shorthand usage
  .description('Install a specific PHP version')
  .action((version) => installPHP(version, program)); // Pass the program instance to commands

/**
 * Command to uninstall a specific PHP version.
 *
 * Usage: phpvm uninstall <version>
 * Example: phpvm uninstall 7.4.10
 */
program
  .command('uninstall <version>')
  .alias('rm') // Alias for shorthand usage
  .description('Uninstall a specific PHP version')
  .action((version) => uninstallPHP(version, program)); // Pass the program instance to commands

/**
 * Command to list all installed PHP versions.
 *
 * Usage: phpvm list
 * Example: phpvm list
 */
program
  .command('list')
  .alias('ls') // Alias for shorthand usage
  .description('List installed PHP versions')
  .action(() => listPHPVersions(program)); // Pass the program instance to commands

/**
 * Command to switch to a specific PHP version.
 *
 * Usage: phpvm use <version>
 * Example: phpvm use 7.4.10
 */
program
  .command('use <version>')
  .alias('switch') // Optional alias for more descriptive usage
  .description('Switch to a specific PHP version')
  .action((version) => usePHPVersion(version, program)); // Pass the program instance to commands

/**
 * Command to simulate an error.
 *
 * Usage: phpvm error
 * Example: phpvm error
 */
program
  .command('error')
  .description('Simulate an error')
  .action(() => {
    console.logErr('Something went wrong!\n'); // Using custom output handler
    process.exit(1); // Exit with error code 1 to indicate failure
  });

/**
 * Global error handling in case of unhandled exceptions.
 */
program.on('command:*', (invalidCommand) => {
  console.logErr(`Invalid command: ${invalidCommand}\n`);
  program.outputHelp(); // Suggest available commands
  process.exit(1); // Exit with error code
});

/**
 * Parse the command-line arguments.
 */
program.parse(process.argv);
