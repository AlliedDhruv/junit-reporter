#!/bin/bash

# Parse JUnit XML and generate markdown report
# Usage: ./parse-junit.sh <path-to-junit.xml> [annotation-style]

JUNIT_FILE="$1"
ANNOTATION_STYLE="${2:-notice}"

# Check if file exists
if [ ! -f "$JUNIT_FILE" ]; then
    echo "::error::JUnit XML file not found: $JUNIT_FILE"
    exit 1
fi

# Export variables for Python
export JUNIT_FILE
export ANNOTATION_STYLE

# Run Python with heredoc
python3 << 'PYTHON_SCRIPT'
import xml.etree.ElementTree as ET
import sys
import json
import os
import io

# ✅ FORCE UTF-8 for Windows stdout
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Safe print (extra protection)
def safe_print(msg):
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode('utf-8', errors='ignore').decode('utf-8'))

# Get env variables
junit_file = os.environ.get('JUNIT_FILE')
annotation_style = os.environ.get('ANNOTATION_STYLE', 'notice')

if not junit_file:
    safe_print("::error::JUnit_FILE not set")
    sys.exit(1)

# Parse XML
try:
    tree = ET.parse(junit_file)
    root = tree.getroot()
except Exception as e:
    safe_print(f"::error::Failed to parse JUnit XML: {e}")
    sys.exit(1)

# Counters
total_tests = 0
passed_tests = 0
failed_tests = 0
skipped_tests = 0
errors_tests = 0
total_time = 0.0

passed_cases = []
failed_cases = []
error_cases = []

# Parse test cases
for testsuite in root.findall('.//testsuite'):
    for testcase in testsuite.findall('testcase'):
        total_tests += 1
        test_name = testcase.get('name', 'Unknown')
        test_class = testcase.get('classname', 'Unknown')
        test_time = float(testcase.get('time', 0))

        failure = testcase.find('failure')
        error = testcase.find('error')
        skipped = testcase.find('skipped')

        if failure is not None:
            failed_tests += 1
            failed_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time,
                'message': failure.get('message', ''),
                'details': (failure.text or '')[:500]
            })
        elif error is not None:
            errors_tests += 1
            error_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time,
                'message': error.get('message', ''),
                'details': (error.text or '')[:500]
            })
        elif skipped is not None:
            skipped_tests += 1
        else:
            passed_tests += 1
            passed_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time
            })

        total_time += test_time

# Generate Markdown
markdown = []
markdown.append("# 📊 Test Results Report\n\n")
markdown.append("## Summary\n")
markdown.append("|Metric|Count|\n")
markdown.append("|---|---|\n")
markdown.append(f"|Total Tests|{total_tests}|\n")
markdown.append(f"|✅ Passed|{passed_tests}|\n")
markdown.append(f"|❌ Failed|{failed_tests}|\n")
markdown.append(f"|⚠️ Errors|{errors_tests}|\n")
markdown.append(f"|⊘ Skipped|{skipped_tests}|\n")
markdown.append(f"|⏱️ Total Time|{total_time:.2f}s|\n\n")

if total_tests > 0:
    pass_rate = (passed_tests / total_tests) * 100
    markdown.append(f"**Pass Rate:** {pass_rate:.1f}%\n\n")

# Failed tests
if failed_cases or error_cases:
    markdown.append("---\n## ❌ Failed Tests\n\n")
    for case in failed_cases:
        markdown.append(f"### {case['class']}.{case['name']} ({case['time']:.3f}s)\n")
        markdown.append(f"**Message:** {case['message']}\n")
        if case['details']:
            markdown.append(f"```\n{case['details']}\n```\n")
        markdown.append("\n")

    for case in error_cases:
        markdown.append(f"### {case['class']}.{case['name']} ({case['time']:.3f}s)\n")
        markdown.append(f"**Error:** {case['message']}\n")
        if case['details']:
            markdown.append(f"```\n{case['details']}\n```\n")
        markdown.append("\n")

# Passed tests (collapsed)
if passed_cases:
    markdown.append("---\n<details>\n")
    markdown.append(f"<summary>✅ Passed Tests ({len(passed_cases)})</summary>\n\n")
    for case in passed_cases[:10]:
        markdown.append(f"- `{case['class']}.{case['name']}` ({case['time']:.3f}s)\n")
    if len(passed_cases) > 10:
        markdown.append(f"\n... and {len(passed_cases) - 10} more\n")
    markdown.append("\n</details>\n")

# ✅ Write file with UTF-8
with open('junit-report.md', 'w', encoding='utf-8') as f:
    f.write(''.join(markdown))

# ✅ GitHub-style logs
safe_print("::group::Test Results")

for case in failed_cases[:5]:
    safe_print(f"::error::Failed: {case['name']}")

for case in error_cases[:5]:
    safe_print(f"::error::Error: {case['name']}")

safe_print(f"::notice::Tests: {passed_tests}✅ {failed_tests}❌ {errors_tests}⚠️")
safe_print("::endgroup::")

# ✅ Summary output (NEW GitHub Actions format)
summary = {
    "total": total_tests,
    "passed": passed_tests,
    "failed": failed_tests,
    "errors": errors_tests,
    "skipped": skipped_tests,
    "time": round(total_time, 2),
    "passRate": round((passed_tests / total_tests * 100) if total_tests > 0 else 0, 1)
}

github_output = os.environ.get("GITHUB_OUTPUT")
if github_output:
    with open(github_output, "a") as f:
        f.write(f"summary={json.dumps(summary)}\n")

PYTHON_SCRIPT

# Final check
if [ -f "junit-report.md" ]; then
    echo "✅ Report generated"
else
    echo "::error::Report not generated"
    exit 1
fi