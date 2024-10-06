const fs = require('fs');
const path = require('path');
const { installPHP } = require('./install');
const { usePHPVersion } = require('./use');

/**
 * Look for a .phpvmrc file recursively upwards from the current directory.
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
 * Read and return the PHP version from the .phpvmrc file.
 */
function getPHPVersionFromRCFile(rcFilePath) {
  if (!fs.existsSync(rcFilePath)) {
    throw new Error(`File not found: ${rcFilePath}`);
  }
  return fs.readFileSync(rcFilePath, 'utf8').trim();
}

/**
 * Auto-detect and switch PHP version based on .phpvmrc.
 */
async function autoSwitchPHPVersion() {
  const phpvmrcPath = findPHPVMRCFile();

  if (phpvmrcPath) {
    const version = getPHPVersionFromRCFile(phpvmrcPath);
    console.log(`Found .phpvmrc file. PHP version specified: ${version}`);

    try {
      // Check if PHP version is installed
      if (!isPHPVersionInstalled(version)) {
        console.log(`PHP version ${version} is not installed. Installing...`);
        await installPHP(version); // Use your existing installPHP function
      }

      // Switch to the desired version
      usePHPVersion(version); // Use your existing function to switch PHP versions
      console.log(`Switched to PHP ${version}`);
    } catch (error) {
      console.error(`Error while switching PHP version: ${error.message}`);
    }
  } else {
    console.log(
      'No .phpvmrc file found in this directory or any parent directory.',
    );
  }
}

/**
 * Helper function to check if the PHP version is installed.
 */
function isPHPVersionInstalled(version) {
  const homeDir = process.env.HOME || process.env.USERPROFILE;
  if (!homeDir) {
    throw new Error('HOME environment variable is not set.');
  }
  const versionDir = path.join(homeDir, '.phpvm', 'versions', version);
  return fs.existsSync(versionDir);
}

module.exports = { autoSwitchPHPVersion };
