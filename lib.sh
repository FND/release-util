set -e
set -u

TARGET_DIR=`realpath "_tmp_release"` # XXX: implicit path

function cleanup {
	rm -r "$TARGET_DIR" 2> /dev/null || true
}
trap cleanup EXIT

function abort {
	msg=${1:?}
	echo "ABORTING: $msg"
	exit 1
}

# verifies branch, ensures that local dependencies are up to date and balks at
# unstaged changes
function pre_release_checks {
	default_branch=${1:-"master"}
	current_branch=`git rev-parse --abbrev-ref HEAD`
	if [ "$current_branch" != "$default_branch" ]; then
		abort "current branch is $current_branch, expected $default_branch"
	fi

	git diff --exit-code --quiet && \
			git diff --cached --exit-code --quiet || \
			abort "unstaged changes"

	echo "about to install dependencies to ensure consistent test environment"
	read -n1 -p "enter 's' to skip: " skip
	echo
	if [ "$skip" != "s" ]; then
		npm install
	fi
}

# selectively determines package contents
function create_package {
	mkdir "$TARGET_DIR"

	release_archive="_RELEASE_ARCHIVE_.tar.gz" # XXX: implicit path
	git archive -o "$release_archive" HEAD
	tar xzf "$release_archive" -C "$TARGET_DIR"
	rm "$release_archive"

	echo "$TARGET_DIR"
}

function publish_package {
	remote=${1:-"origin"}
	branch=${2:-"master"}

	version=`determine_version "."` # XXX: implicit path
	echo "about to publish v${version}"
	read -n1 -p "enter 'y' to continue: " confirmation
	echo
	if [ "$confirmation" = "y" ]; then
		git push "$remote" "$branch" # ensures local repository is up to date

		(cd "$TARGET_DIR"; npm publish)

		git tag "v${version}"
		git push --tags "$remote" "$branch"
	fi
}

function determine_version {
	root_dir=`realpath "${1:?}"`
	version=`node -p "require('$root_dir/package.json').version"`
	if [ -z "$version" ]; then
		abort "failed to determine version"
	fi

	echo "$version"
}
