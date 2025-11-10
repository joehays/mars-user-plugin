#!/bin/bash
# =============================================================================
# concat-programs.sh
# Concatenate all files from ~/dev/dotfiles/scripts/programs/ into a single
# file with clear file boundaries for easy sharing
# =============================================================================
set -euo pipefail

# Configuration
PROGRAMS_DIR="${HOME}/dev/dotfiles/scripts/programs"
OUTPUT_FILE="/tmp/programs-concatenated.txt"

# Check if programs directory exists
if [ ! -d "${PROGRAMS_DIR}" ]; then
    echo "ERROR: Directory not found: ${PROGRAMS_DIR}"
    exit 1
fi

# Create output file
echo "Concatenating files from: ${PROGRAMS_DIR}"
echo "Output file: ${OUTPUT_FILE}"
echo ""

# Header
cat > "${OUTPUT_FILE}" <<EOF
================================================================================
CONCATENATED PROGRAMS FILES
================================================================================
Source: ~/dev/dotfiles/scripts/programs/
Generated: $(date)
================================================================================

EOF

# Counter
file_count=0

# Process each file in the directory
for file in "${PROGRAMS_DIR}"/*; do
    # Skip if not a regular file
    if [ ! -f "$file" ]; then
        continue
    fi

    filename=$(basename "$file")
    ((file_count++))

    # File header
    cat >> "${OUTPUT_FILE}" <<EOF

################################################################################
# FILE: ${filename}
################################################################################

EOF

    # File contents
    cat "$file" >> "${OUTPUT_FILE}"

    # File footer
    cat >> "${OUTPUT_FILE}" <<EOF


################################################################################
# END OF FILE: ${filename}
################################################################################


EOF

done

# Summary footer
cat >> "${OUTPUT_FILE}" <<EOF

================================================================================
SUMMARY
================================================================================
Total files concatenated: ${file_count}
Output saved to: ${OUTPUT_FILE}
================================================================================
EOF

# Print summary
echo "✅ Concatenation complete!"
echo ""
echo "Total files: ${file_count}"
echo "Output file: ${OUTPUT_FILE}"
echo ""
echo "To view the file:"
echo "  cat ${OUTPUT_FILE}"
echo ""
echo "To copy to clipboard (if xclip installed):"
echo "  cat ${OUTPUT_FILE} | xclip -selection clipboard"
echo ""
echo "Or just open the file and copy-paste its contents."
