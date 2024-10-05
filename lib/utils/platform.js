const os = require('os');
const fs = require('fs');
const path = require('path');

// Define constants for supported platforms
const MACOS_APPLE_SILICON = 'macos-apple-silicon';
const MACOS_INTEL = 'macos-intel';
const LINUX = 'linux';
const WINDOWS = 'windows';

/**
 * Sets the platform details for testing.
 *
 * @param {string} platform - The platform to set.
 * @param {string} architecture - The architecture to set.
 * @returns {void}
 */
function setPlatformDetails(platform, architecture) {
  os.platform = jest.fn(() => platform);
  os.arch = jest.fn(() => architecture);
}

/**
 * Retrieves the platform details.
 *
 * @param {string} [forcedPlatform] - Optional parameter to force a specific platform for testing.
 * @returns {string} A string representing the platform details.
 *                   Possible values are:
 *                   - 'macos-apple-silicon' for macOS on Apple Silicon
 *                   - 'macos-intel' for macOS on Intel
 *                   - 'linux' for Linux platforms
 *                   - 'windows' for Windows platforms
 *                   - 'unsupported' for unsupported platforms
 */
function getPlatformDetails(forcedPlatform) {
  if (forcedPlatform) {
    return forcedPlatform;
  }

  // Get the platform (e.g., 'darwin', 'linux', 'win32')
  const platform = os.platform();
  // Get the CPU architecture (e.g., 'arm64', 'x64')
  const architecture = os.arch();

  // Determine the platform details based on the platform and architecture
  switch (platform) {
    case 'darwin':
      // Return 'macos-apple-silicon' for Apple Silicon, 'macos-intel' for Intel
      return architecture === 'arm64' ? MACOS_APPLE_SILICON : MACOS_INTEL;
    case 'linux':
      // Return 'linux' for Linux platforms
      return LINUX;
    case 'win32':
      // Return 'windows' for Windows platforms
      return WINDOWS;
    default:
      // Throw an error for unsupported platforms with detailed information
      throw new Error(
        `Unsupported platform: ${platform} with architecture: ${architecture}`,
      );
  }
}

/**
 * Retrieves the Linux distribution details.
 *
 * @param {string} [forcedDistro] - Optional parameter to force a specific distribution for testing.
 * @returns {string} A string representing the Linux distribution.
 *                   Possible values are:
 *                   - 'ubuntu' for Ubuntu
 *                   - 'fedora' for Fedora
 *                   - 'debian' for Debian
 *                   - 'centos' for CentOS
 *                   - 'arch' for Arch Linux
 *                   - 'unknown' for unknown distributions
 */
function getLinuxDistro(forcedDistro) {
  if (forcedDistro) {
    return forcedDistro;
  }

  const osReleasePath = '/etc/os-release';
  if (fs.existsSync(osReleasePath)) {
    const osReleaseContent = fs.readFileSync(osReleasePath, 'utf8');
    const idMatch = osReleaseContent.match(/^ID=(.*)$/m);
    if (idMatch) {
      return idMatch[1].replace(/"/g, '');
    }
  }
  return 'unknown';
}

module.exports = { getPlatformDetails, getLinuxDistro, setPlatformDetails };
