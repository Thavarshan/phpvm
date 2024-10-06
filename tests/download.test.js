const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');
const { downloadPHP } = require('../lib/utils/download');

jest.mock('fs');
jest.mock('node-fetch');

describe('downloadPHP', () => {
  const version = '7.4.10';
  const platform = 'macos-intel';
  const baseUrl = 'https://www.php.net/distributions';
  const phpUrl = `${baseUrl}/php-${version}-darwin-x86_64.tar.gz`;
  const outputDir = path.resolve(
    process.env.HOME,
    '.phpvm',
    'versions',
    version,
  );
  const tarballPath = path.join(outputDir, `php-${version}.tar.gz`);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('should download PHP binary for the specified version and platform', async () => {
    fetch.mockResolvedValue({
      ok: true,
      body: {
        pipe: jest.fn(),
      },
    });

    fs.createWriteStream.mockReturnValue({
      on: jest.fn((event, callback) => {
        if (event === 'finish') {
          callback();
        }
      }),
    });

    fs.mkdirSync.mockImplementation(() => {});

    const result = await downloadPHP(version, platform);

    expect(result).toBe(tarballPath);
    expect(fetch).toHaveBeenCalledWith(phpUrl);
    expect(fs.mkdirSync).toHaveBeenCalledWith(outputDir, { recursive: true });
    expect(fs.createWriteStream).toHaveBeenCalledWith(tarballPath);
  });

  test('should throw an error if the platform is unsupported', async () => {
    const unsupportedPlatform = 'unsupported-platform';

    await expect(downloadPHP(version, unsupportedPlatform)).rejects.toThrow(
      `No download URL available for platform: ${unsupportedPlatform}. Consider using a package manager.`,
    );
  });

  test('should throw an error if the PHP binary is not available', async () => {
    fetch.mockResolvedValue({
      ok: false,
    });

    await expect(downloadPHP(version, platform)).rejects.toThrow(
      `PHP binary for platform "${platform}" and version "${version}" is not available at ${phpUrl}.`,
    );
  });

  test('should throw an error if the download fails', async () => {
    fetch.mockResolvedValue({
      ok: true,
      body: {
        pipe: jest.fn(),
      },
    });

    fs.createWriteStream.mockReturnValue({
      on: jest.fn((event, callback) => {
        if (event === 'error') {
          callback(new Error('Download error'));
        }
      }),
    });

    fs.mkdirSync.mockImplementation(() => {});
    fs.unlinkSync.mockImplementation(() => {});

    await expect(downloadPHP(version, platform)).rejects.toThrow(
      'Download error',
    );

    expect(fs.unlinkSync).toHaveBeenCalledWith(tarballPath);
  });
});
