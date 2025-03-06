#!/usr/bin/env bash

# Stop script on error
set -e

# Defaults of all variables
# We set them first, as they are used in the help message
NO_COLOR="${NO_COLOR:-}"
# Variables for github access
INSTALLATION_ID="${INSTALLATION_ID:-}"
TOKEN="${TOKEN:-}"
APP_ID="${APP_ID:-}"
INSTALLATION_KEY="${INSTALLATION_KEY:-}"
PR_NUMBER="${PR_NUMBER:-}"
REPO="${REPO:-}"

# Trivy config
SCAN_TYPE="${SCAN_TYPE:-image}"
REF="${REF:-}"
TEMPLATE="${TEMPLATE:-template.md.tpl}"
export TRIVY_PKG_TYPES="${TRIVY_PKG_TYPES:-library}"
export TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"

# Post config
TITLE="${TITLE:-### Generated [Trivy](https://trivy.dev) Result}"
DRY_RUN="${DRY_RUN:-false}"
IDENTIFIER="${IDENTIFIER:-<!-- trivy-post.sh -->}"

# Load NO_COLOR first
# Because all the rest would use the color markers
for i in "$@"; do
	case $i in
	--no-color)
		NO_COLOR=true
		;;
	esac
done

# Set output colors (or don't use colors if NO_COLOR=true is set)
if [ -z "$NO_COLOR" ]; then
	RED='\033[0;31m'
	CYAN='\033[0;36m'
	GREEN='\033[0;32m'
	PINK='\033[0;35m'
	END='\033[0m'
else
	RED=''
	CYAN=''
	GREEN=''
	PINK=''
	END=''
fi

# Declare required commands and the steps needed to install them
declare -A REQUIRED_COMMANDS
declare -A OPTIONAL_COMMANDS

REQUIRED_COMMANDS["jq"]="https://jqlang.github.io/jq/download/"
REQUIRED_COMMANDS["gh"]="https://cli.github.com/"
REQUIRED_COMMANDS["trivy"]="https://github.com/aquasecurity/trivy"

OPTIONAL_COMMANDS["berglas"]="https://github.com/GoogleCloudPlatform/berglas?tab=readme-ov-file#installation"
OPTIONAL_COMMANDS["openssl"]="https://openssl.org/"
OPTIONAL_COMMANDS["base64"]="https://www.gnu.org/software/coreutils/manual/html_node/base64-invocation.html"

# A function to display an error message in stderr and exit
error() {
	ERROR="
${RED}ERROR:${END} $1

Usage: ${CYAN}$(basename "$0")${END} ${PINK}--help${END}
"
	echo -e "${ERROR}" >&2
	exit 1
}

# A function to check if an optional binary is installed in path
# If not, print a message with the installation instructions
check_optional_command() {
	if ! command -v "$1" &>/dev/null; then
		error "Optional command $1 needs to be installed. ${OPTIONAL_COMMANDS[$1]}"
	fi
}

USAGE="Usage: ${CYAN}$(basename "$0")${END} [OPTIONS]

Post a trivy output to a GitHub Pull Request as a comment.

You need to provide authentication credentials, either a GitHub App (recommended) or a GitHub token.
You can provide the token directly, or load it from Google Secret Manager (example: sm://my-project/my-github-token).
Using [berglas](https://github.com/GoogleCloudPlatform/berglas) to access the secret.

    ${CYAN}$(basename "$0")${END} ${PINK}--token${END}=github_pat_...
    ${CYAN}$(basename "$0")${END} ${PINK}--token${END}=sm://my-project/my-github-token
    ${CYAN}$(basename "$0")${END} ${PINK}--app-id${END}=1234 ${PINK}--installation-key${END}=sm://my-project/my-installation-key

Those can also be provided as environment variables.

    ${GREEN}TOKEN${END}=sm://my-project/my-github-token ${CYAN}$(basename "$0")${END}
    ${GREEN}APP_ID${END}=1234 ${GREEN}INSTALLATION_KEY${END}=sm://my-project/my-installation-key ${CYAN}$(basename "$0")${END}

Additionally you need to provide the PR number, repository.
Also expects that you provide the reference to the image / folder that you wish to scan.
You can override this with ${PINK}--ref${END} (or ${GREEN}\$REF${END})

    ${CYAN}$(basename "$0")${END} ${PINK}--pr-number${END}=1234 ${PINK}--repo${END}=org/repo
    ${GREEN}PR_NUMBER${END}=1234 ${GREEN}REPO${END}=org/repo ${CYAN}$(basename "$0")${END}
    ${CYAN}$(basename "$0")${END} ${PINK}--pr-number${END}=1234 ${PINK}--repo${END}=org/repo ${PINK}--scan-type${END}=config ${PINK}--ref${END}=./terraform-folder
    ${GREEN}PR_NUMBER${END}=1234 ${GREEN}REPO${END}=org/repo ${GREEN}SCAN_TYPE${END}=config ${GREEN}REF${END}=./terraform-folder ${CYAN}$(basename "$0")${END}

Examples:

    ${CYAN}$(basename "$0")${END} \\
      ${PINK}--pr-number${END}=1234 \\
      ${PINK}--repo${END}=org/repo \\
      ${PINK}--token${END}=sm://my-project/my-github-token \\
      ${PINK}--ref${END}=my-image:12.23.2

    ${CYAN}$(basename "$0")${END} \\
      ${PINK}--plan${END}='-chdir=./terraform' \\
      ${PINK}--title${END}='My Terraform Plan' \\
      ${PINK}--pr-number${END}=1234 \\
      ${PINK}--repo${END}=org/repo \\
      ${PINK}--token${END}=1234
			${PINK}--ref${END}=my-image:12.23.2

    ${CYAN}$(basename "$0")${END} \\
      ${PINK}--pr-number${END}=1234 \\
      ${PINK}--repo${END}=org/repo \\
      ${PINK}--app-id${END}=1234 \\
      ${PINK}--installation-key${END}=sm://my-project/my-installation-key
			${PINK}--scan-type${END}=config
			${PINK}--ref${END}=./terraform-configs


Options:

  ${PINK}--help${END}                     Show this message
  ${PINK}--token${END}=value              GitHub token, provided directly or saved in google secret manager (or ENV: ${GREEN}\$TOKEN${END})
  ${PINK}${END}                           ${RED}REQUIRED${END} Unless ${CYAN}--app-id${END} and ${CYAN}--installation-key${END} are provided,
  ${PINK}${END}                           Example: sm://my-project/my-github-token
  ${PINK}--app-id${END}=value             Github App ID (or ENV: ${GREEN}\$APP_ID${END})
  ${PINK}${END}                           ${RED}REQUIRED${END} if ${CYAN}--token${END} is not provided, needs ${CYAN}--installation-key${END}
  ${PINK}--installation-id${END}=value    Installation id, if not provided, it will be fetched from the GitHub API
  ${PINK}${END}                           (or ENV: ${GREEN}\$INSTALLATION_ID${END})
  ${PINK}--installation-key${END}=value   Installation key provided directly or saved in google secret manager
  ${PINK}${END}                           (or ENV: ${GREEN}\$INSTALLATION_KEY${END})
  ${PINK}${END}                           ${RED}REQUIRED${END} if ${CYAN}--app-id${END} is provided, Example: sm://my-project/my-installation-key)
  ${PINK}--pr-number${END}=value          ${RED}REQUIRED${END} Pull Request number (or ENV: ${GREEN}\$PR_NUMBER${END})
  ${PINK}--repo${END}=value               ${RED}REQUIRED${END} Repository, Example: org/repo (or ENV ${GREEN}\$REPO${END})
  ${PINK}--ref${END}=value                Terraform plan text output (or error output)
  ${PINK}${END}                           (or ENV: ${GREEN}\$REF${END})
  ${PINK}--title${END}=value              Title for the review comment (DEFAULT: \"${CYAN}$TITLE${END}\", or ENV: ${GREEN}\$TITLE${END})
  ${PINK}--scan-type${END}=config|image   TYpe of trivy scan
  ${PINK}${END}                           (DEFAULT: \"${CYAN}$SCAN_TYPE${END}\", possible values: config, image or ENV: ${GREEN}\$SCAN_TYPE${END})
  ${PINK}--dry-run${END}                  Output the contents of the comment instead of sending it to GitHub
  ${PINK}--identifier${END}               Identify the tf-plan-post's comment with this text
  ${PINK}${END}                           (DEFAULT: \"$IDENTIFIER\", or ENV: ${GREEN}\$IDENTIFIER${END})
  ${PINK}--no-color${END}                 Disable color output (or ENV: ${GREEN}\$NO_COLOR${END})

Other binaries in PATH used by this script:
Required: ${RED}${!REQUIRED_COMMANDS[*]}${END}
Optional: ${RED}${!OPTIONAL_COMMANDS[*]}${END}"

for i in "$@"; do
	case $i in
	--help)
		echo -e "$USAGE"
		exit 0
		;;
	--installation-id=*)
		INSTALLATION_ID="${i#*=}"
		shift
		;;
	--token=*)
		TOKEN="${i#*=}"
		shift
		;;
	--app-id=*)
		APP_ID="${i#*=}"
		shift
		;;
	--installation-key=*)
		INSTALLATION_KEY="${i#*=}"
		shift
		;;
	--repo=*)
		REPO="${i#*=}"
		shift
		;;
	--pr-number=*)
		PR_NUMBER="${i#*=}"
		shift
		;;
	--title=*)
		TITLE="${i#*=}"
		shift
		;;
	--identifier=*)
		IDENTIFIER="${i#*=}"
		shift
		;;
	--scan-type=*)
		SCAN_TYPE="${i#*=}"
		shift
		;;
	--ref=*)
		REF="${i#*=}"
		shift
		;;
	--template=*)
		TEMPLATE="${i#*=}"
		shift
		;;
	--pkg-types=*)
		TRIVY_PKG_TYPES="${i#*=}"
		shift
		;;
	--severity=*)
		TRIVY_SEVERITY="${i#*=}"
		shift
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--no-color)
		shift
		;;
	*)
		error "Unknown option ${PINK}$i${END}"
		;;
	esac
done

# Validate required arguments
# ------------------------------------------------------------

declare -A REQUIRED_ARGS=(
	["REPO"]="--repo"
	["PR_NUMBER"]="--pr-number"
	["REF"]="--ref"
)

for arg in "${!REQUIRED_ARGS[@]}"; do
	if [ -z "${!arg}" ]; then
		error "${PINK}${REQUIRED_ARGS[$arg]}${END} (or ${GREEN}\$$arg${END}) is required"
	fi
done

if [ "$SCAN_TYPE" != "image" ] && [ "$MODE" != "config" ]; then
	error "Mode must be either 'image' or 'config'"
fi

if ! [[ "$REPO" =~ ^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$ ]]; then
	error "Repository name '$REPO' doesn't seem to be valid, it must be org/repo-name format"
fi

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
	error "pr number '$PR_NUMBER' must be an integer number"
fi

for COMMAND in "${!REQUIRED_COMMANDS[@]}"; do
	if ! command -v "$COMMAND" &>/dev/null; then
		error "$COMMAND needs to be installed. ${REQUIRED_COMMANDS[$COMMAND]}"
	fi
done

# Authenticate
# ------------------------------------------------------------

if [ "$DRY_RUN" = true ]; then
	echo -e "${CYAN}Auth${END}: ${RED}DRY RUN${END} Skipping authentication"
else
	if [ "$TOKEN" ]; then
		if [[ "$TOKEN" =~ ^sm:// ]]; then
			echo -e "${CYAN}Auth${END} Loading Token from Google Secret $TOKEN"
			check_optional_command berglas
			TOKEN=$(berglas access "$TOKEN")
		fi
		gh auth login --with-token <<<"$TOKEN"
		echo -e "${CYAN}Auth${END} Token Loaded"
	elif [ "$APP_ID" ] && [ "$INSTALLATION_KEY" ]; then
		if [[ "$INSTALLATION_KEY" =~ ^sm:// ]]; then
			echo -e "${CYAN}Auth${END} Loading Installation Key from Google Secret $INSTALLATION_KEY"
			check_optional_command berglas
			INSTALLATION_KEY=$(berglas access "$INSTALLATION_KEY")
		fi

		check_optional_command base64
		check_optional_command openssl

		# JWT
		# ======
		NOW=$(date +%s)
		IAT=$((NOW - 60))  # Issues 60 seconds in the past
		EXP=$((NOW + 600)) # Expires 10 minutes in the future

		HEADER=$(echo -n '{"typ":"JWT","alg":"RS256"}' | base64 -w 0)
		PAYLOAD=$(echo -n "{\"iat\":${IAT},\"exp\":${EXP},\"iss\":\"${APP_ID}\"}" | base64 -w 0)
		SIGNATURE=$(openssl dgst -sha256 -sign <(echo -n "$INSTALLATION_KEY") <(echo -n "$HEADER.$PAYLOAD") | base64 -w 0)
		JWT_HEADER="Authorization: Bearer $HEADER.$PAYLOAD.$SIGNATURE"

		if [ -z "$INSTALLATION_ID" ]; then
			echo -e "${CYAN}Auth${END} No Installation Id Provided, loading from GitHub API"
			INSTALLATIONS=$(curl --silent --header "$JWT_HEADER" https://api.github.com/app/installations)
			INSTALLATION_ID=$(echo "$INSTALLATIONS" | jq --raw-output "[.[] | select(.app_id == $APP_ID) | .id][0]")
			echo -e "${CYAN}Auth${END} Using $INSTALLATION_ID (for APP $APP_ID)"
		fi

		ACCESS_TOKEN=$(curl --silent --request POST --header "$JWT_HEADER" "https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens")
		TOKEN=$(echo "$ACCESS_TOKEN" | jq --raw-output ".token")
		gh auth login --with-token <<<"$TOKEN"
		echo -e "${CYAN}Auth${END} Installation Token generated"
	else
		echo -e "${CYAN}Auth${END} No explicit auth found (--token or --app-id and --installation-key), using GitHub CLI default"
	fi
fi

# Trivy run
# ------------------------------------------------------------

OUTPUT=$(trivy "$SCAN_TYPE" "$REF" --format template --template "@$TEMPLATE")

BODY=$(
	cat <<-EOL
		$TITLE
		$IDENTIFIER
		$OUTPUT
	EOL
)

if [ "$DRY_RUN" = true ]; then
	echo -e "${CYAN}Comment${END}: ${RED}DRY RUN${END} Outputting comment"
	echo -e "$BODY"
else
	# Create or update the comment
	# ------------------------------------------------------------
	echo -e "${CYAN}Comment${END} Searching for existing comment in PR https://github.com/$REPO/pull/$PR_NUMBER"

	set +e
	GENERATED_PLAN_COMMENT_ID=$(gh api "/repos/$REPO/issues/$PR_NUMBER/comments?per_page=100" --jq "[.[] | select(.body | contains(\"$IDENTIFIER\")) | .id][0]")
	GENERATED_PLAN_COMMENT_ID_EXIT_CODE=$?
	set -e

	if [[ "$GENERATED_PLAN_COMMENT_ID_EXIT_CODE" -eq 0 && "$GENERATED_PLAN_COMMENT_ID" ]]; then
		echo -e "${CYAN}Comment${END} Existing comment found"

		if [ "$MODE" = "recreate" ]; then
			echo -e "${CYAN}Comment${END} Deleting existing comment"
			gh api "/repos/${REPO}/issues/comments/${GENERATED_PLAN_COMMENT_ID}" --silent --method DELETE

			echo -e "${CYAN}Comment${END} Creating new comment"
			set +e
			gh api "/repos/${REPO}/issues/$PR_NUMBER/comments" --silent --method POST --field body="$BODY"
			set -e
		else
			echo -e "${CYAN}Comment${END} Updating existing comment"
			gh api "/repos/${REPO}/issues/comments/${GENERATED_PLAN_COMMENT_ID}" --silent --method PATCH --field body="$BODY"
		fi
	else
		echo -e "${CYAN}Comment${END} Existing comment not found, creating"
		set +e
		gh api "/repos/${REPO}/issues/$PR_NUMBER/comments" --silent --method POST --field body="$BODY"
		set -e
	fi

	echo -e "${CYAN}Comment${END} Successful"
fi
