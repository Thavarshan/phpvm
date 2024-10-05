const { installPHP } = require('../lib/commands/install');
const { getPlatformDetails, getLinuxDistro } = require('../lib/utils/platform');
const { downloadPHP } = require('../lib/utils/download');
const { extractPHP } = require('../lib/utils/extract');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

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

describe.skip('installPHP', () => {
  const version = '7.4.10';
  const tarballPath = '/path/to/php-7.4.10.tar.gz';
  const platform = 'macos-apple-silicon';
  const distro = 'ubuntu';

  beforeEach(() => {
    jest.clearAllMocks();
    console.log = jest.fn();
    console.error = jest.fn();
  });

  it('should install PHP on macOS using Homebrew', async () => {
    getPlatformDetails.mockReturnValue(platform);
    downloadPHP.mockResolvedValue(tarballPath);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10/bin/php');
    fs.existsSync.mockReturnValue(true);
    execSync.mockImplementation((command) => {
      if (command.includes('brew install')) {
        return;
      }
      throw new Error('Command failed');
    });

    await installPHP(version);

    console.log('getPlatformDetails calls:', getPlatformDetails.mock.calls);
    console.log('downloadPHP calls:', downloadPHP.mock.calls);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalledWith(version, platform);
    expect(extractPHP).toHaveBeenCalledWith(tarballPath, version);
    expect(execSync).toHaveBeenCalledWith('command -v brew', {
      stdio: 'ignore',
    });
    expect(execSync).toHaveBeenCalledWith('brew install php@7.4.10', {
      stdio: 'inherit',
    });
    expect(execSync).toHaveBeenCalledWith(
      '/path/to/.phpvm/versions/7.4.10/bin/php -v',
    );
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining('PHP 7.4.10 installed and verified'),
    );
  });

  it('should install PHP on Linux using apt', async () => {
    getPlatformDetails.mockReturnValue('linux');
    getLinuxDistro.mockReturnValue(distro);
    downloadPHP.mockResolvedValue(tarballPath);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10/bin/php');
    fs.existsSync.mockReturnValue(true);
    execSync.mockImplementation((command) => {
      if (command.includes('apt-get install')) {
        return;
      }
      throw new Error('Command failed');
    });

    await installPHP(version);

    console.log('getPlatformDetails calls:', getPlatformDetails.mock.calls);
    console.log('downloadPHP calls:', downloadPHP.mock.calls);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(getLinuxDistro).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalledWith(version, 'linux');
    expect(extractPHP).toHaveBeenCalledWith(tarballPath, version);
    expect(execSync).toHaveBeenCalledWith('command -v apt-get', {
      stdio: 'ignore',
    });
    expect(execSync).toHaveBeenCalledWith(
      'sudo apt-get update && sudo apt-get install -y build-essential libxml2-dev',
      { stdio: 'inherit' },
    );
    expect(execSync).toHaveBeenCalledWith(
      'sudo apt-get update && sudo apt-get install -y php7.4.10',
      { stdio: 'inherit' },
    );
    expect(execSync).toHaveBeenCalledWith(
      '/path/to/.phpvm/versions/7.4.10/bin/php -v',
    );
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining('PHP 7.4.10 installed and verified'),
    );
  });

  it('should handle unsupported platforms', async () => {
    getPlatformDetails.mockReturnValue('windows');

    await installPHP(version);

    console.log('getPlatformDetails calls:', getPlatformDetails.mock.calls);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(console.log).toHaveBeenCalledWith(
      'Windows installation is not supported yet.\n',
    );
  });

  it('should handle download failure and fallback to package manager', async () => {
    getPlatformDetails.mockReturnValue(platform);
    downloadPHP.mockRejectedValue(new Error('Download failed'));
    execSync.mockImplementation((command) => {
      if (command.includes('brew install')) {
        return;
      }
      throw new Error('Command failed');
    });

    await installPHP(version);

    console.log('getPlatformDetails calls:', getPlatformDetails.mock.calls);
    console.log('downloadPHP calls:', downloadPHP.mock.calls);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalledWith(version, platform);
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining(
        'Failed to download PHP 7.4.10. Attempting installation via package manager',
      ),
    );
    expect(execSync).toHaveBeenCalledWith('brew install php@7.4.10', {
      stdio: 'inherit',
    });
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining('PHP 7.4.10 installed via Homebrew'),
    );
  });

  it('should handle installation failure', async () => {
    getPlatformDetails.mockReturnValue(platform);
    downloadPHP.mockResolvedValue(tarballPath);
    extractPHP.mockRejectedValue(new Error('Extraction failed'));

    await installPHP(version);

    console.log('getPlatformDetails calls:', getPlatformDetails.mock.calls);
    console.log('downloadPHP calls:', downloadPHP.mock.calls);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalledWith(version, platform);
    expect(extractPHP).toHaveBeenCalledWith(tarballPath, version);
    expect(console.error).toHaveBeenCalledWith(
      expect.stringContaining(
        'Failed to install PHP 7.4.10: Extraction failed',
      ),
    );
  });
});
