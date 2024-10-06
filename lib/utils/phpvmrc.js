const fs = require('fs');
const path = require('path');
const { usePHPVersion } = require('../commands/use');

// Look for a .phpvmrc file recursively upwards from the current directory
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

// Auto-detect and switch PHP version based on .phpvmrc
async function autoSwitchPHPVersion() {
  const phpvmrcPath = findPHPVMRCFile();

  if (phpvmrcPath) {
    const version = fs.readFileSync(phpvmrcPath, 'utf8').trim();
    console.log(`Found .phpvmrc file. PHP version specified: ${version}`);

    // Switch to the specified version
    try {
      await usePHPVersion(version); // Use your existing 'use' command logic
      console.log(`Switched to PHP ${version}`);
    } catch (error) {
      console.error(`Failed to switch to PHP ${version}: ${error.message}`);
    }
  } else {
    console.log(
      'No .phpvmrc file found in this directory or any parent directory.',
    );
  }
}

module.exports = { findPHPVMRCFile, autoSwitchPHPVersion };
