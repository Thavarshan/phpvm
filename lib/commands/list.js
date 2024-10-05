const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * List all installed PHP versions.
 * @param {Command} program - The Commander.js program instance to use for output.
 */
function listPHPVersions(program) {
  // Step 1: List PHP versions managed by phpvm
  const phpvmVersionsDir = path.resolve(process.env.HOME, '.phpvm', 'versions');
  console.log('PHP versions installed by phpvm:\n');

  if (fs.existsSync(phpvmVersionsDir)) {
    const phpvmVersions = fs.readdirSync(phpvmVersionsDir);

    if (phpvmVersions.length > 0) {
      phpvmVersions.forEach((version) => console.log(`- ${version}\n`));
    } else {
      console.log('No PHP versions installed by phpvm.\n');
    }
  } else {
    console.log('No PHP versions installed by phpvm.\n');
  }

  // Step 2: List PHP versions installed via platform-specific package managers
  console.log('\nPHP versions installed via system package managers:\n');

  // macOS: Check Homebrew installations
  if (process.platform === 'darwin') {
    try {
      const brewPHPVersions = execSync('brew list --versions | grep php')
        .toString()
        .trim();
      if (brewPHPVersions) {
        console.log(`Homebrew PHP versions:\n${brewPHPVersions}\n`);
      } else {
        console.log('No PHP versions installed via Homebrew.\n');
      }
    } catch (error) {
      program.error(
        'Homebrew is not installed or PHP is not installed via Homebrew.\n',
      );
    }
  }

  // Linux: Check `apt` (Ubuntu/Debian) or `dnf` (Fedora) installations
  if (process.platform === 'linux') {
    try {
      // For Debian/Ubuntu systems using apt
      const aptPHPVersions = execSync('dpkg -l | grep php').toString().trim();
      if (aptPHPVersions) {
        console.log(`APT PHP versions:\n${aptPHPVersions}\n`);
      } else {
        console.log('No PHP versions installed via APT.\n');
      }
    } catch (error) {
      program.error('No PHP versions found via APT package manager.\n');
    }

    try {
      // For Fedora systems using dnf
      const dnfPHPVersions = execSync('dnf list installed | grep php')
        .toString()
        .trim();
      if (dnfPHPVersions) {
        console.log(`DNF PHP versions:\n${dnfPHPVersions}\n`);
      } else {
        console.log('No PHP versions installed via DNF.\n');
      }
    } catch (error) {
      program.error('No PHP versions found via DNF package manager.\n');
    }
  }

  // Step 3: Optionally check for other package managers (extend as needed)
}

module.exports = { listPHPVersions };
