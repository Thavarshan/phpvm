const fs = require('fs');
const path = require('path');

/**
 * Uninstall a specific PHP version.
 * @param {string} version - The PHP version to uninstall.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function uninstallPHP(version, program) {
  const versionDir = path.resolve(
    process.env.HOME,
    '.phpvm',
    'versions',
    version,
  );

  try {
    // Step 1: Check if the version is currently active (optional improvement)
    const activeVersion = getActivePHPVersion();
    if (activeVersion === version) {
      program.error(
        `PHP ${version} is currently in use. Please switch to another version before uninstalling.\n`,
      );
      return;
    }

    // Step 2: Check if the version is installed
    if (fs.existsSync(versionDir)) {
      // Step 3: Remove the directory recursively
      fs.rmSync(versionDir, { recursive: true, force: true });
      console.log(`PHP ${version} has been successfully uninstalled.\n`);

      // Optional: Cleanup any additional files related to the version
      cleanupAdditionalFiles(version, program);
    } else {
      console.log(`PHP ${version} is not installed.\n`);
    }
  } catch (error) {
    program.error(`Failed to uninstall PHP ${version}: ${error.message}\n`);
  }
}

/**
 * Get the currently active PHP version.
 * This is an optional function to prevent uninstallation of active PHP versions.
 * @returns {string|null} The currently active PHP version or null if none is active.
 */
function getActivePHPVersion() {
  const phpVersionFile = path.resolve(
    process.env.HOME,
    '.phpvm',
    'active_version',
  );
  if (fs.existsSync(phpVersionFile)) {
    return fs.readFileSync(phpVersionFile, 'utf8').trim();
  }
  return null;
}

/**
 * Cleanup additional files related to the uninstalled PHP version.
 * This can include removing symlinks, configuration files, etc.
 * @param {string} version - The PHP version being uninstalled.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function cleanupAdditionalFiles(version, program) {
  // Example: remove symlinks or config files related to the PHP version
  const phpSymlink = path.resolve('/usr/local/bin', `php-${version}`);
  if (fs.existsSync(phpSymlink)) {
    fs.unlinkSync(phpSymlink);
    console.log(`Removed symlink for PHP ${version} from /usr/local/bin.\n`);
  }

  // Add more cleanup tasks as needed
}

module.exports = { uninstallPHP };
