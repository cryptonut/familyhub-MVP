# Contributing to Family Hub MVP

Thank you for your interest in contributing to Family Hub MVP!

## Development Workflow

### 1. Create Feature Branch

```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Follow code style guidelines
- Write clear commit messages
- Add tests for new features
- Update documentation

### 3. Commit Changes

```bash
git add .
git commit -m "feat: Add new feature description"
```

**Commit Message Format:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Tests
- `chore:` - Maintenance

### 4. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Create a Pull Request to `develop` branch.

## Code Style

- Follow Dart/Flutter style guide
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small
- Use `Logger` instead of `print()`

## Testing

- Write unit tests for services
- Add widget tests for UI components
- Test on multiple devices
- Verify error handling

## Documentation

- Update README for new features
- Add code comments for complex logic
- Document API changes
- Update setup guides if needed

## Review Process

1. Code review by maintainers
2. Address feedback
3. Merge to `develop`
4. Test in QA environment
5. Deploy to production

## Questions?

Open an issue or contact the maintainers.

