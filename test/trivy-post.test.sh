#! /bin/bash

test_help_message() {
	run --help

	assertEquals "Should return success" "$RETURN" 0
	assertEquals "Should not have error" "" "$ERR"
	assertContains "Should have output" "$OUT" "Post a trivy output to a GitHub Pull Request as a comment."
}

test_unknown_argument() {
	run --unknown

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "Unknown option"
	assertNull "Should not have output" "$OUT"
}

test_missing_repo() {
	run --no-color

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: --repo (or \$REPO) is required"
	assertNull "Should not have output" "$OUT"
}

test_missing_pr_number() {
	run --no-color --repo="owner/repo" --trivy-output-file="./other-file.txt"

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: --pr-number (or \$PR_NUMBER) is required"
	assertNull "Should not have output" "$OUT"
}

test_missing_trivy_output_file() {
	run --no-color --repo="owner/repo" --pr-number=1

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Output text file \"./trivy-output.md\" does not exist. If the file is in a different location, you can set it with --trivy-output-file or \$TRIVY_OUTPUT_FILE"
	assertNull "Should not have output" "$OUT"
}

test_plan_text_file_not_exists() {
	run --no-color --repo="owner/repo" --pr-number=1 --trivy-output-file="./other-file.txt"

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Output text file \"./other-file.txt\" does not exist. If the file is in a different location, you can set it with --trivy-output-file or \$TRIVY_OUTPUT_FILE"
	assertNull "Should not have output" "$OUT"
}

test_wrong_repo() {
	run --no-color --repo="&&!" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md" --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Repository name '&&!' doesn't seem to be valid, it must be org/repo-name format"
	assertNull "Should not have output" "$OUT"
}

test_wrong_mode() {
	run --no-color --repo="owner/repo" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md" --mode=unknown --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Mode must be either 'recreate' or 'update'"
	assertNull "Should not have output" "$OUT"
}

test_no_org_in_repo() {
	run --no-color --repo="repo" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md" --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Repository name 'repo' doesn't seem to be valid, it must be org/repo-name format"
	assertNull "Should not have output" "$OUT"
}

test_wrong_pr_number() {
	run --no-color --repo="owner/repo" --pr-number=test --trivy-output-file="./test/terraform/success/trivy-output.md" --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: pr number 'test' must be an integer number"
	assertNull "Should not have output" "$OUT"
}

test_dry_run_custom_identifier_success() {
	run --no-color --repo="owner/repo" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md" --identifier="<!-- something -->" --dry-run

	EXPECTED=$(
		cat <<-"EOF"
			Auth: DRY RUN Skipping authentication
			Comment: DRY RUN Outputting comment
			### Generated [Trivy](https://trivy.dev) Result
			<!-- something -->

			### . - Trivy Report

			#### terraform

			| Type | Misconf ID | Check | Severity | Message |
			| ---- | ---------- | ----- | -------- | ------- |
			| Terraform Security Check | AVD-AWS-0054 | Use of plain HTTP. | CRITICAL | Listener for application load balancer does not use HTTPS.<br><a href="https://avd.aquasec.com/misconfig/avd-aws-0054">https://avd.aquasec.com/misconfig/avd-aws-0054</a> |
		EOF
	)

	assertEquals "Should not return error" "$RETURN" 0
	assertEquals "Should have output" "$EXPECTED" "$OUT"
	assertEquals "Should not have error" "" "$ERR"
}

test_dry_run_success() {
	run --no-color --repo="owner/repo" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md" --dry-run

	EXPECTED=$(
		cat <<-"EOF"
			Auth: DRY RUN Skipping authentication
			Comment: DRY RUN Outputting comment
			### Generated [Trivy](https://trivy.dev) Result
			<!-- trivy-post.sh -->

			### . - Trivy Report

			#### terraform

			| Type | Misconf ID | Check | Severity | Message |
			| ---- | ---------- | ----- | -------- | ------- |
			| Terraform Security Check | AVD-AWS-0054 | Use of plain HTTP. | CRITICAL | Listener for application load balancer does not use HTTPS.<br><a href="https://avd.aquasec.com/misconfig/avd-aws-0054">https://avd.aquasec.com/misconfig/avd-aws-0054</a> |
		EOF
	)

	assertEquals "Should not return error" "$RETURN" 0
	assertEquals "Should have output" "$EXPECTED" "$OUT"
	assertEquals "Should not have error" "" "$ERR"
}

test_create_comment_and_post() {
	run --no-color --repo="ivank/trivy-post" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md" --mode=update

	EXPECTED=$(
		cat <<-"EOF"
			Auth No explicit auth found (--token or --app-id and --installation-key), using GitHub CLI default
			Comment Searching for existing comment in PR https://github.com/ivank/trivy-post/pull/1
			Comment Existing comment not found, creating
			Comment Successful
		EOF
	)

	assertEquals "Should not return error" "$RETURN" 0
	assertEquals "Should have output" "$EXPECTED" "$OUT"
	assertEquals "Should not have error" "" "$ERR"

	# Check if the comment was created
	COMMENT=$(gh api "/repos/ivank/trivy-post/issues/1/comments" --jq '.[].body')

	EXPECTED=$(
		cat <<-"EOF"
			### Generated [Trivy](https://trivy.dev) Result
			<!-- trivy-post.sh -->

			### . - Trivy Report

			#### terraform

			| Type | Misconf ID | Check | Severity | Message |
			| ---- | ---------- | ----- | -------- | ------- |
			| Terraform Security Check | AVD-AWS-0054 | Use of plain HTTP. | CRITICAL | Listener for application load balancer does not use HTTPS.<br><a href="https://avd.aquasec.com/misconfig/avd-aws-0054">https://avd.aquasec.com/misconfig/avd-aws-0054</a> |
		EOF
	)

	assertEquals "Should have created comment" "$EXPECTED" "$COMMENT"
}

test_recreate_comment() {
	run --no-color --repo="ivank/trivy-post" --pr-number=1 --trivy-output-file="./test/terraform/success/trivy-output.md"

	EXPECTED=$(
		cat <<-"EOF"
			Auth No explicit auth found (--token or --app-id and --installation-key), using GitHub CLI default
			Comment Searching for existing comment in PR https://github.com/ivank/trivy-post/pull/1
			Comment Existing comment found
			Comment Deleting existing comment
			Comment Creating new comment
			Comment Successful
		EOF
	)

	assertEquals "Should not return error" "$RETURN" 0
	assertEquals "Should have output" "$EXPECTED" "$OUT"
	assertEquals "Should not have error" "" "$ERR"

	# Check if the last comment was updated
	COMMENT=$(gh api "/repos/ivank/trivy-post/issues/1/comments" --jq '.[].body')

	EXPECTED=$(
		cat <<-"EOF"
			### Generated [Trivy](https://trivy.dev) Result
			<!-- trivy-post.sh -->

			### . - Trivy Report

			#### terraform

			| Type | Misconf ID | Check | Severity | Message |
			| ---- | ---------- | ----- | -------- | ------- |
			| Terraform Security Check | AVD-AWS-0054 | Use of plain HTTP. | CRITICAL | Listener for application load balancer does not use HTTPS.<br><a href="https://avd.aquasec.com/misconfig/avd-aws-0054">https://avd.aquasec.com/misconfig/avd-aws-0054</a> |
		EOF
	)

	assertEquals "Should have updated the comment" "$EXPECTED" "$COMMENT"
}

# SETUP
# --------------------------------------------

run() {
	(./trivy-post.sh "$@" >"$OUT_FILE" 2>"$ERR_FILE")
	RETURN=$?
	OUT=$(cat "$OUT_FILE")
	ERR=$(cat "$ERR_FILE")
}

oneTimeSetUp() {
	# Define global variables for command output.
	OUT_FILE="${SHUNIT_TMPDIR}/stdout"
	ERR_FILE="${SHUNIT_TMPDIR}/stderr"

	# Delete all the comments in the pr using gh cli
	# Get the a list of comment ids from the test pr using gh cli
	COMMENTS=$(gh api "/repos/ivank/trivy-post/issues/1/comments" --jq '.[].id')
	# Delete all comments from the test pr
	for comment in $COMMENTS; do
		gh api --method DELETE "/repos/ivank/trivy-post/issues/comments/$comment" --silent
	done
}

setUp() {
	# Truncate the output files.
	cp /dev/null "${OUT_FILE}"
	cp /dev/null "${ERR_FILE}"
}

# Load shUnit2.
. shunit2
