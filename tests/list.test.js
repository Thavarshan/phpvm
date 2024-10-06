const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');
const { listPHPVersions } = require('../lib/commands/list');

jest.mock('fs');
jest.mock('child_process');

describe('listPHPVersions', () => {
  const mockProgram = {
    error: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('test process platform', function () {
    beforeAll(function () {
      this.originalPlatform = process.platform;
    });

    afterAll(function () {
      Object.defineProperty(process, 'platform', {
        value: this.originalPlatform,
      });
    });

    test('should list PHP versions managed by phpvm', () => {
      const phpvmVersionsDir = path.resolve(
        process.env.HOME,
        '.phpvm',
        'versions',
      );
      const phpvmVersions = ['7.4.10', '8.0.3'];

      fs.existsSync.mockReturnValue(true);
      fs.readdirSync.mockReturnValue(phpvmVersions);

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(fs.existsSync).toHaveBeenCalledWith(phpvmVersionsDir);
      expect(fs.readdirSync).toHaveBeenCalledWith(phpvmVersionsDir);
      expect(console.log).toHaveBeenCalledWith(
        'PHP versions installed by phpvm:\n',
      );
      phpvmVersions.forEach((version) => {
        expect(console.log).toHaveBeenCalledWith(`- ${version}\n`);
      });
    });

    test('should handle no PHP versions managed by phpvm', () => {
      const phpvmVersionsDir = path.resolve(
        process.env.HOME,
        '.phpvm',
        'versions',
      );

      fs.existsSync.mockReturnValue(true);
      fs.readdirSync.mockReturnValue([]);

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(fs.existsSync).toHaveBeenCalledWith(phpvmVersionsDir);
      expect(fs.readdirSync).toHaveBeenCalledWith(phpvmVersionsDir);
      expect(console.log).toHaveBeenCalledWith(
        'PHP versions installed by phpvm:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        'No PHP versions installed by phpvm.\n',
      );
    });

    test('should handle no phpvm versions directory', () => {
      const phpvmVersionsDir = path.resolve(
        process.env.HOME,
        '.phpvm',
        'versions',
      );

      fs.existsSync.mockReturnValue(false);

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(fs.existsSync).toHaveBeenCalledWith(phpvmVersionsDir);
      expect(console.log).toHaveBeenCalledWith(
        'PHP versions installed by phpvm:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        'No PHP versions installed by phpvm.\n',
      );
    });

    test('should list PHP versions installed via Homebrew on macOS', () => {
      Object.defineProperty(process, 'platform', {
        value: 'darwin',
      });
      const brewPHPVersions = 'php@7.4 7.4.10 php@8.0 8.0.3';

      execSync.mockReturnValue(Buffer.from(brewPHPVersions));

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('brew list --versions | grep php');
      expect(console.log).toHaveBeenCalledWith(
        '\nPHP versions installed via system package managers:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        `Homebrew PHP versions:\n${brewPHPVersions}\n`,
      );
    });

    test('should handle no PHP versions installed via Homebrew on macOS', () => {
      Object.defineProperty(process, 'platform', {
        value: 'darwin',
      });

      execSync.mockReturnValue(Buffer.from(''));

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('brew list --versions | grep php');
      expect(console.log).toHaveBeenCalledWith(
        '\nPHP versions installed via system package managers:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        'No PHP versions installed via Homebrew.\n',
      );
    });

    test('should handle Homebrew not installed on macOS', () => {
      Object.defineProperty(process, 'platform', {
        value: 'darwin',
      });

      execSync.mockImplementation(() => {
        throw new Error('Command failed');
      });

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('brew list --versions | grep php');
      expect(mockProgram.error).toHaveBeenCalledWith(
        'Homebrew is not installed or PHP is not installed via Homebrew.\n',
      );
    });

    test('should list PHP versions installed via APT on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux',
      });
      const aptPHPVersions = 'php7.4 7.4.10 php8.0 8.0.3';

      execSync.mockReturnValue(Buffer.from(aptPHPVersions));

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('dpkg -l | grep php');
      expect(console.log).toHaveBeenCalledWith(
        '\nPHP versions installed via system package managers:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        `APT PHP versions:\n${aptPHPVersions}\n`,
      );
    });

    test('should handle no PHP versions installed via APT on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux',
      });

      execSync.mockReturnValue(Buffer.from(''));

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('dpkg -l | grep php');
      expect(console.log).toHaveBeenCalledWith(
        '\nPHP versions installed via system package managers:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        'No PHP versions installed via APT.\n',
      );
    });

    test('should handle no PHP versions found via APT on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux',
      });

      execSync.mockImplementation(() => {
        throw new Error('Command failed');
      });

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('dpkg -l | grep php');
      expect(mockProgram.error).toHaveBeenCalledWith(
        'No PHP versions found via APT package manager.\n',
      );
    });

    test('should list PHP versions installed via DNF on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux',
      });
      const dnfPHPVersions = 'php7.4 7.4.10 php8.0 8.0.3';

      execSync.mockReturnValue(Buffer.from(dnfPHPVersions));

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('dnf list installed | grep php');
      expect(console.log).toHaveBeenCalledWith(
        '\nPHP versions installed via system package managers:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        `DNF PHP versions:\n${dnfPHPVersions}\n`,
      );
    });

    test('should handle no PHP versions installed via DNF on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux',
      });

      execSync.mockReturnValue(Buffer.from(''));

      console.log = jest.fn();

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('dnf list installed | grep php');
      expect(console.log).toHaveBeenCalledWith(
        '\nPHP versions installed via system package managers:\n',
      );
      expect(console.log).toHaveBeenCalledWith(
        'No PHP versions installed via DNF.\n',
      );
    });

    test('should handle no PHP versions found via DNF on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux',
      });

      execSync.mockImplementation(() => {
        throw new Error('Command failed');
      });

      listPHPVersions(mockProgram);

      expect(execSync).toHaveBeenCalledWith('dnf list installed | grep php');
      expect(mockProgram.error).toHaveBeenCalledWith(
        'No PHP versions found via DNF package manager.\n',
      );
    });
  });
});
