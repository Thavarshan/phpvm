const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');

/**
 * Download PHP binary for the specified version and platform.
 *
 * @param {string} version - The PHP version to download.
 * @param {string} platform - The platform details (e.g., 'macos-apple-silicon').
 * @returns {Promise<string>} The path to the downloaded tarball.
 * @throws {Error} If the download fails or the platform is unsupported.
 */
async function downloadPHP(version, platform) {
  const baseUrl =
    process.env.PHP_BASE_URL || 'https://www.php.net/distributions';

  // Refined URLs based on actual availability on the PHP distribution site
  const urls = {
    'macos-intel': `${baseUrl}/php-${version}-darwin-x86_64.tar.gz`,
    linux: `${baseUrl}/php-${version}-linux.tar.gz`, // This URL may need customization for each Linux distro
  };

  // Check if we have a valid URL for the given platform
  const phpUrl = urls[platform];
  if (!phpUrl) {
    throw new Error(
      `No download URL available for platform: ${platform}. Consider using a package manager.`,
    );
  }

  // Validate the URL before proceeding with download
  const binaryExists = await checkURLExists(phpUrl);
  if (!binaryExists) {
    throw new Error(
      `PHP binary for platform "${platform}" and version "${version}" is not available at ${phpUrl}.`,
    );
  }

  const outputDir = path.resolve(
    process.env.HOME,
    '.phpvm',
    'versions',
    version,
  );
  const tarballPath = path.join(outputDir, `php-${version}.tar.gz`);

  // Create the output directory if it doesn't exist
  fs.mkdirSync(outputDir, { recursive: true });

  // Download the tarball
  console.log(`Downloading PHP ${version} from ${phpUrl}...\n`);
  const response = await fetch(phpUrl);
  if (!response.ok) {
    throw new Error(`Failed to download PHP version ${version} from ${phpUrl}`);
  }

  const fileStream = fs.createWriteStream(tarballPath);
  response.body.pipe(fileStream);

  return new Promise((resolve, reject) => {
    fileStream.on('finish', () => resolve(tarballPath));
    fileStream.on('error', (err) => {
      fs.unlinkSync(tarballPath); // Clean up the incomplete file
      reject(err);
    });
  });
}

/**
 * Check if a URL exists by performing a HEAD request.
 *
 * @param {string} url - The URL to check.
 * @returns {Promise<boolean>} True if the URL exists, false otherwise.
 */
async function checkURLExists(url) {
  try {
    const response = await fetch(url, { method: 'HEAD' });
    return response.ok;
  } catch (error) {
    return false;
  }
}

module.exports = { downloadPHP };
