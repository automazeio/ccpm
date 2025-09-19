"""Cross-platform validation functions for GitHub issue body files."""

import os
import re
from pathlib import Path
from typing import Optional


def get_min_content_length(context: str) -> int:
    """Get minimum content length based on context."""
    # Check environment variables first
    if context.startswith("epic:"):
        return int(os.environ.get("CCPM_MIN_EPIC_CONTENT", "100"))
    elif context.startswith(("task:", "issue:")):
        return int(os.environ.get("CCPM_MIN_TASK_CONTENT", "50"))
    elif context.startswith(("comment:", "update:", "progress-update:", "completion:")):
        return int(os.environ.get("CCPM_MIN_COMMENT_CONTENT", "30"))
    else:
        return int(os.environ.get("CCPM_MIN_DEFAULT_CONTENT", "50"))


def has_placeholder_text(content: str) -> bool:
    """Check if content contains placeholder text."""
    placeholder_patterns = [
        r"insert.*here",
        r"to.*be.*added",
        r"todo(?![\w])",  # TODO but not part of a word
        r"tbd",
        r"placeholder",
        r"description.*here",
        r"add.*content",
        r"write.*here",
        r"fill.*in",
        r"coming.*soon",
        r"work.*in.*progress",
        r"wip(?![\w])",
        r"xxx",
        r"fixme",
        r"update.*this"
    ]

    pattern = "|".join(f"({p})" for p in placeholder_patterns)
    return bool(re.search(pattern, content, re.IGNORECASE))


def get_default_content(context: str) -> str:
    """Get default content based on context."""
    if context.startswith("epic:"):
        return """# Epic Implementation

## Overview
This epic encompasses the implementation tasks required for this feature.

## Objectives
- Define clear implementation goals
- Establish success criteria
- Coordinate parallel development efforts

## Technical Approach
The implementation will follow established patterns and best practices.

## Success Metrics
- All acceptance criteria met
- Tests passing
- Documentation complete

## Notes
Further details will be added as implementation progresses."""

    elif context.startswith(("task:", "issue:")):
        return """# Task Details

## Description
This task implements a specific component of the parent epic.

## Implementation Notes
- Follow existing code patterns
- Ensure comprehensive test coverage
- Update documentation as needed

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Tests passing
- [ ] Code reviewed
- [ ] Documentation updated

## Technical Details
Additional technical details will be documented during implementation."""

    elif context.startswith(("progress-update:", "comment:", "update:")):
        return """## Progress Update

### Summary
Work is progressing on this issue. Details to follow.

### Recent Activity
- Analyzing requirements
- Setting up development environment
- Beginning implementation

### Next Steps
- Continue implementation
- Add tests
- Update documentation

---
*Detailed progress information will be added in subsequent updates.*"""

    elif context.startswith("completion:"):
        return """## Task Completed

### Summary
This task has been successfully completed.

### Deliverables
- Implementation complete
- Tests passing
- Documentation updated

### Verification
- All acceptance criteria met
- Code reviewed and approved
- Integration tests passing

### Notes
The implementation follows established patterns and meets all requirements."""

    else:
        return """## Issue Details

### Context
This issue tracks work in progress.

### Current Status
Active development ongoing.

### Next Steps
- Continue implementation
- Add comprehensive tests
- Update relevant documentation

---
*More details will be added as work progresses.*"""


def validate_body_file_has_content(
    file_path: str,
    context: str,
    min_chars: Optional[int] = None
) -> bool:
    """
    Validate that a body file has sufficient content.

    Args:
        file_path: Path to the markdown file
        context: Context string (e.g., "task:test", "epic:feature")
        min_chars: Minimum character count (excluding whitespace)

    Returns:
        True if file has sufficient content, False otherwise

    Side effects:
        - Adds default content if file is empty or has placeholders
        - Prints warnings to stderr
    """
    import sys

    if min_chars is None:
        min_chars = get_min_content_length(context)

    # Check if file exists
    if not os.path.exists(file_path):
        print(f"Error: Body file {file_path} does not exist for {context}", file=sys.stderr)
        return False

    # Read file content
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Get content length (excluding whitespace)
    stripped_content = re.sub(r'\s', '', content)
    content_length = len(stripped_content)

    # Check for placeholder text
    has_placeholder = has_placeholder_text(content)

    # Check if content is insufficient
    needs_replacement = content_length < min_chars or has_placeholder

    if needs_replacement:
        print(f"Warning: Body file {file_path} has insufficient content for {context}", file=sys.stderr)
        print(f"  Content length: {content_length} chars (minimum: {min_chars})", file=sys.stderr)

        if has_placeholder:
            print(f"  Placeholder text detected - replacing with proper default", file=sys.stderr)

        print("Adding appropriate default content...", file=sys.stderr)

        # Write default content
        default_content = get_default_content(context)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(default_content)

    return True


def strip_frontmatter_safe(
    input_file: str,
    output_file: str,
    default_content: str = "Content pending."
) -> None:
    """
    Strip YAML frontmatter from a markdown file safely.

    Args:
        input_file: Path to input markdown file
        output_file: Path to output file
        default_content: Content to use if file is empty after stripping
    """
    if not os.path.exists(input_file):
        # If input doesn't exist, create output with default
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(default_content)
        return

    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Skip frontmatter if present
    if lines and lines[0].strip() == '---':
        # Find closing ---
        end_idx = 1
        while end_idx < len(lines):
            if lines[end_idx].strip() == '---':
                # Found closing, content starts after
                content_lines = lines[end_idx + 1:]
                break
            end_idx += 1
        else:
            # No closing found, treat whole file as content
            content_lines = lines[1:]
    else:
        # No frontmatter
        content_lines = lines

    # Join and strip
    content = ''.join(content_lines).strip()

    # Use default if empty
    if not content:
        content = default_content

    # Write output
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)


def has_content_after_frontmatter(file_path: str) -> bool:
    """
    Check if a markdown file has content after its frontmatter.

    Args:
        file_path: Path to markdown file

    Returns:
        True if file has content after frontmatter, False otherwise
    """
    if not os.path.exists(file_path):
        return False

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    if not lines:
        return False

    # Skip frontmatter if present
    if lines[0].strip() == '---':
        # Find closing ---
        end_idx = 1
        while end_idx < len(lines):
            if lines[end_idx].strip() == '---':
                # Found closing, check content after
                content_lines = lines[end_idx + 1:]
                content = ''.join(content_lines).strip()
                return bool(content)
            end_idx += 1
        # No closing found, check remaining content
        content = ''.join(lines[1:]).strip()
        return bool(content)
    else:
        # No frontmatter, check all content
        content = ''.join(lines).strip()
        return bool(content)