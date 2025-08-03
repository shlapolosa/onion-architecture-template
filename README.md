# Template Service

CLAUDE.md-compliant microservice with Onion Architecture and 12-Factor principles.

## Architecture

This template follows the Onion Architecture pattern with these layers:

- **Domain Layer** (`src/domain/`): Core business entities and rules
- **Application Layer** (`src/application/`): Use cases and application services  
- **Infrastructure Layer** (`src/infrastructure/`): External concerns (databases, APIs)
- **Interface Layer** (`src/interface/`): Web controllers and API endpoints

## 12-Factor Compliance

- ✅ **Codebase**: Single codebase, version controlled
- ✅ **Dependencies**: Explicitly declared in `pyproject.toml`
- ✅ **Config**: Store in environment variables 
- ✅ **Backing services**: Treat as attachable resources
- ✅ **Build, release, run**: Separation via Docker multi-stage build
- ✅ **Processes**: Stateless and disposable
- ✅ **Port binding**: Self-contained service on port 8080
- ✅ **Concurrency**: Scale via process model
- ✅ **Disposability**: Fast startup and graceful shutdown
- ✅ **Dev/prod parity**: Docker ensures consistency
- ✅ **Logs**: Treat as event streams
- ✅ **Admin processes**: Run as one-off containers

## Development

### Prerequisites

- Python 3.11+
- Poetry for dependency management

### Setup

```bash
# Install dependencies
poetry install

# Run tests (TDD Red-Green-Refactor)
poetry run pytest

# Format code
poetry run black src/
poetry run isort src/

# Type checking
poetry run mypy src/
```

### Running

```bash
# Development
poetry run python src/main.py

# Production (Docker)
docker build -t template-service .
docker run -p 8080:8080 template-service
```

### Testing

```bash
# Run all tests
poetry run pytest

# Run with coverage
poetry run pytest --cov=src

# Health check
curl http://localhost:8080/health
```

## API Endpoints

- `GET /health` - Health check for Kubernetes probes
- `GET /ready` - Readiness check for Kubernetes probes  
- `GET /` - Root endpoint
- `GET /docs` - Auto-generated API documentation

## Template Usage

This repository serves as a template for creating new Python/FastAPI microservices. When used by the ApplicationClaim composition:

1. The template is cloned
2. Service name replaces `template-service` throughout
3. Files are customized for the specific service
4. The result follows CLAUDE.md compliance automatically