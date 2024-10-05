const os = require('os');
const fs = require('fs');
const { getPlatformDetails, getLinuxDistro } = require('../lib/utils/platform');

jest.mock('os');
jest.mock('fs');

describe('getPlatformDetails', () => {
  it('should return macos-apple-silicon for macOS on Apple Silicon', () => {
    os.platform.mockReturnValue('darwin');
    os.arch.mockReturnValue('arm64');

    const platformDetails = getPlatformDetails();
    expect(platformDetails).toBe('macos-apple-silicon');
  });

  it('should return macos-intel for macOS on Intel', () => {
    os.platform.mockReturnValue('darwin');
    os.arch.mockReturnValue('x64');

    const platformDetails = getPlatformDetails();
    expect(platformDetails).toBe('macos-intel');
  });

  it('should return linux for Linux platforms', () => {
    os.platform.mockReturnValue('linux');
    os.arch.mockReturnValue('x64');

    const platformDetails = getPlatformDetails();
    expect(platformDetails).toBe('linux');
  });

  it('should return windows for Windows platforms', () => {
    os.platform.mockReturnValue('win32');
    os.arch.mockReturnValue('x64');

    const platformDetails = getPlatformDetails();
    expect(platformDetails).toBe('windows');
  });

  it('should throw an error for unsupported platforms', () => {
    os.platform.mockReturnValue('unsupported');
    os.arch.mockReturnValue('x64');

    expect(() => getPlatformDetails()).toThrow(
      'Unsupported platform: unsupported with architecture: x64',
    );
  });
});

describe('getLinuxDistro', () => {
  it('should return the forced Linux distribution if provided', () => {
    const forcedDistro = 'ubuntu';
    const distro = getLinuxDistro(forcedDistro);
    expect(distro).toBe(forcedDistro);
  });

  it('should return the correct Linux distribution from /etc/os-release', () => {
    const osReleaseContent = 'ID=ubuntu\nNAME="Ubuntu"\nVERSION="20.04 LTS"';
    fs.existsSync.mockReturnValue(true);
    fs.readFileSync.mockReturnValue(osReleaseContent);

    const distro = getLinuxDistro();
    expect(distro).toBe('ubuntu');
  });

  it('should return "unknown" if /etc/os-release does not exist', () => {
    fs.existsSync.mockReturnValue(false);

    const distro = getLinuxDistro();
    expect(distro).toBe('unknown');
  });

  it('should return "unknown" if ID is not found in /etc/os-release', () => {
    const osReleaseContent = 'NAME="Unknown OS"\nVERSION="1.0"';
    fs.existsSync.mockReturnValue(true);
    fs.readFileSync.mockReturnValue(osReleaseContent);

    const distro = getLinuxDistro();
    expect(distro).toBe('unknown');
  });
});
