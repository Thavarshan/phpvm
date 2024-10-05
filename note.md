Based on the contents of the `nvm.sh` script, we can recreate it as a Node.js CLI for managing PHP versions. Here’s how we can break it down and refactor it into a Node.js-based solution for PHP:

### Steps to Recreate `nvm.sh` as a Node.js CLI

1. **Initialize a Node.js CLI Project:**

   - Use `npm` to set up the CLI package, specifying commands like `install`, `use`, `list`, and `uninstall` as primary actions.
   - Use `commander.js` or `yargs` to handle the command-line arguments.

2. **Replace Shell Functions with JavaScript:**

   - **Version Management**: Functions like `nvm_ls`, `nvm_version`, `nvm_is_version_installed` can be reimplemented in Node.js by leveraging file system checks and executing shell commands using Node.js modules (`child_process`).
   - **Path Management**: Instead of modifying shell profiles (`.bashrc`, `.zshrc`), use Node.js to manage PHP installations and switch versions dynamically by modifying the environment variables at runtime.

3. **Implement Core Functions in JavaScript:**

   - **Download PHP versions**: Use `node-fetch` or `axios` to download PHP binaries from official mirrors.
   - **Installation Path**: Store PHP binaries in a specific directory (e.g., `~/.pvm/versions/`) and use Node.js to manage these directories.
   - **Switch Versions**: Use Node.js to modify environment variables, such as the `$PATH`, to switch between different PHP versions dynamically.
   - **Version List and Resolution**: Implement functions like `nvm_ls` and `nvm_resolve_alias` to list available PHP versions and resolve aliases (e.g., `default`, `latest`).

4. **Platform-Specific Support:**

   - For cross-platform support, you can use Node.js' built-in `os` module to detect the platform and handle platform-specific paths and binaries (e.g., handling `.exe` files for Windows).

5. **Managing Environment Variables:**

   - Instead of modifying shell profiles, the CLI can print instructions for users to modify their environment variables, or provide a helper function to automatically modify shell profiles or PowerShell configurations.

6. **Creating Commands:**
   Use Node.js libraries to create commands equivalent to NVM’s:
   - `pvm install <version>`: Downloads and installs a PHP version.
   - `pvm use <version>`: Switches to a specific PHP version by modifying the path.
   - `pvm list`: Lists installed versions.
   - `pvm uninstall <version>`: Removes a specific PHP version.

### Example Node.js Code Snippet

Here’s a small example of how to handle downloading PHP versions:

```javascript
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

const versionsDir = path.resolve(process.env.HOME, '.pvm/versions');

// Install PHP version
async function installPHP(version) {
  const phpUrl = `https://www.php.net/distributions/php-${version}.tar.gz`;
  const res = await fetch(phpUrl);

  if (!res.ok) {
    console.error(`Failed to download PHP version ${version}`);
    return;
  }

  const phpFilePath = path.join(versionsDir, `php-${version}.tar.gz`);
  const fileStream = fs.createWriteStream(phpFilePath);

  res.body.pipe(fileStream);
  res.body.on('error', (err) => {
    console.error(`Error writing PHP version: ${err}`);
  });

  fileStream.on('finish', () => {
    console.log(`PHP ${version} downloaded successfully!`);
    // Extract and install steps go here
  });
}

// Switch PHP version
function usePHP(version) {
  const phpPath = path.join(versionsDir, `php-${version}/bin/php`);

  if (fs.existsSync(phpPath)) {
    process.env.PATH = `${phpPath}:${process.env.PATH}`;
    console.log(`Switched to PHP ${version}`);
  } else {
    console.error(`PHP version ${version} is not installed.`);
  }
}

// List installed PHP versions
function listPHP() {
  const installedVersions = fs.readdirSync(versionsDir);
  console.log('Installed PHP versions:');
  installedVersions.forEach((version) => {
    console.log(version);
  });
}

// Example usage
installPHP('8.0.3');
```

This is just a basic sketch, but it demonstrates how you can manage PHP versions similarly to how `nvm` handles Node versions.

### Next Steps:

1. Set up the CLI using a Node.js library like `commander` or `yargs`.
2. Implement core commands (`install`, `use`, `list`, `uninstall`).
3. Test across different platforms (Linux, macOS, Windows).

Let me know when you're ready to proceed with each part, and feel free to share any specific functions or code that you'd like help with!
