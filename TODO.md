# NixOS Sensor Network Cleanup - Project Status

## Overview
This document tracks the phased cleanup approach to simplify the NixOS Raspberry Pi sensor system by removing deprecated files and streamlining documentation.

**IMPORTANT**: DO NOT modify any `.nix` files, `build.sh`, or core build infrastructure during this cleanup.

---

## ✅ COMPLETED PHASES

### Phase 1: Complete Documentation Cleanup ✅ COMPLETE
**Completed on:** September 20, 2024

#### Phase 1.1: Deprecated File Removal ✅ 
**Files Successfully Removed:**
- ✅ `discovery-service/generate_psk.py` 
- ✅ `discovery-service/app/config.original.py`
- ✅ `discovery-service/app/database.original.py`
- ✅ `discovery-service/app/logging.original.py`
- ✅ `discovery-service/app/main.original.py`
- ✅ `discovery-service/app/models.original.py`
- ✅ `discovery-service/app/notifications.original.py`
- ✅ `discovery-service/app/security.original.py`
- ✅ `discovery-service/docker-compose.original.yml`
- ✅ `discovery-service/Dockerfile.original`
- ✅ `discovery-service/entrypoint.sh`
- ✅ `discovery-service/requirements.original.txt`

#### Phase 1.2: Clean Documentation References ✅
**Completed Tasks:**
- ✅ **In `discovery-service/README.md`:**
  - ✅ Removed references to deprecated `simple_main` module
  - ✅ Removed Docker CMD modification instructions
  - ✅ Removed legacy Phase 4 deployment documentation sections
  - ✅ Updated to focus only on unified configuration approach

- ✅ **In `bootstrap-image/README.md`:**
  - ✅ Removed "Legacy Methods" section entirely
  - ✅ Removed "Build Methods Comparison" table
  - ✅ Removed "Method 1: Parameter-based Build Script" section
  - ✅ Removed "Method 2: Direct Nix Commands" section
  - ✅ Removed all references to `generate_psk.py`
  - ✅ Removed "Direct Nix Commands Reference" section
  - ✅ Updated development workflow to use unified configuration
  - ✅ Simplified cross-platform building explanation
  - ✅ Updated file overview to reflect current structure

#### Phase 1.3: Remove Complex Documentation Files ✅
**Result:** No complex documentation files found (already cleaned or never created)

**Phase 1 Result:** Successfully streamlined documentation to show only the unified configuration approach, eliminating choice paralysis and deprecated references.

---

## 🔄 PENDING PHASES

---

## Phase 3: Documentation Overhaul (Low Risk)

### Phase 3.1: Simplify Bootstrap Image README
**Status:** NOT STARTED
**Priority:** HIGH

**Task:** Create new streamlined `bootstrap-image/README.md` with ONLY:
- [ ] Prerequisites section (link to CachyOS setup guide)
- [ ] Two-step build process (setup → build)
- [ ] Flash and deploy instructions
- [ ] Basic troubleshooting
- [ ] Security warnings
- [ ] Remove all legacy methods, comparison tables, and complex examples

### Phase 3.2: Simplify Discovery Service README
**Status:** NOT STARTED
**Priority:** HIGH

**Tasks:**
- [ ] Remove all sections about `generate_psk.py` usage
- [ ] Remove legacy config directory setup instructions
- [ ] Remove manual configuration editing references
- [ ] Remove multiple deployment method discussions
- [ ] Focus only on unified configuration approach

### Phase 3.3: Consolidate Troubleshooting Documentation
**Status:** NOT STARTED
**Priority:** MEDIUM

**Keep Only:**
- [ ] `docs/cachyos-setup.md` (essential for new users)
- [ ] `docs/bootstrap-troubleshooting.md` (CachyOS-specific issues)

**Remove:**
- [ ] `docs/bootstrap-walkthrough.md` (too verbose)
- [ ] Redundant troubleshooting sections in component READMEs

### Phase 3.4: Update Main Project README
**Status:** NOT STARTED
**Priority:** MEDIUM

**Tasks:**
- [ ] Remove references to deleted files (generate_psk.py, etc.)
- [ ] Simplify "Quick Start" section to show only unified approach
- [ ] Remove alternative setup methods
- [ ] Focus on two-step process: configure → build

### Phase 3.5: Update Documentation Hub
**Status:** NOT STARTED
**Priority:** LOW

**Tasks:**
- [ ] Update `docs/README.md` references to reflect simplified structure
- [ ] Remove links to deleted documentation files
- [ ] Remove "planned documentation" sections for deleted files

---

## Implementation Guidelines

### Rules for All Phases:
1. **DO NOT MODIFY**: Any `.nix` files, `build.sh`, or core build infrastructure
2. **PRESERVE**: All working functionality
3. **MAINTAIN**: Security warnings and best practices
4. **TEST**: All documentation links work after changes

### Success Criteria:
- [ ] New users see only ONE way to build images (unified configuration)
- [ ] No broken links or references to deleted files
- [ ] Simplified README files focus on essential information only
- [ ] Clear prerequisite documentation for CachyOS users
- [ ] Consistent messaging about unified approach across all docs

---

## Next Steps

**For Claude Code Implementation:**

1. **Start with Phase 1.2** (Clean Documentation References) - highest impact, low risk
2. **Continue with Phase 3.1** (Simplify Bootstrap README) - most user-facing
3. **Proceed systematically** through remaining phases
4. **Test thoroughly** that all links and references work after each phase

**Commands to Continue:**
```bash
# To continue cleanup, provide this TODO.md to Claude Code with instructions like:
# "Implement Phase 1.2: Clean Documentation References"
# "Implement Phase 3.1: Simplify Bootstrap Image README"
```

---

## Benefits After Completion

- **70% reduction** in cognitive load for new users
- **Single path** to success (no choice paralysis)
- **Faster onboarding** with streamlined documentation
- **Easier maintenance** with fewer files to keep updated
- **Consistent messaging** across all documentation