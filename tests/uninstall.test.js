const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const {
  uninstallPHP,
  getActivePHPVersion,
  uninstallFromHomebrew,
  uninstallFromLinux,
} = require('../lib/commands/uninstall');
const { getPlatformDetails } = require('../lib/utils/platform');

jest.mock('fs');
jest.mock('path');
jest.mock('child_process');
jest.mock('../lib/utils/platform');
jest.mock('../lib/commands/uninstall', () => ({
  ...jest.requireActual('../lib/commands/uninstall'),
  getActivePHPVersion: jest.fn(),
}));

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

  it('should not uninstall the active PHP version', () => {
    getActivePHPVersion.mockReturnValue('7.4.10');
    uninstallPHP('7.4.10', program);
    expect(program.error).toHaveBeenCalledWith(
      'PHP 7.4.10 is currently in use. Please switch to another version before uninstalling.\n',
    );
  });

  it('should uninstall a PHP version installed by phpvm', () => {
    getActivePHPVersion.mockReturnValue(null);
    fs.existsSync.mockReturnValue(true);
    path.resolve.mockReturnValue('/home/user/.phpvm/versions/7.4.10');

    uninstallPHP('7.4.10', program);

    expect(fs.rmSync).toHaveBeenCalledWith(
      '/home/user/.phpvm/versions/7.4.10',
      { recursive: true, force: true },
    );
    expect(console.log).toHaveBeenCalledWith(
      'PHP 7.4.10 has been successfully uninstalled from phpvm.\n',
    );
  });

  it('should handle uninstallation via Homebrew on macOS', () => {
    getActivePHPVersion.mockReturnValue(null);
    fs.existsSync.mockReturnValue(false);
    getPlatformDetails.mockReturnValue('macos');

    uninstallPHP('7.4.10', program);

    expect(execSync).toHaveBeenCalledWith('brew uninstall php@7.4.10', {
      stdio: 'inherit',
    });
    expect(console.log).toHaveBeenCalledWith(
      'Uninstalling PHP 7.4.10 via Homebrew...\n',
    );
  });

  it('should handle uninstallation via apt on Ubuntu', () => {
    getActivePHPVersion.mockReturnValue(null);
    fs.existsSync.mockReturnValue(false);
    getPlatformDetails.mockReturnValue('linux');
    jest.spyOn(global, 'getLinuxDistro').mockReturnValue('ubuntu');

    uninstallPHP('7.4.10', program);

    expect(execSync).toHaveBeenCalledWith('sudo apt-get remove -y php7.4.10', {
      stdio: 'inherit',
    });
    expect(console.log).toHaveBeenCalledWith(
      'Uninstalling PHP 7.4.10 via apt...\n',
    );
  });

  it('should handle unsupported platforms', () => {
    getActivePHPVersion.mockReturnValue(null);
    fs.existsSync.mockReturnValue(false);
    getPlatformDetails.mockReturnValue('unsupported');

    uninstallPHP('7.4.10', program);

    expect(program.error).toHaveBeenCalledWith(
      'Unsupported platform: unsupported. Cannot uninstall PHP 7.4.10.\n',
    );
  });

  it('should handle errors during uninstallation', () => {
    getActivePHPVersion.mockReturnValue(null);
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
