const tar = require('tar');
const path = require('path');
const fs = require('fs');

/**
 * Extracts the downloaded PHP tarball.
 *
 * @param {string} tarballPath - The path to the tarball.
 * @param {string} version - The PHP version.
 * @throws {Error} If the extraction fails or the input parameters are invalid.
 */
async function extractPHP(tarballPath, version) {
  if (!tarballPath || typeof tarballPath !== 'string') {
    throw new Error('Invalid tarballPath provided.');
  }

  if (!version || typeof version !== 'string') {
    throw new Error('Invalid version provided.');
  }

  if (!fs.existsSync(tarballPath)) {
    throw new Error(`Tarball not found at path: ${tarballPath}`);
  }

  const outputDir = path.dirname(tarballPath);

  try {
    await tar.x({
      file: tarballPath,
      cwd: outputDir,
    });
    console.log(`PHP ${version} extracted successfully.`);
  } catch (err) {
    throw new Error(`Error extracting PHP ${version}: ${err.message}`);
  }
}

module.exports = { extractPHP };
