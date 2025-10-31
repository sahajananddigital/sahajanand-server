# Contributing to Sahajanand Server Infrastructure

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## 🎯 How to Contribute

### Reporting Issues

If you find a bug or have a feature request, please open an issue on GitHub with:
- Clear description of the issue
- Steps to reproduce (if applicable)
- Expected vs actual behavior
- System information (OS, Docker version, etc.)

### Contributing Code

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Make your changes**
4. **Test your changes** (`./scripts/test-setup.sh`)
5. **Commit with clear messages** (`git commit -m 'Add amazing feature'`)
6. **Push to your branch** (`git push origin feature/amazing-feature`)
7. **Open a Pull Request**

### Code Guidelines

- Follow existing code style
- Add comments for complex logic
- Update documentation for new features
- Test all changes before submitting
- Keep commits focused and atomic

### Areas for Contribution

- **Documentation**: Improve README, add examples, fix typos
- **Scripts**: Optimize performance, add features, fix bugs
- **Configuration**: Better defaults, more options
- **Docker**: Optimize images, reduce resource usage
- **Testing**: Add tests, improve test coverage

## 🔍 Development Setup

1. Clone the repository
2. Copy `env.example` to `.env` and configure
3. Run `./scripts/test-setup.sh` to verify setup
4. Make your changes
5. Test thoroughly before submitting

## 📝 Commit Message Guidelines

- Use clear, descriptive messages
- Start with a verb (Add, Fix, Update, Remove)
- Reference issue numbers if applicable
- Example: `Fix Nginx config generation for multiple domains`

## ✅ Before Submitting

- [ ] Code follows project style
- [ ] Tests pass (`./scripts/test-setup.sh`)
- [ ] Documentation updated
- [ ] No hardcoded secrets or passwords
- [ ] Commit messages are clear

## 🤝 Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community

## 📞 Questions?

Open an issue for discussion or questions about contributing.

Thank you for contributing! 🎉
