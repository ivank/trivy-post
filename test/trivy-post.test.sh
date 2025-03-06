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
	run --no-color --repo="owner/repo"

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: --pr-number (or \$PR_NUMBER) is required"
	assertNull "Should not have output" "$OUT"
}

test_missing_ref() {
	run --no-color --repo="owner/repo" --pr-number=1

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: --ref (or \$REF) is required"
	assertNull "Should not have output" "$OUT"
}

test_wrong_repo() {
	run --no-color --repo="&&!" --pr-number=1 --ref="image:123" --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Repository name '&&!' doesn't seem to be valid, it must be org/repo-name format"
	assertNull "Should not have output" "$OUT"
}

test_wrong_scan_type() {
	run --no-color --repo="owner/repo" --pr-number=1 --ref="image:123" --scan-type=unknown --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Scan type must be either 'image' or 'config'"
	assertNull "Should not have output" "$OUT"
}

test_no_org_in_repo() {
	run --no-color --repo="repo" --pr-number=1 --ref="image:123" --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: Repository name 'repo' doesn't seem to be valid, it must be org/repo-name format"
	assertNull "Should not have output" "$OUT"
}

test_wrong_pr_number() {
	run --no-color --repo="owner/repo" --pr-number=test --ref="image:123" --dry-run

	assertEquals "Should return error" "$RETURN" 1
	assertContains "Should have error" "$ERR" "ERROR: pr number 'test' must be an integer number"
	assertNull "Should not have output" "$OUT"
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
