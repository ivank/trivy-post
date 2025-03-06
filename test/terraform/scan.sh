#!/bin/bash

# Loop through each directory in the current directory
for dir in */; do
	if [ -d "$dir" ]; then
		cd "$dir" || exit
		echo "Processing directory: $dir"

		# Scan directory for config errors
		trivy config . --format template --template "@../../../template.md.tpl" --output "trivy-output.md"

		cd ..
	fi
done
