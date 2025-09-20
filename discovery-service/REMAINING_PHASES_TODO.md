# Simplified Discovery Service - Remaining Phases TODO

## Overview

This document outlines the remaining implementation tasks for Phases 2-4 of the simplified discovery service project. Phase 1 (Core Architecture Simplification) has been completed successfully.

**Phase 1 Status: ✅ COMPLETED**
- Core components consolidated into `app/simple_core.py` (380 lines)
- Web application created as `app/simple_main.py` (180 lines)
- Database schema simplified to single table
- Configuration compatibility maintained
- 70% code reduction achieved while preserving functionality

---

## Phase 2: Security Model Simplification

### Goals
Complete the security model simplification by updating client scripts and removing timestamp-based complexity throughout the system.

### Tasks for Claude Code:

#### 2.1 Update Client Scripts
- [ ] **Simplify `bootstrap_client.py`**:
  - Remove `timestamp` parameter from signature creation methods
  - Update `_create_signature()` to use format: `hmac_sha256(psk, data)` (no timestamp)
  - Remove timestamp handling in `register_device()` and `confirm_bootstrap()` methods
  - Update request payloads to exclude timestamp fields
  - Test with simplified discovery service endpoints

- [ ] **Remove `client_example.py`** (redundant with simplified bootstrap_client.py)

- [ ] **Update request/response documentation**:
  - Update API documentation to reflect removed timestamp fields
  - Update example requests in comments and docstrings
  - Ensure all references to timestamp validation are removed

#### 2.2 Validate Security Model Changes
- [ ] **Test signature compatibility**:
  - Verify simplified client can register with simplified service
  - Test registration request: `serial:mac` signature format
  - Test confirmation request: `serial:hostname` signature format
  - Ensure no timestamp-related errors occur

- [ ] **Security validation**:
  - Confirm PSK authentication still works correctly
  - Verify device-specific encryption/decryption functions
  - Test with invalid signatures (should fail appropriately)
  - Ensure constant-time comparison still prevents timing attacks

#### 2.3 Update Configuration Models
- [ ] **Remove timestamp-related configuration**:
  - Remove `signature_window_seconds` from security configuration
  - Remove any timestamp validation settings
  - Clean up configuration documentation

### Phase 2 Deliverables:
- [ ] Updated `bootstrap_client.py` with simplified signature handling
- [ ] Removed `client_example.py` 
- [ ] Updated API documentation and examples
- [ ] Validated end-to-end registration flow without timestamps

---

## Phase 3: Docker and Deployment Simplification

### Goals
Create minimal Docker setup and simplified deployment configurations while maintaining production readiness.

### Tasks for Claude Code:

#### 3.1 Create Simplified Docker Configuration
- [ ] **Create `Dockerfile.simple`**:
  - Use single-stage build (remove multi-stage complexity)
  - Remove user creation and permission handling (run as root for simplicity)
  - Remove `entrypoint.sh` script dependency
  - Use direct command: `CMD ["python", "-m", "app.simple_main"]`
  - Keep health check but simplify: `python -c "import requests; requests.get('http://localhost:8080/health')"`
  - Minimize installed system packages

- [ ] **Create `requirements.simple.txt`**:
  - Include only essential dependencies:
    - `fastapi==0.104.1`
    - `uvicorn[standard]==0.24.0`
    - `pydantic==2.5.0`
    - `cryptography==41.0.7`
    - `pyyaml==6.0.1`
  - Remove: `slowapi`, `python-multipart`, `pydantic-settings`
  - Keep `httpx==0.25.2` as optional (commented out with note)

#### 3.2 Create Simplified Docker Compose
- [ ] **Create `docker-compose.simple.yml`**:
  - Use `Dockerfile.simple` for build
  - Keep parent directory mount for `.deployment.yaml`: `..:/app/parent:ro`
  - Simplify volume mounts (remove complex permission handling)
  - Keep basic health check configuration
  - Use simplified service name: `discovery-service-simple`

- [ ] **Remove NGINX configuration** (not needed for simplified setup):
  - Document that NGINX can be added separately if needed
  - Provide simple reverse proxy example in documentation

#### 3.3 Update Bootstrap Client for Production
- [ ] **Enhance `bootstrap_client.py` for production use**:
  - Add better error handling and retry logic
  - Improve device information detection (serial/MAC)
  - Add configuration file output for integration with NixOS
  - Add verbose logging option for debugging
  - Ensure compatibility with simplified discovery service

#### 3.4 Create Migration Documentation
- [ ] **Create `SIMPLE_MIGRATION.md`**:
  - Document how to migrate from original to simplified service
  - List all breaking changes (timestamp removal, rate limiting, admin auth)
  - Provide step-by-step migration instructions
  - Include rollback procedures
  - Document configuration differences

### Phase 3 Deliverables:
- [ ] `Dockerfile.simple` - Minimal container configuration
- [ ] `requirements.simple.txt` - Reduced dependency list
- [ ] `docker-compose.simple.yml` - Simplified deployment
- [ ] Enhanced `bootstrap_client.py` for production
- [ ] `SIMPLE_MIGRATION.md` - Migration documentation

---

## Phase 4: Testing and Validation

### Goals
Ensure the simplified version maintains functional compatibility and validate performance improvements.

### Tasks for Claude Code:

#### 4.1 Create Comprehensive Test Suite
- [ ] **Create `test_simple_discovery_complete.py`**:
  - Test all 4 endpoints: `/register`, `/confirm`, `/health`, `/stats`
  - Test PSK signature generation/verification for both request types
  - Test database operations (registration, confirmation, statistics)
  - Test configuration loading from unified YAML
  - Test encrypted payload creation and device-specific encryption
  - Test error handling and edge cases
  - Use proper test fixtures and mock external dependencies

- [ ] **Create integration tests**:
  - Test full registration workflow (client → service → confirmation)
  - Test with real `.deployment.yaml` configuration
  - Test Docker container deployment
  - Test NTFY notifications (with and without httpx)

#### 4.2 Performance Validation
- [ ] **Create `performance_comparison.py`**:
  - Compare memory usage: simplified vs original service
  - Compare startup time: simplified vs original service
  - Compare response times for all endpoints
  - Compare database operation performance
  - Document improvements and any regressions

- [ ] **Load testing**:
  - Test simplified service under load (multiple concurrent registrations)
  - Verify no race conditions in hostname assignment
  - Test database performance with multiple devices
  - Document performance characteristics

#### 4.3 Compatibility Validation
- [ ] **Create `compatibility_test.py`**:
  - Test unified configuration compatibility
  - Verify same API contract (request/response formats)
  - Test with existing bootstrap clients (before simplification)
  - Validate encrypted payload format compatibility
  - Test deployment in Docker environment

#### 4.4 Documentation and Examples
- [ ] **Create `DEPLOYMENT_GUIDE.md`**:
  - Complete deployment instructions for simplified service
  - Docker deployment examples
  - Configuration examples and best practices
  - Troubleshooting guide
  - Performance tuning recommendations

- [ ] **Create example configurations**:
  - Example `.deployment.yaml` for different scenarios
  - Example Docker deployment with monitoring
  - Example client integration scripts

### Phase 4 Deliverables:
- [ ] `test_simple_discovery_complete.py` - Comprehensive test suite
- [ ] `performance_comparison.py` - Performance validation
- [ ] `compatibility_test.py` - Compatibility validation
- [ ] `DEPLOYMENT_GUIDE.md` - Complete deployment documentation
- [ ] Example configurations and integration scripts

---

## Success Criteria for All Phases

### Code Quality
- [ ] **70% code reduction achieved** (Phase 1: ✅ Complete)
- [ ] **40% dependency reduction achieved** (Target for Phase 3)
- [ ] All functionality preserved (all 4 endpoints working)
- [ ] Unified configuration system unchanged
- [ ] Security model maintained (PSK + HMAC + encryption)

### Performance Goals
- [ ] **Faster startup time** (measured in Phase 4)
- [ ] **Lower memory usage** (measured in Phase 4)
- [ ] **Same or better response times** (validated in Phase 4)

### Deployment Improvements
- [ ] **Simplified Docker deployment** (Phase 3)
- [ ] **Reduced configuration complexity** (Phase 3)
- [ ] **Easier troubleshooting** (fewer moving parts)

### Compatibility Requirements
- [ ] **API contract preserved** (same endpoints, same data formats)
- [ ] **Configuration compatibility** (same `.deployment.yaml` format)
- [ ] **Client compatibility** (after timestamp removal updates)

---

## Implementation Notes for Claude Code

### Key Principles
1. **Maintain functionality**: All existing features must work after simplification
2. **Preserve security**: PSK + HMAC + encryption must remain intact
3. **Keep compatibility**: Unified configuration system must work unchanged
4. **Document changes**: All breaking changes must be clearly documented
5. **Test thoroughly**: Each phase should include comprehensive testing

### Breaking Changes to Document
- **Timestamp removal**: Clients must update request formats
- **Rate limiting removal**: No built-in protection against abuse
- **Admin authentication removal**: `/stats` endpoint becomes public
- **Audit logging removal**: No request history tracking

### Files to Preserve
- **Core functionality**: All business logic from original implementation
- **Configuration system**: Complete compatibility with `.deployment.yaml`
- **Security features**: PSK, HMAC, AES-256-GCM encryption
- **API endpoints**: Same URLs, methods, and basic response formats

### Testing Requirements
- Each phase should include validation that changes work correctly
- Integration tests should verify end-to-end functionality
- Performance tests should demonstrate improvements
- Compatibility tests should ensure no regressions in core features

---

## Getting Started with Next Phase

To continue development, Claude Code should:

1. **Choose Phase 2, 3, or 4** based on priorities
2. **Create feature branch** for the selected phase: `git checkout -b feature/phase-N-description`
3. **Work through tasks systematically** using the TodoWrite tool to track progress
4. **Test each change** before moving to the next task
5. **Document all changes** and update relevant documentation
6. **Commit work regularly** with descriptive commit messages

The simplified discovery service architecture from Phase 1 provides a solid foundation for all remaining work while maintaining the essential functionality and security requirements.