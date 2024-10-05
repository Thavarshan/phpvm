const os = require('os');

// Define constants for supported platforms
const MACOS_APPLE_SILICON = 'macos-apple-silicon';
const MACOS_INTEL = 'macos-intel';
const LINUX = 'linux';
const WINDOWS = 'windows';

/**
 * Retrieves the platform details of the current operating system.
 *
 * @returns {string} A string representing the platform details.
 *                   Possible values are:
 *                   - 'macos-apple-silicon' for macOS on Apple Silicon
 *                   - 'macos-intel' for macOS on Intel
 *                   - 'linux' for Linux
 *                   - 'windows' for Windows
 * @throws {Error} If the platform is unsupported.
 */
function getPlatformDetails() {
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

module.exports = { getPlatformDetails };
