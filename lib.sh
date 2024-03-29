set -e
set -u

default_branch="main"

realpath() {
	filepath=${1:?}
	node -r fs -p \
			'try { fs.realpathSync(process.argv[1]); } catch(err) { if(err.code !== "ENOENT") { throw err; } err.path; }' \
			"$filepath"
}

TARGET_DIR=`realpath "_tmp_release"` # XXX: implicit path

cleanup() {
	rm -r "$TARGET_DIR" 2> /dev/null || true
}
trap cleanup EXIT

abort() {
	msg=${1:?}
	echo "ABORTING: $msg"
	exit 1
}

# verifies branch, ensures that local dependencies are up to date and balks at
# unstaged changes
pre_release_checks() {
	release_branch=${1:-"$default_branch"}
	current_branch=`git rev-parse --abbrev-ref HEAD`
	if [ "$current_branch" != "$release_branch" ]; then
		abort "current branch is $current_branch, expected $release_branch"
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
create_package() {
	mkdir "$TARGET_DIR"

	release_archive="_RELEASE_ARCHIVE_.tar.gz" # XXX: implicit path
	git archive -o "$release_archive" HEAD
	tar xzf "$release_archive" -C "$TARGET_DIR"
	rm "$release_archive"

	echo "$TARGET_DIR"
}

publish_package() {
	remote=${1:-"origin"}
	branch=${2:-"$default_branch"}

	version=`determine_version "."` # XXX: implicit path
	echo "about to publish v${version}"
	read -n1 -p "enter 'y' to continue: " confirmation
	echo
	if [ "$confirmation" != "y" ]; then
		exit 1
	fi

	git push "$remote" "$branch" # ensures local repository is up to date

	tag="v${version}"
	git tag -am "$tag" "$tag"
	git push "$remote" "$tag"

	(cd "$TARGET_DIR"; npm publish)
}

determine_version() {
	root_dir=`realpath "${1:?}"`
	version=`node -p "require('$root_dir/package.json').version"`
	if [ -z "$version" ]; then
		abort "failed to determine version"
	fi

	echo "$version"
}
