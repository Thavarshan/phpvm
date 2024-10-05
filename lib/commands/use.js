const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { getPlatformDetails, getLinuxDistro } = require('../utils/platform');

/**
 * Use a specific PHP version.
 *
 * @param {string} version - The PHP version to switch to.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function usePHPVersion(version, program) {
  const platform = getPlatformDetails();
  const versionDir = path.resolve(
    process.env.HOME,
    '.phpvm',
    'versions',
    version,
  );

  try {
    if (fs.existsSync(versionDir)) {
      console.log(`Switching to PHP ${version} installed by phpvm...\n`);
      setPHPVersion(versionDir, version, program);
    } else {
      handlePlatformSpecificInstallations(platform, version, program);
    }
  } catch (error) {
    program.error(`Failed to switch to PHP ${version}: ${error.message}\n`);
  }
}

/**
 * Handle platform-specific PHP installations.
 *
 * @param {string} platform - The platform details.
 * @param {string} version - The PHP version to switch to.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function handlePlatformSpecificInstallations(platform, version, program) {
  // console.log(platform);

  if (platform.includes('macos')) {
    useHomebrewPHP(version, program);
  } else if (platform === 'linux') {
    useLinuxPHP(version, program);
  } else {
    program.error(
      `Unsupported platform: ${platform}. Cannot switch to PHP ${version}.\n`,
    );
  }
}

/**
 * Switch to a Homebrew-managed PHP version (macOS).
 *
 * @param {string} version - The PHP version to switch to.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function useHomebrewPHP(version, program) {
  try {
    const brewPrefix = execSync('brew --prefix').toString().trim();
    const brewPHPPath = path.resolve(
      `${brewPrefix}/opt/php@${version}/bin/php`,
    );

    if (fs.existsSync(brewPHPPath)) {
      console.log(`Switching to PHP ${version} via Homebrew...\n`);
      unlinkCurrentPHPVersion();
      linkNewPHPVersion(version);
      setPHPVersion(brewPHPPath, version, program);
    } else {
      throw new Error(`PHP ${version} is not installed via Homebrew.`);
    }
  } catch (error) {
    program.error(
      `Failed to switch to PHP ${version} via Homebrew: ${error.message}\n`,
    );
  }
}

/**
 * Unlink the current PHP version managed by Homebrew.
 */
function unlinkCurrentPHPVersion() {
  try {
    console.log('Unlinking any currently linked PHP version via Homebrew...\n');
    execSync('brew unlink php', { stdio: 'inherit' });
  } catch (unlinkError) {
    console.warn(
      'No currently linked PHP version found via Homebrew, continuing...\n',
    );
  }
}

/**
 * Link the new PHP version managed by Homebrew.
 *
 * @param {string} version - The PHP version to link.
 */
function linkNewPHPVersion(version) {
  console.log(`Linking PHP ${version} via Homebrew...\n`);
  execSync(`brew link php@${version}`, { stdio: 'inherit' });
}

/**
 * Switch to a Linux-installed PHP version via package manager (apt/dnf).
 *
 * @param {string} version - The PHP version to switch to.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function useLinuxPHP(version, program) {
  const distro = getLinuxDistro();
  try {
    if (distro === 'ubuntu' || distro === 'debian') {
      switchPHPVersionOnLinux(version, program, 'apt', 'apt-get');
    } else if (distro === 'fedora') {
      switchPHPVersionOnLinux(version, program, 'dnf', 'dnf');
    } else {
      program.error(
        `Unsupported Linux distribution: ${distro}. Cannot switch to PHP ${version}.\n`,
      );
    }
  } catch (error) {
    program.error(`Failed to switch to PHP ${version}: ${error.message}\n`);
  }
}

/**
 * Switch to a PHP version on Linux using the specified package manager.
 *
 * @param {string} version - The PHP version to switch to.
 * @param {Command} program - The Commander.js program instance to use for output.
 * @param {string} packageManager - The package manager to use (e.g., 'apt', 'dnf').
 * @param {string} installCommand - The install command to use (e.g., 'apt-get', 'dnf').
 */
function switchPHPVersionOnLinux(
  version,
  program,
  packageManager,
  installCommand,
) {
  const phpPath = `/usr/bin/php${version}`;
  if (fs.existsSync(phpPath)) {
    console.log(`Switching to PHP ${version} via ${packageManager}...\n`);
    setPHPVersion(phpPath, version, program);
  } else {
    program.error(
      `PHP ${version} is not installed via ${packageManager}. Install with: sudo ${installCommand} install php${version}\n`,
    );
  }
}

/**
 * Activate a PHP version by setting up the environment in the user's home directory.
 * This avoids permission issues by not requiring superuser privileges.
 *
 * @param {string} phpPath - The path to the PHP binary.
 * @param {string} version - The PHP version being switched to.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function setPHPVersion(phpPath, version, program) {
  try {
    updateActiveVersionFile(version);
    createSymlink(phpPath);
    console.log(
      `PHP ${version} is now the active version. Use 'php -v' to verify.\n`,
    );
    suggestAddingLocalBinToPath();
  } catch (error) {
    program.error(`Failed to activate PHP ${version}: ${error.message}\n`);
  }
}

/**
 * Update the active PHP version file.
 *
 * @param {string} version - The PHP version to set as active.
 */
function updateActiveVersionFile(version) {
  const phpVersionFile = path.resolve(
    process.env.HOME,
    '.phpvm',
    'active_version',
  );
  fs.writeFileSync(phpVersionFile, version);
}

/**
 * Create a symlink to the PHP binary in the user's home directory.
 *
 * @param {string} phpPath - The path to the PHP binary.
 */
function createSymlink(phpPath) {
  const localBinDir = path.resolve(process.env.HOME, '.local', 'bin');
  const symlinkPath = path.join(localBinDir, 'php');

  if (!fs.existsSync(localBinDir)) {
    fs.mkdirSync(localBinDir, { recursive: true });
  }

  if (fs.existsSync(symlinkPath)) {
    const currentLinkDest = fs.readlinkSync(symlinkPath);
    if (currentLinkDest !== phpPath) {
      fs.unlinkSync(symlinkPath); // Remove the existing symlink if different
    }
  }

  fs.symlinkSync(phpPath, symlinkPath);
}

/**
 * Suggest adding $HOME/.local/bin to the user's PATH if not already present.
 */
function suggestAddingLocalBinToPath() {
  console.log(
    // eslint-disable-next-line quotes
    "Make sure that $HOME/.local/bin is in your PATH if you haven't added it already.\n",
  );
  if (!isLocalBinInPath()) {
    console.log(
      'It looks like $HOME/.local/bin is not in your PATH.\nYou can add it by including the following in your shell configuration:\n\nexport PATH="$HOME/.local/bin:$PATH"\n',
    );
  }
}

/**
 * Check if $HOME/.local/bin is in the user's PATH.
 *
 * @returns {boolean} True if it's already in PATH, false otherwise.
 */
function isLocalBinInPath() {
  const localBinDir = path.resolve(process.env.HOME, '.local', 'bin');
  return process.env.PATH.split(path.delimiter).includes(localBinDir);
}

/**
 * Get the currently active PHP version.
 * This is an optional function to prevent switching to an already active version.
 *
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

module.exports = {
  usePHPVersion,
  useHomebrewPHP,
  useLinuxPHP,
  setPHPVersion,
  getActivePHPVersion,
  isLocalBinInPath,
};
