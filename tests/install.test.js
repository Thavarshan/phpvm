// Move mocks to the top of the file, before imports

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

// Now import the install function after mocks
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
    jest.clearAllMocks();
    console.log = jest.fn();
    console.error = jest.fn();
  });

  it('should install PHP on macOS (Apple Silicon) using Homebrew', async () => {
    getPlatformDetails.mockReturnValue('macos-apple-silicon'); // Mock Apple Silicon
    downloadPHP.mockResolvedValue(tarballPath);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10/bin/php');
    fs.existsSync.mockReturnValue(true);

    execSync.mockImplementation((command) => {
      if (command.includes('brew install')) return; // Simulate successful brew install
      throw new Error('Command failed');
    });

    console.log('Running macOS (Apple Silicon) test...'); // Debug log

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalled(); // Check if downloadPHP was called
    expect(execSync).toHaveBeenCalledWith('command -v brew', {
      stdio: 'ignore',
    });
    expect(execSync).toHaveBeenCalledWith('brew install php@7.4.10', {
      stdio: 'inherit',
    });
  });

  it('should install PHP on macOS (Intel) using Homebrew', async () => {
    getPlatformDetails.mockReturnValue('macos-intel'); // Mock Intel-based macOS
    downloadPHP.mockResolvedValue(tarballPath);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10/bin/php');
    fs.existsSync.mockReturnValue(true);

    execSync.mockImplementation((command) => {
      if (command.includes('brew install')) return;
      throw new Error('Command failed');
    });

    console.log('Running macOS (Intel) test...'); // Debug log

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalled(); // Check if downloadPHP was called
    expect(execSync).toHaveBeenCalledWith('command -v brew', {
      stdio: 'ignore',
    });
    expect(execSync).toHaveBeenCalledWith('brew install php@7.4.10', {
      stdio: 'inherit',
    });
  });

  it('should install PHP on Linux using apt', async () => {
    getPlatformDetails.mockReturnValue('linux'); // Mock Linux
    getLinuxDistro.mockReturnValue('ubuntu'); // Simulate Ubuntu
    downloadPHP.mockResolvedValue(tarballPath);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10/bin/php');
    fs.existsSync.mockReturnValue(true);

    execSync.mockImplementation((command) => {
      if (command.includes('apt-get install')) return; // Simulate apt-get install
      throw new Error('Command failed');
    });

    console.log('Running Linux (apt) test...'); // Debug log

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(getLinuxDistro).toHaveBeenCalled(); // Confirm Linux distro detection
    expect(downloadPHP).toHaveBeenCalled(); // Check if downloadPHP was called
    expect(execSync).toHaveBeenCalledWith('command -v apt-get', {
      stdio: 'ignore',
    });
    expect(execSync).toHaveBeenCalledWith(
      'sudo apt-get update && sudo apt-get install -y php7.4.10',
      { stdio: 'inherit' },
    );
  });

  it('should handle unsupported platforms (Windows)', async () => {
    getPlatformDetails.mockReturnValue('windows'); // Mock Windows

    console.log('Running Windows unsupported test...'); // Debug log

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(console.log).toHaveBeenCalledWith(
      'Windows installation is not supported yet.\n',
    );
  });

  it('should handle download failure and fallback to package manager', async () => {
    getPlatformDetails.mockReturnValue('macos-apple-silicon'); // Simulate Apple Silicon
    downloadPHP.mockRejectedValue(new Error('Download failed')); // Simulate download failure

    execSync.mockImplementation((command) => {
      if (command.includes('brew install')) return; // Simulate brew install success
      throw new Error('Command failed');
    });

    console.log('Running download failure and fallback test...'); // Debug log

    await installPHP(version);

    expect(getPlatformDetails).toHaveBeenCalled();
    expect(downloadPHP).toHaveBeenCalled(); // Check if downloadPHP was called
    expect(console.log).toHaveBeenCalledWith(
      expect.stringContaining(
        'Failed to download PHP 7.4.10. Attempting installation via package manager',
      ),
    );
    expect(execSync).toHaveBeenCalledWith('brew install php@7.4.10', {
      stdio: 'inherit',
    });
  });

  it('should handle installation failure', async () => {
    getPlatformDetails.mockReturnValue('macos-apple-silicon');
    downloadPHP.mockResolvedValue(tarballPath);
    extractPHP.mockRejectedValue(new Error('Extraction failed')); // Simulate extraction failure

    console.log('Running installation failure test...'); // Debug log

    await installPHP(version);

    expect(downloadPHP).toHaveBeenCalled(); // Check if downloadPHP was called
    expect(extractPHP).toHaveBeenCalled(); // Check if extractPHP was called
    expect(console.error).toHaveBeenCalledWith(
      expect.stringContaining(
        'Failed to install PHP 7.4.10: Extraction failed',
      ),
    );
  });
});
