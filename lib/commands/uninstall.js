const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { getPlatformDetails } = require('../utils/platform');

/**
 * Uninstall a specific PHP version.
 * @param {string} version - The PHP version to uninstall.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function uninstallPHP(version, program) {
  const platform = getPlatformDetails();
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

    // Step 2: Check if the version is installed by phpvm
    if (fs.existsSync(versionDir)) {
      // Step 3: Remove the directory recursively
      fs.rmSync(versionDir, { recursive: true, force: true });
      console.log(
        `PHP ${version} has been successfully uninstalled from phpvm.\n`,
      );

      // Optional: Cleanup any additional files related to the version
      cleanupAdditionalFiles(version, program);
    } else {
      // Step 4: Handle platform-specific uninstallations
      if (platform.includes('macos')) {
        uninstallFromHomebrew(version, program);
      } else if (platform === 'linux') {
        uninstallFromLinux(version, program);
      } else {
        program.error(
          `Unsupported platform: ${platform}. Cannot uninstall PHP ${version}.\n`,
        );
      }
    }
  } catch (error) {
    program.error(`Failed to uninstall PHP ${version}: ${error.message}\n`);
  }
}

/**
 * Handle uninstalling PHP via Homebrew (for macOS).
 *
 * @param {string} version - The PHP version to uninstall.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function uninstallFromHomebrew(version, program) {
  try {
    console.log(`Uninstalling PHP ${version} via Homebrew...\n`);
    execSync(`brew uninstall php@${version}`, { stdio: 'inherit' });
    console.log(
      `PHP ${version} has been successfully uninstalled via Homebrew.\n`,
    );
  } catch (error) {
    console.error(
      `Failed to uninstall PHP ${version} via Homebrew: ${error.message}\n`,
    );
  }
}

/**
 * Handle uninstalling PHP from Linux distributions.
 *
 * @param {string} version - The PHP version to uninstall.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function uninstallFromLinux(version, program) {
  const distro = getLinuxDistro();
  if (distro === 'ubuntu' || distro === 'debian') {
    try {
      console.log(`Uninstalling PHP ${version} via apt...\n`);
      execSync(`sudo apt-get remove -y php${version}`, { stdio: 'inherit' });
      console.log(
        `PHP ${version} has been successfully uninstalled via apt.\n`,
      );
    } catch (error) {
      console.error(
        `Failed to uninstall PHP ${version} via apt: ${error.message}\n`,
      );
    }
  } else if (distro === 'fedora') {
    try {
      console.log('Uninstalling PHP via dnf...\n');
      execSync('sudo dnf remove -y php', { stdio: 'inherit' });
      console.log('PHP has been successfully uninstalled via dnf.\n');
    } catch (error) {
      console.error('Failed to uninstall PHP via dnf.\n');
    }
  } else {
    program.error(
      `Unsupported Linux distribution: ${distro}. Cannot uninstall PHP ${version}.\n`,
    );
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
