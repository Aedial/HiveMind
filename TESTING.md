# 🧪 Testing for HiveMind

HiveMind uses **pre-commit hooks** to automatically run tests before each commit, ensuring code quality and preventing regressions.

## Quick Setup

### 1. Install Pre-commit Hooks:

**Windows:**
```cmd
setup-precommit.bat
```

**Linux/Mac/WSL:**
```bash
./setup-precommit.sh
```

**Manual Setup:**
```bash
pip install pre-commit
pre-commit install
```

### 2. That's it! 
Tests now run automatically before every commit.

## Usage

### 🚀 **Automatic** (Recommended):
```bash
git add <files>
git commit -m "Your changes"
# Tests run automatically before commit!
```

### 🔧 **Manual Testing**:
```bash
# Run all tests on all files
pre-commit run --all-files

# Run tests only on staged files
pre-commit run

# Run performance tests (manual stage)
pre-commit run --hook-stage manual --all-files

# Skip pre-commit for emergency commits
git commit --no-verify -m "Emergency fix"
```

## What Gets Tested

### ✅ **Every Commit** (automatic):
1. **Lua Syntax Check** - Validates all `.lua` files compile correctly
2. **Planning Tests** - Tests breeding path calculation for 15+ species
3. **Execution Tests** - Tests executeBreedingTree with mock functions
4. **Error Handling** - Tests failure scenarios and recovery
5. **Example Usage** - Validates `test_example.lua` works correctly
6. **File Quality** - Trailing whitespace, file endings, YAML validation

### ⚡ **Manual Stage** (run with `--hook-stage manual`):
7. **Performance Tests** - Timing analysis for complex breeding chains
8. **Stress Tests** - Extreme multi-mod breeding scenarios

### 🚫 **Protections**:
- Blocks large files (>1MB)
- Detects merge conflicts
- Validates YAML/JSON files

## Test Artifacts

All tests generate detailed analysis files in the `Artifacts/` folder:

- **`*_analysis.txt`** - Complete breeding trees with dependency visualization
- **`*_execution_*.txt`** - Detailed execution logs with failure analysis

## Integration with CI

Pre-commit hooks run **the same core tests** as GitHub Actions:

- ✅ **Before Commit**: Auto-run prevents broken commits
- ✅ **CI Consistency**: Same test logic locally and remotely  
- ✅ **Fast Feedback**: Catch issues in seconds, not minutes

## Advanced Usage

### Bypass Pre-commit (Emergency Only):
```bash
git commit --no-verify -m "Emergency hotfix"
```

### Update Hooks:
```bash
pre-commit autoupdate
```

### Run Specific Hook:
```bash
pre-commit run lua-syntax-check
pre-commit run hivemind-planning-tests
```

### Debug Hook Issues:
```bash
pre-commit run --verbose --all-files
```

## Requirements

- **Pre-commit** installed (`pip install pre-commit`)
- **Lua 5.3+** installed and in PATH
- Run from the HiveMind project root directory

## Troubleshooting

### "pre-commit command not found":
```bash
pip install pre-commit
# or
pip3 install pre-commit
```

### "Lua not found":
- **Linux**: `apt install lua5.3`
- **macOS**: `brew install lua`  
- **Windows**: Download from [lua.org](https://www.lua.org)

### "Hook failed":
```bash
# See detailed error output
pre-commit run --verbose --all-files

# Reset and reinstall hooks
pre-commit uninstall
pre-commit install
```

### Skip problematic hook temporarily:
```bash
SKIP=hivemind-planning-tests git commit -m "Work in progress"
```

---

💡 **Pro tip**: Pre-commit hooks make your workflow bulletproof - they catch issues instantly and ensure every commit is tested!
