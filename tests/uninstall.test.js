const fs = require('fs');
const path = require('path');
const { Command } = require('commander');
const { getPlatformDetails } = require('../lib/utils/platform');
const {
  uninstallPHP,
  getActivePHPVersion,
  uninstallFromHomebrew,
  uninstallFromLinux,
} = require('../lib/commands/uninstall');

jest.mock('fs');
jest.mock('path');
jest.mock('../lib/utils/platform');
jest.mock('../lib/utils/phpvmrc');
jest.mock('../lib/commands/uninstall');

describe.skip('uninstallPHP', () => {
  let program;

  beforeEach(() => {
    program = new Command();
    jest.clearAllMocks();
  });

  test('returns early if version is invalid', () => {
    try {
      uninstallPHP(null, program);
    } catch (error) {
      fail(error.message);
    }
  });

  test('returns early if version is currently active', () => {
    getActivePHPVersion.mockReturnValue('7.4.10');
    uninstallPHP('7.4.10', program);
  });

  test('removes directory if version is installed by phpvm', () => {
    getActivePHPVersion.mockReturnValue('7.3.0');
    getPlatformDetails.mockReturnValue('macos');
    fs.existsSync = jest.fn();
    fs.existsSync.mockReturnValue(true);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10');

    // Ensure fs.rmSync is mocked
    fs.rmSync = jest.fn();

    uninstallPHP('7.4.10', program);
    expect(fs.rmSync).toHaveBeenCalledWith('/path/to/.phpvm/versions/7.4.10', {
      recursive: true,
      force: true,
    });
  });

  test('calls uninstallFromHomebrew if version is not installed by phpvm on macOS', () => {
    getActivePHPVersion.mockReturnValue('7.3.0');
    getPlatformDetails.mockReturnValue('macos');
    fs.existsSync.mockReturnValue(false);

    uninstallPHP('7.4.10', program);
    expect(uninstallFromHomebrew).toHaveBeenCalledWith('7.4.10', program);
  });

  test('calls uninstallFromLinux if version is not installed by phpvm on Linux', () => {
    getActivePHPVersion.mockReturnValue('7.3.0');
    getPlatformDetails.mockReturnValue('linux');
    fs.existsSync.mockReturnValue(false);

    uninstallPHP('7.4.10', program);
    expect(uninstallFromLinux).toHaveBeenCalledWith('7.4.10', program);
  });

  test('handles errors during uninstallation', () => {
    getActivePHPVersion.mockReturnValue('7.3.0');
    getPlatformDetails.mockReturnValue('macos');
    fs.existsSync.mockReturnValue(true);
    path.resolve.mockReturnValue('/path/to/.phpvm/versions/7.4.10');
    fs.rmSync.mockImplementation(() => {
      throw new Error('Failed to remove directory');
    });

    uninstallPHP('7.4.10', program);
    expect(program.error).toHaveBeenCalledWith(
      expect.stringContaining('Failed to uninstall PHP 7.4.10'),
    );
  });
});
