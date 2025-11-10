#!/bin/bash
# Simple concatenation script using find
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

# Use find to get all files, then process them
while IFS= read -r filepath; do
    filename=$(basename "$filepath")

    # Skip the concat scripts themselves
    if [[ "$filename" == "concat-programs"* ]]; then
        echo "Skipping: $filename (concat script)"
        continue
    fi

    # Skip test.sh
    if [[ "$filename" == "test.sh" ]]; then
        echo "Skipping: $filename (test script)"
        continue
    fi

    echo "" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "# FILE: $filename" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    cat "$filepath" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "# END OF FILE: $filename" >> "$OUTPUT_FILE"
    echo "################################################################################" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    count=$((count + 1))
    echo "Processed: $filename"
done < <(find "$PROGRAMS_DIR" -maxdepth 1 -type f | sort)

echo ""
echo "✅ Done! Processed $count files"
echo "Output: $OUTPUT_FILE"
echo ""
echo "File size: $(du -h $OUTPUT_FILE | cut -f1)"
echo ""
echo "To view: cat $OUTPUT_FILE"
