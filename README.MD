[![PHP Version Manager (phpvm)](./assets/Banner.jpg)](https://github.com/Thavarshan/phpvm)

# PHP Version Manager (phpvm)

[![Version](https://img.shields.io/badge/version-v0.0.1-yellow.svg)](https://github.com/Thavarshan/phpvm/releases)
[![Tests](https://github.com/Thavarshan/phpvm/actions/workflows/test.yml/badge.svg?label=test&branch=main)](https://github.com/Thavarshan/phpvm/actions/workflows/test.yml)
[![Build](https://github.com/Thavarshan/phpvm/actions/workflows/use.yml/badge.svg?label=build&branch=main)](https://github.com/Thavarshan/phpvm/actions/workflows/use.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Introduction

`phpvm` is a PHP Version Manager that allows you to easily install, switch between, and manage multiple PHP versions via the command line.

**Example:**

```sh
$ phpvm use 7.4
Now using PHP v7.4.10
$ php -v
PHP 7.4.10
$ phpvm use 8.0
Now using PHP v8.0.8
$ php -v
PHP 8.0.8
```

## About phpvm

`phpvm` is a version manager designed to be used on Unix-like systems, including macOS and Linux. It allows you to install and manage PHP versions, switch between them seamlessly, and work with multiple versions on your system.

### Key Features

- Install and use different PHP versions.
- Easily switch between installed PHP versions.
- List installed PHP versions.
- Uninstall a specific PHP version.

## Installation

### Install & Update Script

To **install** or **update** phpvm, run the following command using either `curl` or `wget`:

```sh
curl -o- https://raw.githubusercontent.com/Thavarshan/phpvm/main/bin/install.sh | bash
```

```sh
wget -qO- https://raw.githubusercontent.com/Thavarshan/phpvm/main/bin/install | bash
```

This script clones the `phpvm` repository into `~/.phpvm` and attempts to add the following lines to your profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```sh
export PHPVM_DIR="$HOME/.phpvm"
export PATH="$HOME/.local/bin:$PATH"
```

### Verify Installation

To verify that `phpvm` has been installed, run the following command:

```sh
command -v phpvm
```

This should output `phpvm` if the installation was successful.

### Manual Install

To manually install `phpvm`, clone the repository:

```sh
git clone https://github.com/Thavarshan/phpvm.git ~/.phpvm
```

Then add the following lines to your shell's profile (`~/.bashrc`, `~/.zshrc`, etc.):

```sh
export PHPVM_DIR="$HOME/.phpvm"
export PATH="$HOME/.local/bin:$PATH"
```

### Manual Update

To manually update `phpvm` to the latest version, use the following commands:

```sh
cd ~/.phpvm
git fetch --tags origin
git checkout `git describe --abbrev=0 --tags`
```

## Usage

### Installing PHP Versions

To install a specific version of PHP, run:

```sh
phpvm install 8.1
```

This will install PHP version 8.1.

### Switching PHP Versions

To switch between installed versions:

```sh
phpvm use 8.0
```

This will switch to PHP 8.0. You can verify the active version by running:

```sh
php -v
```

### Uninstalling PHP Versions

To uninstall a version of PHP:

```sh
phpvm uninstall 7.4
```

This will uninstall PHP 7.4 from the system.

### Listing Installed Versions

To list the installed PHP versions:

```sh
phpvm list
```

This will display all the PHP versions managed by `phpvm`.

## Running Tests

You can run tests using Jest. Install the dependencies and run the following command:

```sh
npm install
npm test
```

This will run all tests defined for `phpvm`.

## Uninstallation

To manually uninstall `phpvm`, run:

```sh
rm -rf ~/.phpvm
```

And remove the following lines from your shell's profile:

```sh
export PHPVM_DIR="$HOME/.phpvm"
export PATH="$HOME/.local/bin:$PATH"
```

## Troubleshooting

If you encounter any issues with `phpvm` or its functionality, consider the following troubleshooting steps:

- Make sure your shell configuration file is correctly sourcing `phpvm`.
- For macOS, ensure that the necessary command line tools (like Homebrew or Xcode) are installed.
- Restart your terminal after making any changes.
- Ensure you have proper permissions to install PHP versions and modify system paths.

## Maintainers

`phpvm` is maintained by [Jerome Thayananthajothy](https://github.com/Thavarshan).

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for more details.

## Disclaimer

`phpvm` is an open-source tool designed to simplify PHP version management. While we strive to ensure its functionality across different platforms and configurations, we make no warranties or guarantees regarding its accuracy, completeness, reliability, or suitability for any particular purpose.

**Use at your own risk.** By using `phpvm`, you acknowledge that the developers and contributors are not responsible for any damages or data loss resulting from the installation, configuration, or use of this tool.
