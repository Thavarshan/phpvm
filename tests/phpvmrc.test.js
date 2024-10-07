const fs = require('fs');
const path = require('path');
const {
  findPHPVMRCFile,
  autoSwitchPHPVersion,
} = require('../lib/utils/phpvmrc');
const { usePHPVersion } = require('../lib/commands/use');

jest.mock('fs');
jest.mock('path');
jest.mock('../lib/commands/use');

describe('findPHPVMRCFile', () => {
  it('should return the correct path when a .phpvmrc file is found', () => {
    const mockPath = '/path/to/.phpvmrc';
    fs.existsSync.mockReturnValueOnce(true);
    path.join.mockReturnValueOnce(mockPath);

    const result = findPHPVMRCFile('/path/to/start');
    expect(result).toBe(mockPath);
  });

  it('should return null when no .phpvmrc file is found', () => {
    fs.existsSync.mockReturnValue(false);

    const result = findPHPVMRCFile('/path/to/start');
    expect(result).toBeNull();
  });
});

describe('autoSwitchPHPVersion', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should switch to PHP version specified in .phpvmrc', async () => {
    const mockVersion = '7.4.10';
    const mockPath = '/path/to/.phpvmrc';

    fs.existsSync.mockReturnValue(true);
    path.join.mockReturnValue(mockPath);
    fs.readFileSync.mockReturnValue(mockVersion);

    await autoSwitchPHPVersion();
    expect(usePHPVersion).toHaveBeenCalledWith(mockVersion);
  });

  it('should log an error if switching to PHP version fails', async () => {
    const mockVersion = '7.4.10';
    const mockPath = '/path/to/.phpvmrc';
    const mockError = new Error('Switch failed');

    fs.existsSync.mockReturnValue(true);
    path.join.mockReturnValue(mockPath);
    fs.readFileSync.mockReturnValue(mockVersion);
    usePHPVersion.mockRejectedValue(mockError);

    jest.spyOn(global.console, 'error');

    await autoSwitchPHPVersion();
    expect(console.error).toHaveBeenCalledWith(
      `Failed to switch to PHP ${mockVersion}: ${mockError.message}`,
    );
  });

  it('should remain silent if no .phpvmrc file is found', async () => {
    fs.existsSync.mockReturnValue(false);

    jest.spyOn(global.console, 'log');

    await autoSwitchPHPVersion();
    expect(console.log).not.toHaveBeenCalled();
  });
});
