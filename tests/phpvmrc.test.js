const fs = require('fs');
const path = require('path');
const {
  findPHPVMRCFile,
  getPHPVersionFromRCFile,
  isPHPVersionInstalled,
  autoSwitchPHPVersion,
} = require('../lib/utils/phpvmrc');

jest.mock('fs');
jest.mock('path');

describe('findPHPVMRCFile', () => {
  it('should find .phpvmrc in the current directory', () => {
    const mockPath = '/path/to/project/.phpvmrc';
    path.join.mockReturnValue(mockPath);
    path.resolve.mockImplementation((_, up) => (up ? '/' : '/path/to/project'));
    fs.existsSync.mockReturnValue(true);

    const result = findPHPVMRCFile('/path/to/project');
    expect(result).toBe(mockPath);
  });

  it('should return null if no .phpvmrc file is found', () => {
    fs.existsSync.mockReturnValue(false);
    const result = findPHPVMRCFile('/some/other/path');
    expect(result).toBeNull();
  });
});

describe('getPHPVersionFromRCFile', () => {
  it('should return PHP version from .phpvmrc file', () => {
    const mockFilePath = '/path/to/.phpvmrc';
    const mockPHPVersion = '7.4.10';
    fs.existsSync.mockReturnValue(true);
    fs.readFileSync.mockReturnValue(mockPHPVersion);

    const result = getPHPVersionFromRCFile(mockFilePath);
    expect(result).toBe(mockPHPVersion);
  });

  it('should throw an error if .phpvmrc file does not exist', () => {
    fs.existsSync.mockReturnValue(false);

    expect(() => {
      getPHPVersionFromRCFile('/path/to/nonexistent/.phpvmrc');
    }).toThrow('File not found: /path/to/nonexistent/.phpvmrc');
  });
});

describe('isPHPVersionInstalled', () => {
  it('should return true if PHP version is installed', () => {
    const mockVersion = '7.4.10';
    const mockHomeDir = '/home/user';
    process.env.HOME = mockHomeDir;
    const mockVersionDir = `${mockHomeDir}/.phpvm/versions/${mockVersion}`;
    fs.existsSync.mockReturnValue(true);

    const result = isPHPVersionInstalled(mockVersion);
    expect(result).toBe(true);
  });

  it('should return false if PHP version is not installed', () => {
    fs.existsSync.mockReturnValue(false);
    const result = isPHPVersionInstalled('7.4.10');
    expect(result).toBe(false);
  });

  it('should throw an error if HOME environment variable is not set', () => {
    delete process.env.HOME;

    expect(() => {
      isPHPVersionInstalled('7.4.10');
    }).toThrow('HOME environment variable is not set.');
  });
});

describe('autoSwitchPHPVersion', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should switch to PHP version specified in .phpvmrc', async () => {
    const mockVersion = '7.4.10';
    const mockPath = '/path/to/.phpvmrc';

    jest.spyOn(global.console, 'log');
    fs.existsSync.mockReturnValue(true);
    path.join.mockReturnValue(mockPath);
    fs.readFileSync.mockReturnValue(mockVersion);
    jest.mock('../lib/commands/use', () => ({
      usePHPVersion: jest.fn(),
    }));
    jest.mock('../lib/commands/install', () => ({
      installPHP: jest.fn(),
    }));

    await autoSwitchPHPVersion();
    expect(console.log).toHaveBeenCalledWith(
      `Found .phpvmrc file. PHP version specified: ${mockVersion}`,
    );
  });

  it('should log if no .phpvmrc file is found', async () => {
    fs.existsSync.mockReturnValue(false);

    jest.spyOn(global.console, 'log');
    await autoSwitchPHPVersion();

    expect(console.log).toHaveBeenCalledWith(
      'No .phpvmrc file found in this directory or any parent directory.',
    );
  });
});
