import re

with open('lib/main.dart', 'r') as f:
    lines = f.readlines()

# Find the _facts list and convert problematic single-quoted strings to double-quoted
in_facts = False
for i in range(len(lines)):
    if '_facts = [' in lines[i]:
        in_facts = True
    if in_facts and lines[i].strip() == '];':
        in_facts = False
        break
    if not in_facts:
        continue

    line = lines[i]
    # Match title: 'text with apostrophe' patterns
    # or body strings starting with '...'
    stripped = line.strip()

    # Count single quotes - if more than 2, there's an apostrophe problem
    if stripped.count("'") > 2:
        # Replace the outer single quotes with double quotes
        # Pattern: find 'content with apostrophes',
        # We need to be smart about this
        # Replace outermost single quotes with double quotes for title/body values
        new_line = line.replace("'", '"', 1)  # First quote
        # Find the last quote before comma or end
        # Reverse find and replace the last single quote
        idx = new_line.rfind("'")
        if idx >= 0:
            new_line = new_line[:idx] + '"' + new_line[idx+1:]
        lines[i] = new_line
        print(f"Fixed line {i+1}: {lines[i].strip()[:80]}")

with open('lib/main.dart', 'w') as f:
    f.writelines(lines)

print("Done!")
