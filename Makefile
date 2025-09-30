.PHONY: help install lint build test clean

# Default target
help:
	@echo "Available targets:"
	@echo "  install    - Install development dependencies"
	@echo "  lint       - Run all linting tools"
	@echo "  build      - Build the Ansible collection"
	@echo "  test       - Run syntax checks and tests"
	@echo "  clean      - Clean build artifacts"

install:
	@echo "Installing dependencies..."
	pip install --user -r requirements.txt
	@if command -v npm >/dev/null 2>&1; then \
		npm install; \
	else \
		echo "Node.js not found, skipping npm install"; \
	fi

lint:
	@echo "Running linting tools..."
	@if command -v ansible-lint >/dev/null 2>&1; then \
		ansible-lint; \
	else \
		echo "ansible-lint not found, skipping"; \
	fi
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint .; \
	else \
		echo "yamllint not found, skipping"; \
	fi
	@if command -v npm >/dev/null 2>&1 && [ -f package.json ]; then \
		npm run lint:markdown; \
	else \
		echo "npm or package.json not found, skipping markdown lint"; \
	fi

build:
	@echo "Building collection..."
	mkdir -p build
	ansible-galaxy collection build ansible_collections/basher83/komodo/ --output-path ./build/ --force

test: build
	@echo "Running syntax checks..."
	ansible-playbook --syntax-check ansible_collections/basher83/komodo/playbooks/install.yml
	@echo "Running collection validation..."
	ansible-galaxy collection install ./build/basher83-komodo-*.tar.gz --force

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -f *.tar.gz
	rm -rf node_modules/