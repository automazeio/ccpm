---
allowed-tools: Bash, Read, Write, LS
---

# Prime Testing Environment

This command prepares the testing environment by detecting the test framework, validating dependencies, and configuring the test-runner agent for optimal test execution.

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

### 1. Test Framework Detection

**JavaScript/Node.js:**
- Check package.json for test scripts: `grep -E '"test"|"spec"|"jest"|"mocha"' package.json 2>/dev/null`
- Look for test config files: `ls -la jest.config.* mocha.opts .mocharc.* 2>/dev/null`
- Check for test directories: `find . -type d \( -name "test" -o -name "tests" -o -name "__tests__" -o -name "spec" \) -maxdepth 3 2>/dev/null`

**Python:**
- Check for pytest: `find . -name "pytest.ini" -o -name "conftest.py" -o -name "setup.cfg" 2>/dev/null | head -5`
- Check for unittest: `find . -path "*/test*.py" -o -path "*/test_*.py" 2>/dev/null | head -5`
- Check requirements: `grep -E "pytest|unittest|nose" requirements.txt 2>/dev/null`

**Rust:**
- Check for Cargo tests: `grep -E '\[dev-dependencies\]' Cargo.toml 2>/dev/null`
- Look for test modules: `find . -name "*.rs" -exec grep -l "#\[cfg(test)\]" {} \; 2>/dev/null | head -5`

**Go:**
- Check for test files: `find . -name "*_test.go" 2>/dev/null | head -5`
- Check go.mod exists: `test -f go.mod && echo "Go module found"`

**PHP:**
- Check for PHPUnit: `find . -name "phpunit.xml" -o -name "phpunit.xml.dist" -o -name "composer.json" -exec grep -l "phpunit" {} \; 2>/dev/null`
- Check for Pest: `find . -name "composer.json" -exec grep -l "pestphp/pest" {} \; 2>/dev/null`
- Look for test directories: `find . -type d \( -name "tests" -o -name "test" \) -maxdepth 3 2>/dev/null`

**C#/.NET:**
- Check for MSTest/NUnit/xUnit: `find . -name "*.csproj" -exec grep -l -E "Microsoft\.NET\.Test|NUnit|xunit" {} \; 2>/dev/null`
- Check for test projects: `find . -name "*.csproj" -exec grep -l "<IsTestProject>true</IsTestProject>" {} \; 2>/dev/null`
- Look for solution files: `find . -name "*.sln" 2>/dev/null`

**Java:**
- Check for JUnit (Maven): `find . -name "pom.xml" -exec grep -l "junit" {} \; 2>/dev/null`
- Check for JUnit (Gradle): `find . -name "build.gradle" -o -name "build.gradle.kts" -exec grep -l -E "junit|testImplementation" {} \; 2>/dev/null`
- Look for test directories: `find . -path "*/src/test/java" -type d 2>/dev/null`

**Kotlin:**
- Check for Kotlin tests: `find . -name "build.gradle.kts" -exec grep -l -E "kotlin.*test|spek" {} \; 2>/dev/null`
- Look for Kotlin test files: `find . -name "*Test.kt" -o -name "*Spec.kt" 2>/dev/null | head -5`

**Swift:**
- Check for XCTest: `find . -name "Package.swift" -exec grep -l "XCTest" {} \; 2>/dev/null`
- Check for Xcode test targets: `find . -name "*.xcodeproj" -o -name "*.xcworkspace" 2>/dev/null`
- Look for test files: `find . -name "*Test.swift" -o -name "*Tests.swift" 2>/dev/null | head -5`

**Dart/Flutter:**
- Check for Flutter tests: `test -f pubspec.yaml && grep -q "flutter_test" pubspec.yaml && echo "Flutter test found"`
- Look for test files: `find . -name "*_test.dart" 2>/dev/null | head -5`
- Check for test directory: `test -d test && echo "Test directory found"`

**C/C++:**
- Check for GoogleTest: `find . -name "CMakeLists.txt" -exec grep -l -E "gtest|GTest" {} \; 2>/dev/null`
- Check for Catch2: `find . -name "CMakeLists.txt" -exec grep -l "Catch2" {} \; 2>/dev/null`
- Look for test files: `find . -name "*test.cpp" -o -name "*test.c" -o -name "test_*.cpp" 2>/dev/null | head -5`

**Ruby:**
- Check for RSpec: `find . -name ".rspec" -o -name "spec_helper.rb" 2>/dev/null`
- Check for Minitest: `find . -name "Gemfile" -exec grep -l "minitest" {} \; 2>/dev/null`
- Look for test files: `find . -name "*_spec.rb" -o -name "*_test.rb" 2>/dev/null | head -5`

### 2. Test Environment Validation

If no test framework detected:
- Tell user: "⚠️ No test framework detected. Please specify your testing setup."
- Ask: "What test command should I use? Examples:
  - Node.js: npm test, pnpm test, yarn test
  - Python: pytest, python -m unittest, poetry run pytest
  - PHP: ./vendor/bin/phpunit, composer test
  - Java: mvn test, ./gradlew test
  - C#/.NET: dotnet test
  - Swift: swift test
  - Dart/Flutter: flutter test
  - C/C++: ctest, make test
  - Ruby: bundle exec rspec, rake test
  - Go: go test ./...
  - Rust: cargo test"
- Store response for future use

### 3. Dependency Check

**For detected framework:**
- Node.js: Run `npm list --depth=0 2>/dev/null | grep -E "jest|mocha|chai|jasmine"`
- Python: Run `pip list 2>/dev/null | grep -E "pytest|unittest|nose"`
- PHP: Run `composer show 2>/dev/null | grep -E "phpunit|pestphp"`
- Java (Maven): Run `mvn dependency:list 2>/dev/null | grep -E "junit|testng"`
- Java (Gradle): Run `./gradlew dependencies --configuration testImplementation 2>/dev/null | grep -E "junit|testng"`
- C#/.NET: Run `dotnet list package 2>/dev/null | grep -E "Microsoft.NET.Test|NUnit|xunit"`
- Ruby: Run `bundle list 2>/dev/null | grep -E "rspec|minitest"`
- Dart/Flutter: Run `flutter pub deps 2>/dev/null | grep flutter_test`
- Verify test dependencies are installed

If dependencies missing:
- Tell user: "❌ Test dependencies not installed"
- Suggest installation commands:
  - Node.js: "npm install" or "pnpm install"
  - Python: "pip install -r requirements.txt" or "poetry install"
  - PHP: "composer install"
  - Java (Maven): "mvn clean install"
  - Java (Gradle): "./gradlew build"
  - C#/.NET: "dotnet restore"
  - Ruby: "bundle install"
  - Dart/Flutter: "flutter pub get"
  - Swift: "swift package resolve"
  - C/C++: "mkdir build && cd build && cmake .. && make"

## Instructions

### 1. Framework-Specific Configuration

Based on detected framework, create test configuration:

#### JavaScript/Node.js (Jest)
```yaml
framework: jest
test_command: npm test
test_directory: __tests__
config_file: jest.config.js
options:
  - --verbose
  - --no-coverage
  - --runInBand
environment:
  NODE_ENV: test
```

#### JavaScript/Node.js (Mocha)
```yaml
framework: mocha
test_command: npm test
test_directory: test
config_file: .mocharc.js
options:
  - --reporter spec
  - --recursive
  - --bail
environment:
  NODE_ENV: test
```

#### Python (Pytest)
```yaml
framework: pytest
test_command: pytest
test_directory: tests
config_file: pytest.ini
options:
  - -v
  - --tb=short
  - --strict-markers
environment:
  PYTHONPATH: .
```

#### Rust
```yaml
framework: cargo
test_command: cargo test
test_directory: tests
config_file: Cargo.toml
options:
  - --verbose
  - --nocapture
environment: {}
```

#### Go
```yaml
framework: go
test_command: go test
test_directory: .
config_file: go.mod
options:
  - -v
  - ./...
environment: {}
```

#### PHP (PHPUnit)
```yaml
framework: phpunit
test_command: ./vendor/bin/phpunit
test_directory: tests
config_file: phpunit.xml
options:
  - --verbose
  - --testdox
environment:
  APP_ENV: testing
```

#### C#/.NET
```yaml
framework: dotnet
test_command: dotnet test
test_directory: .
config_file: *.sln
options:
  - --verbosity normal
  - --logger console
environment: {}
```

#### Java (Maven)
```yaml
framework: maven
test_command: mvn test
test_directory: src/test/java
config_file: pom.xml
options:
  - -Dtest.verbose=true
environment: {}
```

#### Java (Gradle)
```yaml
framework: gradle
test_command: ./gradlew test
test_directory: src/test/java
config_file: build.gradle
options:
  - --info
  - --continue
environment: {}
```

#### Kotlin
```yaml
framework: kotlin
test_command: ./gradlew test
test_directory: src/test/kotlin
config_file: build.gradle.kts
options:
  - --info
environment: {}
```

#### Swift
```yaml
framework: swift
test_command: swift test
test_directory: Tests
config_file: Package.swift
options:
  - --verbose
environment: {}
```

#### Dart/Flutter
```yaml
framework: flutter
test_command: flutter test
test_directory: test
config_file: pubspec.yaml
options:
  - --verbose
environment: {}
```

#### C/C++ (CMake)
```yaml
framework: cmake
test_command: ctest
test_directory: build
config_file: CMakeLists.txt
options:
  - --verbose
  - --output-on-failure
environment: {}
```

#### Ruby (RSpec)
```yaml
framework: rspec
test_command: bundle exec rspec
test_directory: spec
config_file: .rspec
options:
  - --format documentation
  - --color
environment:
  RAILS_ENV: test
```

### 2. Test Discovery

Scan for test files:
- Count total test files found
- Identify test naming patterns used
- Note any test utilities or helpers
- Check for test fixtures or data

```bash
# Examples by language:

# JavaScript/TypeScript
find . -path "*/node_modules" -prune -o -name "*.test.js" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.spec.ts" | wc -l

# Python
find . -name "test_*.py" -o -name "*_test.py" -o -path "*/tests/*.py" | wc -l

# PHP
find . -path "*/tests/*" -name "*.php" -o -name "*Test.php" | wc -l

# Java/Kotlin
find . -path "*/src/test/*" -name "*Test.java" -o -name "*Test.kt" | wc -l

# C#/.NET
find . -name "*Test.cs" -o -name "*Tests.cs" | wc -l

# Swift
find . -name "*Test.swift" -o -name "*Tests.swift" | wc -l

# Dart/Flutter
find . -name "*_test.dart" | wc -l

# C/C++
find . -name "*test.cpp" -o -name "*test.c" -o -name "test_*.cpp" | wc -l

# Ruby
find . -name "*_spec.rb" -o -name "*_test.rb" | wc -l

# Go
find . -name "*_test.go" | wc -l

# Rust
find . -name "*.rs" -exec grep -l "#\[cfg(test)\]" {} \; | wc -l
```

### 3. Create Test Runner Configuration

Create `.claude/testing-config.md` with discovered information:

```markdown
---
framework: {detected_framework}
test_command: {detected_command}
created: [Use REAL datetime from: date -u +"%Y-%m-%dT%H:%M:%SZ"]
---

# Testing Configuration

## Framework
- Type: {framework_name}
- Version: {framework_version}
- Config File: {config_file_path}

## Test Structure
- Test Directory: {test_dir}
- Test Files: {count} files found
- Naming Pattern: {pattern}

## Commands
- Run All Tests: `{full_test_command}`
- Run Specific Test: `{specific_test_command}`
- Run with Debugging: `{debug_command}`

## Environment
- Required ENV vars: {list}
- Test Database: {if applicable}
- Test Servers: {if applicable}

## Test Runner Agent Configuration
- Use verbose output for debugging
- Run tests sequentially (no parallel)
- Capture full stack traces
- No mocking - use real implementations
- Wait for each test to complete
```

### 4. Configure Test-Runner Agent

Prepare agent context based on framework:

```markdown
# Test-Runner Agent Configuration

## Project Testing Setup
- Framework: {framework}
- Test Location: {directories}
- Total Tests: {count}
- Last Run: Never

## Execution Rules
1. Always use the test-runner agent from `.claude/agents/test-runner.md`
2. Run with maximum verbosity for debugging
3. No mock services - use real implementations
4. Execute tests sequentially - no parallel execution
5. Capture complete output including stack traces
6. If test fails, analyze test structure before assuming code issue
7. Report detailed failure analysis with context

## Test Command Templates
- Full Suite: `{full_command}`
- Single File: `{single_file_command}`
- Pattern Match: `{pattern_command}`
- Watch Mode: `{watch_command}` (if available)

## Common Issues to Check
- Environment variables properly set
- Test database/services running
- Dependencies installed
- Proper file permissions
- Clean test state between runs
```

### 5. Validation Steps

After configuration:
- Try running a simple test to validate setup
- Check if test command works: `{test_command} --version` or equivalent
- Verify test files are discoverable
- Ensure no permission issues

### 6. Output Summary

```
🧪 Testing Environment Primed

🔍 Detection Results:
  ✅ Framework: {framework_name} {version}
  ✅ Test Files: {count} files in {directories}
  ✅ Config: {config_file}
  ✅ Dependencies: All installed

📋 Test Structure:
  - Pattern: {test_file_pattern}
  - Directories: {test_directories}
  - Utilities: {test_helpers}

🤖 Agent Configuration:
  ✅ Test-runner agent configured
  ✅ Verbose output enabled
  ✅ Sequential execution set
  ✅ Real services (no mocks)

⚡ Ready Commands:
  - Run all tests: /testing:run
  - Run specific: /testing:run {test_file}
  - Run pattern: /testing:run {pattern}

💡 Tips:
  - Always run tests with verbose output
  - Check test structure if tests fail
  - Use real services, not mocks
  - Let each test complete fully
```

### 7. Error Handling

**Common Issues:**

**No Framework Detected:**
- Message: "⚠️ No test framework found"
- Solution: "Please specify test command manually"
- Store user's response for future use

**Missing Dependencies:**
- Message: "❌ Test framework not installed"
- Solution: "Install dependencies first based on project type:"
  - Node.js: "npm install" or "pnpm install"
  - Python: "pip install -r requirements.txt" or "poetry install"
  - PHP: "composer install"
  - Java: "mvn clean install" or "./gradlew build"
  - C#/.NET: "dotnet restore"
  - Ruby: "bundle install"
  - Dart/Flutter: "flutter pub get"

**No Test Files:**
- Message: "⚠️ No test files found"
- Solution: "Create tests first or check test directory location"

**Permission Issues:**
- Message: "❌ Cannot access test files"
- Solution: "Check file permissions"

### 8. Save Configuration

If successful, save configuration for future sessions:
- Store in `.claude/testing-config.md`
- Include all discovered settings
- Update on subsequent runs if changes detected

## Important Notes

- **Always detect** rather than assume test framework
- **Validate dependencies** before claiming ready
- **Configure for debugging** - verbose output is critical
- **No mocking** - use real services for accurate testing
- **Sequential execution** - avoid parallel test issues
- **Store configuration** for consistent future runs

$ARGUMENTS
