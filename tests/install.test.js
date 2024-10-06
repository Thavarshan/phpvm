// Mock utilities and dependencies at the top
jest.mock('../lib/utils/platform', () => ({
  getPlatformDetails: jest.fn(),
  getLinuxDistro: jest.fn(),
}));

jest.mock('../lib/utils/download', () => ({
  downloadPHP: jest.fn(),
}));

jest.mock('../lib/utils/extract', () => ({
  extractPHP: jest.fn(),
}));

jest.mock('child_process', () => ({
  execSync: jest.fn(),
}));

jest.mock('fs', () => ({
  existsSync: jest.fn(),
}));

jest.mock('path', () => ({
  resolve: jest.fn(),
}));

// Import necessary functions
const { installPHP } = require('../lib/commands/install');
const { getPlatformDetails, getLinuxDistro } = require('../lib/utils/platform');
const { downloadPHP } = require('../lib/utils/download');
const { extractPHP } = require('../lib/utils/extract');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

describe('installPHP', () => {
  const version = '7.4.10';
  const tarballPath = '/path/to/php-7.4.10.tar.gz';

  beforeEach(() => {
    jest.clearAllMocks(); // Reset mocks before each test
    console.log = jest.fn();
    console.error = jest.fn();
  });

  test.each([
    ['macos-apple-silicon', 'brew install php@7.4.10'],
    ['macos-intel', 'brew install php@7.4.10'],
  ])(
    'should install PHP on %s using Homebrew',
    async (platform, brewInstallCmd) => {
      getPlatformDetails.mockReturnValue(platform);
      downloadPHP.mockResolvedValue(tarballPath);
      path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10/bin/php');
      fs.existsSync.mockReturnValue(true);

      await installPHP(version);

      expect(getPlatformDetails).toHaveBeenCalled();
      expect(downloadPHP).toHaveBeenCalled();
      expect(execSync).toHaveBeenCalledWith('command -v brew', {
        stdio: 'ignore',
      });
      expect(execSync).toHaveBeenCalledWith(brewInstallCmd, {
        stdio: 'inherit',
      });
    },
  );

  test('should install PHP on Linux using apt', async () => {
    getPlatformDetails.mockReturnValue('linux');
    getLinuxDistro.mockReturnValue('ubuntu');
    downloadPHP.mockResolvedValue(tarballPath);
    fs.existsSync.mockReturnValue(true);

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(getLinuxDistro).toHaveBeenCalled();
    expect(execSync).toHaveBeenCalledWith('command -v apt-get', {
      stdio: 'ignore',
    });
    expect(execSync).toHaveBeenCalledWith(
      'sudo apt-get update && sudo apt-get install -y php7.4.10',
      { stdio: 'inherit' },
    );
  });

  test('should handle unsupported platforms like Windows', async () => {
    getPlatformDetails.mockReturnValue('windows');

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(console.log).toHaveBeenCalledWith(
      'Windows installation is not supported yet.\n',
    );
  });

  test('should fallback to package manager on download failure', async () => {
    getPlatformDetails.mockReturnValue('macos-apple-silicon');
    downloadPHP.mockRejectedValue(new Error('Download failed'));

    await installPHP(version);

    expect(downloadPHP).toHaveBeenCalled();
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining(
        'Failed to download PHP 7.4.10. Attempting installation via package manager',
      ),
    );
    expect(execSync).toHaveBeenCalledWith('brew install php@7.4.10', {
      stdio: 'inherit',
    });
  });

  test('should handle installation failure due to extraction error', async () => {
    getPlatformDetails.mockReturnValue('macos-apple-silicon');
    downloadPHP.mockResolvedValue(tarballPath);
    extractPHP.mockRejectedValue(new Error('Extraction failed'));

    await installPHP(version);

    expect(downloadPHP).toHaveBeenCalled();
    expect(extractPHP).toHaveBeenCalled();
    expect(console.error).toHaveBeenCalledWith(
      expect.stringContaining(
        'Failed to install PHP 7.4.10: Extraction failed',
      ),
    );
  });
});
