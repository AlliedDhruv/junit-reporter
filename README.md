# JUnit Test Reporter Action

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-JUnit%20Reporter-blue?logo=github)](https://github.com/marketplace/actions/junit-test-reporter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Parse JUnit XML test results and display them in a beautiful, customizable markdown format with GitHub annotations.

## Features

- 📊 **Custom Summary** - Total, passed, failed, errors, skipped with pass rate
- ❌ **Detailed Failures** - Full exception messages and stack traces
- ✅ **Collapsible Results** - Clean report, expand to see all tests
- 🔔 **GitHub Annotations** - Automatic failure notifications in PR checks
- 💬 **PR Comments** - Auto-comment results on pull requests
- ⏱️ **Execution Times** - Track each test's duration
- 🎨 **Fully Customizable** - Modify colors, format, and content

## Usage

### Basic
```yaml
- name: Report Test Results
  if: always()
  uses: YOUR-USERNAME/junit-reporter@v1
  with:
    junit-xml-path: './target/surefire-reports/TEST-*.xml'
```

### With PR Comments
```yaml
- name: Report Test Results
  if: always()
  id: test-results
  uses: YOUR-USERNAME/junit-reporter@v1
  with:
    junit-xml-path: './target/surefire-reports/TEST-*.xml'
    annotation-style: 'notice'

- name: Comment PR
  if: always() && github.event_name == 'pull_request'
  uses: actions/github-script@v7
  with:
    script: |
      const fs = require('fs');
      const report = fs.readFileSync('junit-report.md', 'utf8');
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: report
      });
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `junit-xml-path` | Path to JUnit XML file(s) | Yes | `./test-results.xml` |
| `annotation-style` | Style for annotations (notice/warning/error) | No | `notice` |

## Outputs

| Output | Description |
|--------|-------------|
| `test-summary` | Test results summary as JSON |
| `results-markdown` | Test results as markdown |

## Supported Frameworks

- ✅ Maven (JUnit)
- ✅ Gradle (JUnit)
- ✅ Jest (jest-junit)
- ✅ pytest (pytest-junit)
- ✅ Any framework generating JUnit XML

## Examples

### Maven
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v3
        with:
          java-version: '11'
      
      - name: Run Tests
        run: mvn clean test
        continue-on-error: true
      
      - name: Report Results
        if: always()
        uses: YOUR-USERNAME/junit-reporter@v1
        with:
          junit-xml-path: './target/surefire-reports/TEST-*.xml'
```

### Gradle
```yaml
- name: Run Tests
  run: ./gradlew test
  continue-on-error: true

- name: Report Results
  if: always()
  uses: YOUR-USERNAME/junit-reporter@v1
  with:
    junit-xml-path: './build/test-results/test/TEST-*.xml'
```

### Jest
```yaml
- name: Run Tests
  run: npm test -- --reporters=jest-junit
  continue-on-error: true

- name: Report Results
  if: always()
  uses: YOUR-USERNAME/junit-reporter@v1
  with:
    junit-xml-path: './junit.xml'
```

## Sample Output

### Summary Section