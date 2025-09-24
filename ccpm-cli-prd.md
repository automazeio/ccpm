# CCPM CLI Rewrite - Mini PRD

## Vision
Create a simple, cross-platform CLI tool that provides AI-agnostic access to CCPM functionality while maintaining backward compatibility with existing Claude Code workflows.

## Goals
- **AI Flexibility**: Support multiple AI providers (Claude, Codex, Gemini) with consistent syntax
- **Performance**: Skip AI for deterministic operations (status, list, search)
- **Simplicity**: Replace 23K+ lines of Python with ~100 lines of shell scripts
- **Cross-Platform**: Work identically on macOS, Linux, and Windows
- **Global Access**: Install once, use everywhere via PATH
- **Backward Compatible**: Existing `/pm:` commands in Claude continue to work

## Architecture

### Installation Structure
```
# Unix/Linux/macOS
~/.ccpm/
├── bin/
│   ├── ccpm           # Main executable
│   └── ccpm.bat       # Windows executable  
├── commands/pm/       # AI command templates
├── scripts/pm/        # Deterministic scripts (.sh + .bat)
└── rules/             # Shared rules and templates

# Windows  
%USERPROFILE%\.ccpm\
├── bin\
│   ├── ccpm.bat       # Main executable
│   └── ccpm           # Unix executable (for Git Bash)
├── commands\pm\       # AI command templates  
├── scripts\pm\        # Deterministic scripts (.sh + .bat)
└── rules\             # Shared rules and templates
```

### Command Syntax
```bash
# Explicit provider
ccpm claude pm:prd-new "my feature"
ccpm codex pm:status  
ccpm gemini pm:epic-list

# Default provider (CCPM_DEFAULT_PROVIDER or claude)
ccmp pm:prd-new "my feature"
ccpm pm:status

# Project initialization
ccpm init claude      # Copy ~/.ccpm/ → ./.claude/
ccpm init codex       # Copy ~/.ccpm/ → ./.claude/
```

### Command Routing Logic
```
ccpm [provider] command [args]
    ↓
Is command deterministic? (status, list, search, etc.)
    ↓ YES: Run ~/.ccpm/scripts/pm/command.{sh|bat} directly
    ↓ NO: Route to AI provider
         ↓
    claude < ~/.ccpm/commands/pm/command.md
    codex exec < ~/.ccmp/commands/pm/command.md --skip-git-repo-check  
    gemini -p < ~/.ccpm/commands/pm/command.md
```

## Cross-Platform Requirements

### Path Management
- **Unix/Linux/macOS**: `~/.ccpm/` (`$HOME/.ccpm/`)
- **Windows**: `%USERPROFILE%\.ccpm\`  
- **Git Bash on Windows**: Handle both Windows and Unix paths

### Executables
- **Unix**: `~/.ccpm/bin/ccpm` (bash script)
- **Windows**: `%USERPROFILE%\.ccpm\bin\ccpm.bat` (batch script)
- **Git Bash**: Use Unix version when available

### Script Compatibility
All deterministic commands need dual implementation:
- `~/.ccpm/scripts/pm/status.sh` (Unix)
- `%USERPROFILE%\.ccpm\scripts\pm\status.bat` (Windows)

### PATH Installation
- **Unix/macOS**: Add `~/.ccpm/bin` to `$PATH` via `.bashrc`/`.zshrc`
- **Windows**: Add `%USERPROFILE%\.ccpm\bin` to system PATH
- **Installer**: Automatically configure PATH during setup

## Technical Specifications

### Core Commands

**Deterministic** (run scripts directly):
- `pm:status` - Project status
- `pm:epic-list` - List epics  
- `pm:prd-list` - List PRDs
- `pm:search` - Search functionality
- `pm:validate` - System validation
- `pm:help` - Help documentation

**Agentic** (require AI):
- `pm:prd-new` - Create new PRD
- `pm:prd-parse` - Parse PRD to epic
- `pm:epic-decompose` - Break epic into tasks
- `pm:epic-sync` - Sync to GitHub
- `pm:issue-start` - Start working on issue

### Environment Variables
- `CCPM_DEFAULT_PROVIDER` - Default AI provider (claude|codex|gemini)
- `CCMP_HOME` - Override default installation directory
- `PATH` - Must include CCPM bin directory

### Installation Process
1. **Download**: Get latest ccpm release
2. **Extract**: Unpack to `~/.ccpm/` or `%USERPROFILE%\.ccpm\`
3. **PATH Setup**: Add bin directory to system PATH
4. **Verification**: `ccpm help` should work globally
5. **Project Init**: Run `ccpm init <provider>` in each project

### Error Handling
- Missing AI provider → Clear error message with install instructions
- Invalid command → Show available commands
- No .claude/ directory → Suggest `ccpm init <provider>`
- Provider not in PATH → Installation guidance

## Implementation Plan

### Phase 1: Core CLI
- [ ] Create cross-platform ccpm executable  
- [ ] Implement command routing logic
- [ ] Support claude provider only
- [ ] Basic installation script

### Phase 2: Multi-Provider Support
- [ ] Add codex provider support
- [ ] Add gemini provider support  
- [ ] Environment variable configuration
- [ ] Provider validation

### Phase 3: Cross-Platform Polish
- [ ] Windows .bat script implementations
- [ ] PATH management automation  
- [ ] Installation packaging (homebrew, scoop, etc.)
- [ ] Comprehensive testing on all platforms

### Phase 4: Migration
- [ ] Update documentation
- [ ] Deprecate old installation methods
- [ ] Community migration guide
- [ ] Close Python CLI PR with explanation

## Success Metrics
- [ ] Single global installation serves all projects
- [ ] Commands work identically across all platforms  
- [ ] AI provider switching takes <5 seconds
- [ ] Installation process takes <2 minutes
- [ ] Existing Claude users experience no breaking changes
- [ ] Performance: Deterministic commands <100ms, agentic commands unchanged

## Migration Path
1. **Backward Compatibility**: All existing `/pm:` commands continue working
2. **Gradual Adoption**: Users can try new CLI alongside existing workflow
3. **Documentation**: Update with new preferred syntax
4. **Community**: Provide migration examples and support

---

**Philosophy**: Keep It Simple, Stupid (KISS) - Replace complexity with clarity, maintain power through simplicity.
