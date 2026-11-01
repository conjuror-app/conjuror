#!/bin/sh

set -eu

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 TAG NOTES_FILE APP_ZIP DSYM_ZIP" >&2
  exit 1
fi

tag=$1
notes=$2
app=$3
symbols=$4
repository=conjuror-app/conjuror

case "$tag" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "Use an existing source tag, such as 1.0.0-alpha.17" >&2; exit 1 ;;
esac

for file in "$notes" "$app" "$symbols"; do
  if [ ! -s "$file" ]; then
    echo "Missing or empty file: $file" >&2
    exit 1
  fi
done

case "$app" in
  *.dSYM.zip) echo "The app archive must not be a dSYM ZIP" >&2; exit 1 ;;
  *.zip) ;;
  *) echo "The app archive must be a ZIP" >&2; exit 1 ;;
esac
case "$symbols" in
  *.dSYM.zip) ;;
  *) echo "The symbols archive must be a .dSYM.zip file" >&2; exit 1 ;;
esac

# Prefix relative paths so filenames cannot be interpreted as CLI options.
case "$app" in /*) ;; *) app=./$app ;; esac
case "$symbols" in /*) ;; *) symbols=./$symbols ;; esac

set --
case "$tag" in *-*) set -- --prerelease ;; esac

# Upload everything while the release is a draft. --verify-tag prevents GitHub
# from silently creating a tag at the current default branch.
gh release create "$tag" "$app" "$symbols" \
  --repo "$repository" --verify-tag --draft \
  --title "$tag" --notes-file "$notes" "$@"
gh release edit "$tag" --repo "$repository" --draft=false
