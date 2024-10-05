const { getPlatformDetails, getLinuxDistro } = require('../utils/platform');
const { downloadPHP } = require('../utils/download');
const { extractPHP } = require('../utils/extract');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Install a specific PHP version.
 *
 * @param {string} version - The PHP version to install.
 */
async function installPHP(version) {
  try {
    // Step 1: Get platform details
    const platform = getPlatformDetails();

    // Step 2: Check for required package managers or dependencies
    if (platform.includes('macos')) {
      ensureMacOSPackageManager();
    } else if (platform === 'linux') {
      ensureLinuxDependencies();
    } else if (platform === 'windows') {
      console.log('Windows installation is not supported yet.\n');
      return;
    }

    // Step 3: Try downloading the PHP tarball for the given platform
    try {
      console.log(
        `Attempting to download PHP ${version} for platform: ${platform}...\n`,
      );
      const tarballPath = await downloadPHP(version, platform);

      // Step 4: Extract the downloaded tarball
      console.log(`Extracting PHP ${version}...\n`);
      await extractPHP(tarballPath, version);

      // Step 5: Verify the installation
      verifyPHPInstallation(version);

      console.log(`PHP ${version} has been successfully installed!\n`);
    } catch (error) {
      console.log(
        `Failed to download PHP ${version}. Attempting installation via package manager...\n`,
      );
      handlePackageManagerInstall(version, platform);
    }
  } catch (error) {
    console.error(`Failed to install PHP ${version}: ${error.message}\n`);
  }
}

/**
 * Fallback to platform-specific package manager to install PHP.
 *
 * @param {string} version - The PHP version to install.
 * @param {string} platform - The platform details (e.g., 'macos-apple-silicon').
 */
function handlePackageManagerInstall(version, platform) {
  if (platform.includes('macos')) {
    // macOS uses Homebrew to install PHP
    try {
      console.log(`Installing PHP ${version} via Homebrew...\n`);
      execSync(`brew install php@${version}`, { stdio: 'inherit' });
      console.log(`PHP ${version} installed via Homebrew.`);
    } catch (error) {
      throw new Error(`Failed to install PHP ${version} via Homebrew.`);
    }
  } else if (platform === 'linux') {
    // Linux distribution: Use apt (Ubuntu/Debian) or dnf (Fedora)
    const distro = getLinuxDistro();
    if (distro === 'ubuntu' || distro === 'debian') {
      try {
        console.log(`Installing PHP ${version} via apt...\n`);
        execSync(
          `sudo apt-get update && sudo apt-get install -y php${version}`,
          { stdio: 'inherit' },
        );
        console.log(`PHP ${version} installed via apt.`);
      } catch (error) {
        throw new Error(`Failed to install PHP ${version} via apt.`);
      }
    } else if (distro === 'fedora') {
      try {
        console.log('Installing PHP via dnf...\n');
        execSync('sudo dnf install -y php', { stdio: 'inherit' });
        console.log('PHP installed via dnf.');
      } catch (error) {
        throw new Error('Failed to install PHP via dnf.');
      }
    } else {
      throw new Error('Unsupported Linux distribution or package manager.');
    }
  } else {
    throw new Error('Unsupported platform or package manager.');
  }
}

/**
 * Ensure necessary package managers are available on macOS.
 */
function ensureMacOSPackageManager() {
  try {
    execSync('command -v brew', { stdio: 'ignore' });
    console.log('Homebrew detected on macOS.\n');
  } catch (error) {
    throw new Error(
      'Homebrew is not installed. Please install it from https://brew.sh and try again.',
    );
  }
}

/**
 * Ensure necessary dependencies for Linux distributions.
 */
function ensureLinuxDependencies() {
  const distro = getLinuxDistro();
  console.log(`Detected Linux distribution: ${distro}\n`);

  if (distro === 'ubuntu' || distro === 'debian') {
    installIfMissing(
      'apt-get',
      'sudo apt-get update && sudo apt-get install -y build-essential libxml2-dev',
    );
  } else if (distro === 'fedora') {
    installIfMissing(
      'dnf',
      'sudo dnf install -y @development-tools libxml2-devel',
    );
  } else {
    throw new Error(
      'Unsupported Linux distribution or missing package manager.',
    );
  }
}

/**
 * Check if a package manager command is available, and if not, prompt to install dependencies.
 *
 * @param {string} command - The package manager command to check (e.g., apt-get, dnf).
 * @param {string} installCommand - The command to install required dependencies.
 */
function installIfMissing(command, installCommand) {
  try {
    execSync(`command -v ${command}`, { stdio: 'ignore' });
    console.log(`${command} detected. Installing necessary dependencies...\n`);
    execSync(installCommand, { stdio: 'inherit' });
  } catch (error) {
    throw new Error(
      `${command} is not available. Please install it or use a compatible Linux distribution.`,
    );
  }
}

/**
 * Verify PHP installation by running "php -v" in the installed version's bin folder.
 *
 * @param {string} version - The PHP version to verify.
 */
function verifyPHPInstallation(version) {
  const phpPath = path.resolve(
    process.env.HOME,
    '.phpvm',
    'versions',
    version,
    'bin',
    'php',
  );

  if (fs.existsSync(phpPath)) {
    const result = execSync(`${phpPath} -v`).toString();
    console.log(`PHP ${version} installed and verified:\n${result}`);
  } else {
    throw new Error(
      `PHP ${version} installation failed. PHP binary not found.`,
    );
  }
}

module.exports = { installPHP };
