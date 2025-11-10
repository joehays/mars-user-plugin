#!/bin/bash
# Simple concatenation script
set -euo pipefail

PROGRAMS_DIR="$HOME/dev/dotfiles/scripts/programs"
OUTPUT_FILE="/tmp/programs-concatenated.txt"

echo "=================================================================================" > "$OUTPUT_FILE"
echo "CONCATENATED PROGRAMS FILES" >> "$OUTPUT_FILE"
echo "=================================================================================" >> "$OUTPUT_FILE"
echo "Source: ${PROGRAMS_DIR}" >> "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "=================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

count=0
cd "$PROGRAMS_DIR"

# Process all files in the directory
for file in *; do
    # Skip if not a regular file
    if [ ! -f "$file" ]; then
        continue
    fi

    # Skip the concat scripts themselves
    if [[ "$file" == "concat-programs"* ]]; then
        continue
    fi

    # Skip test.sh if exists
    if [[ "$file" == "test.sh" ]]; then
        continue
    fi

    echo "" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "# FILE: $file" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "# END OF FILE: $file" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    ((count++))
    echo "Processed: $file"
done

echo ""
echo "✅ Done! Processed $count files"
echo "Output: $OUTPUT_FILE"
echo ""
echo "File size: $(du -h $OUTPUT_FILE | cut -f1)"
