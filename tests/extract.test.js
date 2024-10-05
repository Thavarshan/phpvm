const tar = require('tar');
const path = require('path');
const fs = require('fs');
const { extractPHP } = require('../lib/utils/extract');

jest.mock('tar');
jest.mock('fs');
jest.mock('path');

describe('extractPHP', () => {
  const tarballPath = '/path/to/php-7.4.10.tar.gz';
  const version = '7.4.10';
  const outputDir = '/path/to';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should extract the PHP tarball successfully', async () => {
    fs.existsSync.mockReturnValue(true);
    path.dirname.mockReturnValue(outputDir);
    tar.x.mockResolvedValue();

    console.log = jest.fn();

    await extractPHP(tarballPath, version);

    expect(fs.existsSync).toHaveBeenCalledWith(tarballPath);
    expect(path.dirname).toHaveBeenCalledWith(tarballPath);
    expect(tar.x).toHaveBeenCalledWith({
      file: tarballPath,
      cwd: outputDir,
    });
    expect(console.log).toHaveBeenCalledWith(
      `PHP ${version} extracted successfully.`,
    );
  });

  it('should throw an error if tarballPath is invalid', async () => {
    await expect(extractPHP(null, version)).rejects.toThrow(
      'Invalid tarballPath provided.',
    );
    await expect(extractPHP(123, version)).rejects.toThrow(
      'Invalid tarballPath provided.',
    );
  });

  it('should throw an error if version is invalid', async () => {
    await expect(extractPHP(tarballPath, null)).rejects.toThrow(
      'Invalid version provided.',
    );
    await expect(extractPHP(tarballPath, 123)).rejects.toThrow(
      'Invalid version provided.',
    );
  });

  it('should throw an error if tarball does not exist', async () => {
    fs.existsSync.mockReturnValue(false);

    await expect(extractPHP(tarballPath, version)).rejects.toThrow(
      `Tarball not found at path: ${tarballPath}`,
    );
  });

  it('should throw an error if extraction fails', async () => {
    fs.existsSync.mockReturnValue(true);
    path.dirname.mockReturnValue(outputDir);
    tar.x.mockRejectedValue(new Error('Extraction error'));

    await expect(extractPHP(tarballPath, version)).rejects.toThrow(
      'Error extracting PHP 7.4.10: Extraction error',
    );
  });
});
