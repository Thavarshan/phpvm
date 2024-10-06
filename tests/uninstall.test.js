// Mock utilities and dependencies at the top
jest.mock('fs');
jest.mock('path');
jest.mock('child_process');
jest.mock('../lib/utils/platform');
jest.mock('../lib/commands/uninstall', () => ({
  ...jest.requireActual('../lib/commands/uninstall'),
  getActivePHPVersion: jest.fn(), // Correctly mock this function
}));

// Import necessary functions
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { uninstallPHP } = require('../lib/commands/uninstall');
const { getPlatformDetails } = require('../lib/utils/platform');
const { getActivePHPVersion } = require('../lib/commands/uninstall'); // Make sure it's imported correctly

describe('uninstallPHP', () => {
  let program;

  beforeEach(() => {
    program = { error: jest.fn() };
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  test('should not uninstall the active PHP version', () => {
    getActivePHPVersion.mockReturnValue('7.4.10'); // Correctly mock the return value

    uninstallPHP('7.4.10', program);

    expect(program.error).toHaveBeenCalledWith(
      'PHP 7.4.10 is currently in use. Please switch to another version before uninstalling.\n',
    );
  });

  test('should uninstall a PHP version installed by phpvm', () => {
    getActivePHPVersion.mockReturnValue(null);
    fs.existsSync.mockReturnValue(true);
    path.resolve.mockReturnValue('/home/user/.phpvm/versions/7.4.10');

    uninstallPHP('7.4.10', program);

    expect(fs.rmSync).toHaveBeenCalledWith(
      '/home/user/.phpvm/versions/7.4.10',
      { recursive: true, force: true },
    );
  });

  test.each([
    [
      'macos',
      'brew uninstall php@7.4.10',
      'Uninstalling PHP 7.4.10 via Homebrew...\n',
    ],
    [
      'linux',
      'sudo apt-get remove -y php7.4.10',
      'Uninstalling PHP 7.4.10 via apt...\n',
    ],
  ])(
    'should uninstall PHP on %s platform',
    async (platform, uninstallCmd, logMessage) => {
      getActivePHPVersion.mockReturnValue(null); // Correctly mock the return value
      fs.existsSync.mockReturnValue(false);
      getPlatformDetails.mockReturnValue(platform);

      uninstallPHP('7.4.10', program);

      expect(execSync).toHaveBeenCalledWith(uninstallCmd, { stdio: 'inherit' });
      expect(console.log).toHaveBeenCalledWith(logMessage);
    },
  );

  test('should handle unsupported platforms', () => {
    getActivePHPVersion.mockReturnValue(null); // Correctly mock the return value
    fs.existsSync.mockReturnValue(false);
    getPlatformDetails.mockReturnValue('unsupported');

    uninstallPHP('7.4.10', program);

    expect(program.error).toHaveBeenCalledWith(
      'Unsupported platform: unsupported. Cannot uninstall PHP 7.4.10.\n',
    );
  });

  test('should handle errors during uninstallation', () => {
    getActivePHPVersion.mockReturnValue(null); // Correctly mock the return value
    fs.existsSync.mockReturnValue(true);
    path.resolve.mockReturnValue('/home/user/.phpvm/versions/7.4.10');
    fs.rmSync.mockImplementation(() => {
      throw new Error('Test error');
    });

    uninstallPHP('7.4.10', program);

    expect(program.error).toHaveBeenCalledWith(
      'Failed to uninstall PHP 7.4.10: Test error\n',
    );
  });
});
