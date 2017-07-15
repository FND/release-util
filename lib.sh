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
	git diff --exit-code --quiet && \
			git diff --cached --exit-code --quiet || \
			abort "unstaged changes"
}

# selectively determines package contents
function create_package {
	mkdir "$TARGET_DIR"

	git ls-tree --name-only HEAD | while read filename; do
		cp -r "$filename" "$TARGET_DIR"
	done

	echo "$TARGET_DIR"
}

function publish_package {
	version=`node -p 'require("./package.json").version'`
	if [ -z "$version" ]; then
		abort "failed to determine version"
	fi

	echo "about to publish v${version}"
	read -n1 -p "enter 'y' to continue" confirmation
	if [ "$confirmation" = "y" ]; then
		cd "$TARGET_DIR"
		npm publish
		cd -
		git tag "v${version}"
		git push --tags origin master
	fi
}
