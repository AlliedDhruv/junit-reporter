#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

JUNIT_FILE="$1"
ANNOTATION_STYLE="${2:-notice}"

# Check if file exists
if [ ! -f "$JUNIT_FILE" ]; then
    echo "::error::JUnit XML file not found: $JUNIT_FILE"
    exit 1
fi

# Initialize variables
total_tests=0
passed_tests=0
failed_tests=0
skipped_tests=0
errors_tests=0
total_time=0

# Temporary files for storing results
passed_file=$(mktemp)
failed_file=$(mktemp)
markdown_file=$(mktemp)

# Parse XML using grep and sed (works on any system)
# Extract test suite info
suite_info=$(grep -oP 'tests="\K[0-9]+|failures="\K[0-9]+|errors="\K[0-9]+|skipped="\K[0-9]+|time="\K[0-9.]+' "$JUNIT_FILE" | head -5)

# Better approach: use Python for more reliable XML parsing
python3 << 'PYTHON_SCRIPT'
import xml.etree.ElementTree as ET
import sys
import json
import os

junit_file = sys.argv[1]
annotation_style = sys.argv[2] if len(sys.argv) > 2 else 'notice'

try:
    tree = ET.parse(junit_file)
    root = tree.getroot()
except Exception as e:
    print(f"::error::Failed to parse JUnit XML: {e}")
    sys.exit(1)

# Initialize counters
total_tests = 0
passed_tests = 0
failed_tests = 0
skipped_tests = 0
errors_tests = 0
total_time = 0.0

passed_cases = []
failed_cases = []
error_cases = []
skipped_cases = []

# Parse test suites
for testsuite in root.findall('.//testsuite'):
    suite_name = testsuite.get('name', 'Unknown')
    suite_time = float(testsuite.get('time', 0))
    
    for testcase in testsuite.findall('testcase'):
        total_tests += 1
        test_name = testcase.get('name', 'Unknown')
        test_class = testcase.get('classname', 'Unknown')
        test_time = float(testcase.get('time', 0))
        
        # Check test status
        failure = testcase.find('failure')
        error = testcase.find('error')
        skipped = testcase.find('skipped')
        
        if failure is not None:
            failed_tests += 1
            failure_msg = failure.get('message', '')
            failure_text = failure.text or ''
            failed_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time,
                'message': failure_msg,
                'details': failure_text[:500]  # Truncate for readability
            })
        elif error is not None:
            errors_tests += 1
            error_msg = error.get('message', '')
            error_text = error.text or ''
            error_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time,
                'message': error_msg,
                'details': error_text[:500]
            })
        elif skipped is not None:
            skipped_tests += 1
            skipped_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time,
                'reason': skipped.get('message', 'No reason provided')
            })
        else:
            passed_tests += 1
            passed_cases.append({
                'class': test_class,
                'name': test_name,
                'time': test_time
            })
        
        total_time += test_time

# Create markdown report
markdown = []
markdown.append("# 📊 Test Results Report\n")
markdown.append("---\n")

# Summary section
markdown.append("## Summary\n")
markdown.append(f"| Metric | Count |\n")
markdown.append(f"|--------|-------|\n")
markdown.append(f"| Total Tests | {total_tests} |\n")
markdown.append(f"| ✅ Passed | {passed_tests} |\n")
markdown.append(f"| ❌ Failed | {failed_tests} |\n")
markdown.append(f"| ⚠️ Errors | {errors_tests} |\n")
markdown.append(f"| ⊘ Skipped | {skipped_tests} |\n")
markdown.append(f"| ⏱️ Total Time | {total_time:.2f}s |\n\n")

# Calculate pass rate
if total_tests > 0:
    pass_rate = (passed_tests / total_tests) * 100
    markdown.append(f"**Pass Rate:** {pass_rate:.1f}%\n\n")

# Failed tests section
if failed_cases or error_cases:
    markdown.append("---\n")
    markdown.append("## ❌ Failed Tests\n\n")
    
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

# Passed tests section (collapsed)
if passed_cases:
    markdown.append("---\n")
    markdown.append("<details>\n")
    markdown.append("<summary>✅ Passed Tests ({})".format(len(passed_cases)))
    markdown.append("</summary>\n\n")
    
    for case in passed_cases[:10]:  # Show first 10
        markdown.append(f"- `{case['class']}.{case['name']}` ({case['time']:.3f}s)\n")
    
    if len(passed_cases) > 10:
        markdown.append(f"\n... and {len(passed_cases) - 10} more passed tests\n")
    
    markdown.append("\n</details>\n")

# Create GitHub annotations for failures
print("::group::Adding annotations for test failures")
for case in failed_cases[:5]:  # Limit to first 5
    annotation = f"Failed: {case['name']}"
    if case['message']:
        annotation += f" - {case['message']}"
    print(f"::{annotation_style}::{annotation}")

for case in error_cases[:5]:  # Limit to first 5
    annotation = f"Error: {case['name']}"
    if case['message']:
        annotation += f" - {case['message']}"
    print(f"::error::{annotation}")
print("::endgroup::")

# Output markdown to file
with open('junit-report.md', 'w') as f:
    f.write(''.join(markdown))

# Set outputs
print(f"::notice::Test Results: {passed_tests} passed, {failed_tests} failed, {errors_tests} errors, {skipped_tests} skipped")

# Output summary JSON
summary = {
    "total": total_tests,
    "passed": passed_tests,
    "failed": failed_tests,
    "errors": errors_tests,
    "skipped": skipped_tests,
    "time": round(total_time, 2),
    "passRate": round((passed_tests / total_tests * 100) if total_tests > 0 else 0, 1)
}

print(f"::set-output name=summary::{json.dumps(summary)}")
print(f"::set-output name=markdown::$(cat junit-report.md | base64 -w 0)")

PYTHON_SCRIPT

PYTHON_SCRIPT_EXIT=$?
exit $PYTHON_SCRIPT_EXIT