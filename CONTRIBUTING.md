# Contributing to AWS Project Template

Thank you for your interest in contributing to the AWS Project Template! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to foster an open and welcoming environment.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/aws-project-template.git`
3. Create a branch for your changes: `git checkout -b feature/your-feature-name`

## Development Process

### Setting Up the Development Environment

1. Make sure you have the following tools installed:
   - Node.js (latest LTS version)
   - AWS CLI
   - AWS CDK (if working with CDK)
   - Terraform (if working with Terraform)

2. Run the initialization script: `./scripts/init.sh`

### Making Changes

1. Make your changes in your feature branch
2. Follow the coding style and best practices of the project
3. Add or update tests as necessary
4. Update documentation to reflect your changes

### Testing

1. Run tests to ensure your changes don't break existing functionality:
   ```
   npm test
   ```

2. For infrastructure changes, validate templates:
   - CloudFormation: `aws cloudformation validate-template --template-body file://path/to/template.yaml`
   - CDK: `cdk synth`
   - Terraform: `terraform validate`

### Committing Changes

1. Use clear and descriptive commit messages
2. Reference issue numbers in your commit messages when applicable
3. Keep commits focused on a single logical change

## Pull Request Process

1. Update the README.md or documentation with details of changes if appropriate
2. Ensure all tests pass and the build is successful
3. Submit a pull request to the `main` branch
4. Address any feedback or requested changes from reviewers

### Pull Request Template

When submitting a pull request, please include:

- A description of the changes
- Any related issue numbers
- Screenshots or examples if applicable
- Confirmation that tests have been added or updated

## Style Guides

### Code Style

- Follow the existing code style in the project
- Use meaningful variable and function names
- Include comments for complex logic
- Remove debugging code before submitting

### Documentation Style

- Use Markdown for documentation
- Keep language clear and concise
- Include examples where appropriate
- Update diagrams if necessary

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests after the first line

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Best Practices](https://aws.amazon.com/architecture/best-practices/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)

## Questions?

If you have any questions or need help, please open an issue or contact the maintainers.

Thank you for contributing to the AWS Project Template!