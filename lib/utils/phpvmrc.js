const fs = require('fs');
const path = require('path');
const { usePHPVersion } = require('../commands/use');

/**
 * Find the .phpvmrc file in the current directory or any parent directory
 *
 * @param {string} startDir The directory to start searching from
 * @returns {string|null} The path to the .phpvmrc file or null if not found
 */
function findPHPVMRCFile(startDir = process.cwd()) {
  let currentDir = startDir;

  while (currentDir !== '/') {
    const phpvmrcPath = path.join(currentDir, '.phpvmrc');
    if (fs.existsSync(phpvmrcPath)) {
      return phpvmrcPath;
    }
    currentDir = path.resolve(currentDir, '..');
  }

  return null;
}

/**
 * Automatically switch to the PHP version specified in the .phpvmrc file
 *
 * This function is meant to be called when the shell is started.
 * It remains silent if no .phpvmrc file is found.
 */
async function autoSwitchPHPVersion() {
  const phpvmrcPath = findPHPVMRCFile();

  if (phpvmrcPath) {
    const version = fs.readFileSync(phpvmrcPath, 'utf8').trim();

    // Switch to the specified version
    try {
      await usePHPVersion(version); // Use the existing 'use' command logic
      console.log(`Switched to PHP ${version}`);
    } catch (error) {
      console.error(`Failed to switch to PHP ${version}: ${error.message}`);
    }
  } else {
    // Silent if no .phpvmrc file is found
    return;
  }
}

module.exports = { findPHPVMRCFile, autoSwitchPHPVersion };
