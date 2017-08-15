set -e

TARGET_DIR=`realpath "tmp_release"`

function cleanup {
	rm -r "$TARGET_DIR" 2> /dev/null || true
}
trap cleanup EXIT

function abort {
	msg=${1:?}
	echo "ABORTING: $msg"
	exit 1
}

# ensures there are no unstaged changes
function pre_release_checks {
	default_branch=${1:-"master"}
	current_branch=`git rev-parse --abbrev-ref HEAD`
	if [ "$current_branch" != "$default_branch" ]; then
		abort "current branch is $current_branch, expected $default_branch"
	fi

	git diff --exit-code --quiet && \
			git diff --cached --exit-code --quiet || \
			abort "unstaged changes"
}

# selectively determines package contents
function create_package {
	mkdir "$TARGET_DIR"

	release_archive="_RELEASE_ARCHIVE_.tar.gz"
	git archive -o "$release_archive" HEAD
	tar xzf "$release_archive" -C "$TARGET_DIR"
	rm "$release_archive"

	echo "$TARGET_DIR"
}

function publish_package {
	version=`determine_version "."`
	echo "about to publish v${version}"
	read -n1 -p "enter 'y' to continue: " confirmation
	echo
	if [ "$confirmation" = "y" ]; then
		cd "$TARGET_DIR"
		npm publish
		cd -
		git tag "v${version}"
		git push --tags origin master
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
