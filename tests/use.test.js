const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const {
  usePHPVersion,
  useHomebrewPHP,
  useLinuxPHP,
  setPHPVersion,
  getActivePHPVersion,
  isLocalBinInPath,
} = require('../lib/commands/use');
const {
  getPlatformDetails,
  getLinuxDistro,
  setPlatformDetails,
} = require('../lib/utils/platform');

jest.mock('fs');
jest.mock('path');
jest.mock('child_process');
jest.mock('../lib/utils/platform');

describe('usePHPVersion', () => {
  const program = {
    error: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    console.log = jest.fn();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('should switch to PHP version installed by phpvm', () => {
    const version = '7.4.10';
    const versionDir = '/home/user/.phpvm/versions/7.4.10';
    getPlatformDetails.mockReturnValue('macos-apple-silicon');
    path.resolve.mockReturnValue(versionDir);
    fs.existsSync.mockReturnValue(true);

    usePHPVersion(version, program);

    expect(fs.existsSync).toHaveBeenCalledWith(versionDir);
    expect(console.log).toHaveBeenCalledWith(
      `Switching to PHP ${version} installed by phpvm...\n`,
    );
  });

  it('should switch to Homebrew-managed PHP version on macOS', () => {
    const version = '7.4.10';
    const brewPrefix = '/usr/local';
    const brewPHPPath = `${brewPrefix}/opt/php@${version}/bin/php`;
    getPlatformDetails.mockReturnValue('macos-apple-silicon');
    execSync.mockReturnValue(brewPrefix);
    path.resolve.mockReturnValue(brewPHPPath);
    fs.existsSync.mockReturnValueOnce(false).mockReturnValueOnce(true);

    usePHPVersion(version, program);

    expect(execSync).toHaveBeenCalledWith('brew --prefix');
    expect(fs.existsSync).toHaveBeenCalledWith(brewPHPPath);
    expect(console.log).toHaveBeenCalledWith(
      `Switching to PHP ${version} via Homebrew...\n`,
    );
  });

  it('should switch to apt-managed PHP version on Linux', () => {
    const version = '7.4';
    const aptPHPPath = `/usr/bin/php${version}`;
    getPlatformDetails.mockReturnValue('linux');
    path.resolve.mockReturnValue('/home/user/.phpvm/versions/7.4');
    fs.existsSync.mockReturnValueOnce(false).mockReturnValueOnce(true);

    usePHPVersion(version, program);

    expect(fs.existsSync).toHaveBeenCalledWith(aptPHPPath);
    expect(console.log).toHaveBeenCalledWith(
      `Switching to PHP ${version} via apt...\n`,
    );
  });

  it('should handle unsupported platforms', () => {
    jest.clearAllMocks();
    const version = '7.4.10';
    setPlatformDetails('unsupported', 'unsupported');
    // getPlatformDetails.mockReturnValue('unsupported');
    path.resolve.mockReturnValue('/home/user/.phpvm/versions/7.4.10');
    fs.existsSync.mockReturnValue(false);

    usePHPVersion(version, program);

    expect(program.error).toHaveBeenCalledWith(
      `Unsupported platform: unsupported. Cannot switch to PHP ${version}.\n`,
    );
  });

  it('should handle errors during switching', () => {
    const version = '7.4.10';
    getPlatformDetails.mockReturnValue('macos-apple-silicon');
    path.resolve.mockReturnValue('/home/user/.phpvm/versions/7.4.10');
    fs.existsSync.mockImplementation(() => {
      throw new Error('Mocked error');
    });

    usePHPVersion(version, program);

    expect(program.error).toHaveBeenCalledWith(
      `Failed to switch to PHP ${version}: Mocked error\n`,
    );
  });
});

describe('useHomebrewPHP', () => {
  const program = {
    error: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    console.log = jest.fn();
  });

  it('should switch to Homebrew-managed PHP version', () => {
    const version = '7.4.10';
    const brewPrefix = '/usr/local';
    const brewPHPPath = `${brewPrefix}/opt/php@${version}/bin/php`;
    execSync.mockReturnValue(brewPrefix);
    path.resolve.mockReturnValue(brewPHPPath);
    fs.existsSync.mockReturnValue(true);

    useHomebrewPHP(version, program);

    expect(execSync).toHaveBeenCalledWith('brew --prefix');
    expect(fs.existsSync).toHaveBeenCalledWith(brewPHPPath);
    expect(console.log).toHaveBeenCalledWith(
      `Switching to PHP ${version} via Homebrew...\n`,
    );
  });

  it('should handle errors during switching', () => {
    const version = '7.4.10';
    execSync.mockImplementation(() => {
      throw new Error('Mocked error');
    });

    useHomebrewPHP(version, program);

    expect(program.error).toHaveBeenCalledWith(
      `Failed to switch to PHP ${version} via Homebrew: Mocked error\n`,
    );
  });
});

describe('useLinuxPHP', () => {
  const program = {
    error: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    console.log = jest.fn();
  });

  it('should switch to apt-managed PHP version on Ubuntu', () => {
    const version = '7.4';
    const aptPHPPath = `/usr/bin/php${version}`;
    getLinuxDistro.mockReturnValue('ubuntu');
    fs.existsSync.mockReturnValue(true);

    useLinuxPHP(version, program);

    expect(fs.existsSync).toHaveBeenCalledWith(aptPHPPath);
    expect(console.log).toHaveBeenCalledWith(
      `Switching to PHP ${version} via apt...\n`,
    );
  });

  it('should handle unsupported Linux distributions', () => {
    const version = '7.4';
    getLinuxDistro.mockReturnValue('unsupported-distro');

    useLinuxPHP(version, program);

    expect(program.error).toHaveBeenCalledWith(
      `Unsupported Linux distribution: unsupported-distro. Cannot switch to PHP ${version}.\n`,
    );
  });

  it('should handle errors during switching', () => {
    const version = '7.4';
    getLinuxDistro.mockReturnValue('ubuntu');
    fs.existsSync.mockImplementation(() => {
      throw new Error('Mocked error');
    });

    useLinuxPHP(version, program);

    expect(program.error).toHaveBeenCalledWith(
      `Failed to switch to PHP ${version}: Mocked error\n`,
    );
  });
});

describe('setPHPVersion', () => {
  const program = {
    error: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
    console.log = jest.fn();
  });

  it('should set the PHP version', () => {
    const phpPath = '/usr/bin/php7.4';
    const version = '7.4';
    const phpVersionFile = path.resolve(
      process.env.HOME,
      '.phpvm',
      'active_version',
    );
    const localBinDir = path.resolve(process.env.HOME, '.local', 'bin');
    const symlinkPath = path.join(localBinDir, 'php');

    fs.existsSync.mockReturnValue(false);
    path.resolve
      .mockReturnValueOnce(phpVersionFile)
      .mockReturnValueOnce(localBinDir)
      .mockReturnValueOnce(symlinkPath);

    setPHPVersion(phpPath, version, program);

    expect(fs.writeFileSync).toHaveBeenCalledWith(phpVersionFile, version);
    expect(fs.mkdirSync).toHaveBeenCalledWith(localBinDir, { recursive: true });
    expect(fs.symlinkSync).toHaveBeenCalledWith(phpPath, symlinkPath);
    expect(console.log).toHaveBeenCalledWith(
      `PHP ${version} is now the active version. Use 'php -v' to verify.\n`,
    );
  });

  it('should handle errors during setting PHP version', () => {
    const phpPath = '/usr/bin/php7.4';
    const version = '7.4';
    fs.writeFileSync.mockImplementation(() => {
      throw new Error('Mocked error');
    });

    setPHPVersion(phpPath, version, program);

    expect(program.error).toHaveBeenCalledWith(
      `Failed to activate PHP ${version}: Mocked error\n`,
    );
  });
});

describe('getActivePHPVersion', () => {
  it('should return the currently active PHP version', () => {
    const version = '7.4';
    const phpVersionFile = path.resolve(
      process.env.HOME,
      '.phpvm',
      'active_version',
    );
    fs.existsSync.mockReturnValue(true);
    fs.readFileSync.mockReturnValue(version);

    const activeVersion = getActivePHPVersion();
    expect(activeVersion).toBe(version);
  });

  it('should return null if no active PHP version', () => {
    const phpVersionFile = path.resolve(
      process.env.HOME,
      '.phpvm',
      'active_version',
    );
    fs.existsSync.mockReturnValue(false);

    const activeVersion = getActivePHPVersion();
    expect(activeVersion).toBeNull();
  });
});

describe('isLocalBinInPath', () => {
  it('should return true if $HOME/.local/bin is in PATH', () => {
    const localBinDir = path.resolve(process.env.HOME, '.local', 'bin');
    process.env.PATH = `${localBinDir}:${process.env.PATH}`;

    const result = isLocalBinInPath();
    expect(result).toBe(true);
  });

  it('should return false if $HOME/.local/bin is not in PATH', () => {
    process.env.PATH = '/usr/local/bin:/usr/bin:/bin';

    const result = isLocalBinInPath();
    expect(result).toBe(false);
  });
});
