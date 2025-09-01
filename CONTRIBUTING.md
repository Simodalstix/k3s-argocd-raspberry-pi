# Contributing

Thank you for your interest in contributing to this project!

## Development Setup

1. Fork and clone the repository
2. Install Ansible and required collections:
   ```bash
   pip install ansible kubernetes
   ansible-galaxy collection install -r requirements.yml
   ```
3. Test on local VMs (Vagrant, Multipass, or VirtualBox)

## Testing

- Test playbooks on clean Ubuntu 22.04 VMs
- Verify K3s cluster functionality with `kubectl get nodes`
- Ensure ArgoCD deploys and syncs applications successfully
- Run `ansible-lint` on playbooks before submitting

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes with clear commit messages
3. Test thoroughly on clean environments
4. Update documentation if needed
5. Submit pull request with description of changes

## Code Standards

- Follow Ansible best practices
- Use meaningful variable names
- Add comments for complex logic
- Pin versions for reproducibility
- Keep roles focused and reusable

## Issues

- Use GitHub issues for bug reports and feature requests
- Include environment details and error messages
- Search existing issues before creating new ones