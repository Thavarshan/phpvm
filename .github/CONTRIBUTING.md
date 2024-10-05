# Contributing to Comet

First off, thank you for considering contributing to Comet! It’s people like you who make open-source projects successful. Whether you’re here to fix a bug, improve the documentation, or suggest a new feature, we welcome your help.

## 🛠 How to Contribute

### Reporting Bugs

If you encounter any bugs or issues while using Comet, please report them. This helps us to maintain the quality of the project and ensures that other users have a better experience.

1. **Search for existing issues**: Before reporting a new issue, check if someone else has already reported it. You can search [here](https://github.com/Thavarshan/phpvm/issues).
2. **Create a new issue**: If you don’t find a similar issue, create a new one [here](https://github.com/Thavarshan/phpvm/issues/new).
3. **Provide details**: Please include as much information as possible. Include the steps to reproduce the issue, the expected outcome, and the actual outcome. Providing screenshots, error messages, and relevant log files can help us resolve the issue faster.

### Suggesting Features

We welcome suggestions for new features that could enhance Comet.

1. **Search for existing suggestions**: Before suggesting a new feature, check if someone else has already suggested it [here](https://github.com/Thavarshan/phpvm/issues).
2. **Create a new feature request**: If your feature is unique, create a new feature request [here](https://github.com/Thavarshan/phpvm/issues/new?template=feature_request.md).
3. **Describe the feature**: Provide a detailed description of the feature, why you think it’s important, and how it could benefit users. If possible, suggest how it could be implemented.

### Contributing Code

We love contributions, whether they’re bug fixes, new features, or improving documentation. Before contributing code, please read the following guidelines:

#### Step 1: Fork the Repository

1. **Fork**: Fork the repository to your GitHub account by clicking the "Fork" button at the top right of the repository page.
2. **Clone**: Clone the forked repository to your local machine.

   ```bash
   git clone https://github.com/Thavarshan/phpvm.git
   cd comet
   ```

#### Step 2: Set Up the Development Environment

1. **Install dependencies**: Install the necessary packages.

   ```bash
   npm install
   ```

2. **Run the application**: Start the application in development mode.

   ```bash
   npm run start
   ```

3. **Make your changes**: Create a new branch for your work, and make your changes.

   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Test your changes**: Ensure that your changes do not break any existing functionality. Write unit tests if applicable.

   ```bash
   npm run test
   ```

#### Step 3: Commit Your Changes

1. **Commit**: Once you’re happy with your changes, commit them with a descriptive commit message.

   ```bash
   git add .
   git commit -m "Description of your changes"
   ```

2. **Push**: Push your branch to your forked repository.

   ```bash
   git push origin feature/your-feature-name
   ```

#### Step 4: Submit a Pull Request

1. **Create a Pull Request (PR)**: Go to the original repository, and you’ll see a "Compare & pull request" button for your branch. Click it.
2. **Provide details**: In the PR description, include a brief summary of your changes and any relevant issue numbers (e.g., `Closes #123`).
3. **Submit**: Click "Create pull request" to submit your changes for review.

#### Step 5: Respond to Feedback

We may have some feedback or questions about your PR. Please be responsive and willing to make adjustments as needed. Once your PR is approved, it will be merged into the main branch.

### Code Style and Guidelines

- **Code Quality**: Please write clean, readable, and well-documented code.
- **Consistency**: Follow the existing code style in the repository. We use ESLint and Prettier for enforcing code style, so make sure your code passes all linting checks.
- **Commit Messages**: Write clear and concise commit messages. If your change is related to an issue, include the issue number in the commit message (e.g., `Fixes #123`).

### Documentation

We appreciate contributions to our documentation. If you’ve added a new feature, or found that some parts of the documentation could be improved, feel free to submit a PR.

1. **Docs Location**: Most of the documentation is located in the `README.md` or within the `docs/` folder if it exists.
2. **Changes**: Make your changes and submit a pull request following the same process as contributing code.

## 🌟 Thank You

Your contributions make Comet better for everyone. Thank you for taking the time to improve the project. We’re thrilled to have you as part of our community, and we’re excited to see what you’ll contribute.

If you have any questions, feel free to [open an issue](https://github.com/Thavarshan/phpvm/issues/new) or reach out to us. Happy coding!
