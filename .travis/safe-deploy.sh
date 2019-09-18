#!/bin/bash

# Deploy safely from Travis to a remote git repo.

# Ok so in theory we should just be able to use the Travis baked-in deployment
# to pages: https://docs.travis-ci.com/user/deployment/pages/
#
# But it is insecure.  If you follow it, you will generate a Github access token
# (with wide permissions for *other* repositories), and this token can be
# accessed by collaborators.
#
# Instead, we follow this gist:
# https://gist.github.com/domenic/ec8b0fc8ab45f39403dd
#
# which generates a deployment key pair that can only be used to push for the
# one specific repository.

# To use the the script, set the following variables, and run ./safe-deploy.sh.

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Configuration variables
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Git repository to deploy to.  Should be an HTTPS url.
# DEPLOY_REPO='https://github.com/atlanmod/updates'

# # Branch of the above repo to deploy to.
# TARGET_BRANCH="master"

# # If true, do an incremental commit.  If false, force push on the target branch,
# # erasing all history of that branch.
# KEEP_HISTORY=true

# # Folder to copy contents from.  Only its contents will be copied.  Path is
# # relative to the root of the origin repository, and must *not* end with a
# # slash.
# SRC_FOLDER="update/target/repository"

# # Folder to copy contents to on the target branch.  Path is relative to the root
# # of the target branch, and must *not* end with a slash.
# DEST_FOLDER="emfviews/snapshot"

# # Name of the deploy key to use.  This file is assumed to be under the .travis
# # folder, with the `.enc' suffix.
# DEPLOY_KEY="deploy-key-updates"

# # Directory to work with during deployment.  Make sure this is unique, and does
# # not clash with any directory in the project, or used by another deployment.
# OUT_DIR="out-updates"

# # Encryption label generated by the Travis CLI tool.
# ENCRYPTION_LABEL="b7b263ca9d8b"

# # Commit author information
# COMMIT_AUTHOR_NAME="Travis CI"
# COMMIT_AUTHOR_EMAIL="deploy@travis.org"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# End configuration
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -e # Exit with nonzero exit code if anything fails

echo Deploying to $DEPLOY_REPO on branch $TARGET_BRANCH ...

# Compute additional variables from the configuration above
SSH_REPO=${DEPLOY_REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`
TARGET_BRANCH_TEMP="${TARGET_BRANCH}-temp"

# Clone the existing target branch for this repo into OUT_DIR
git clone $DEPLOY_REPO $OUT_DIR
cd $OUT_DIR

if [ "$KEEP_HISTORY" = true ]; then
    # Create a new empty branch if TARGET_BRANCH doesn't exist yet (should only
    # happen on first deploy)
    git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
else
    # When not preserving history, always create an orphan branch, and unstage
    # everything, otherwise we'll keep the files from TARGET_BRANCH around
    git checkout --orphan $TARGET_BRANCH_TEMP
    git rm --cached '*'
fi

cd ..

# Clean out existing contents
rm -rf ${OUT_DIR}/${DEST_FOLDER} || exit 0

# Ensure destination folder parent exists
mkdir -p `dirname ${OUT_DIR}/${DEST_FOLDER}`
# Replace with fresh contents
cp -r ${SRC_FOLDER} ${OUT_DIR}/${DEST_FOLDER}

# Now let's go have some fun with the cloned repo
cd $OUT_DIR
git config user.name "$COMMIT_AUTHOR_NAME"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# If there are no changes to the compiled out (e.g. this is a README update)
# then just bail.  Note: when not preserving history, we will always commit due
# to not having any baseline to compare to.
git add -N .
if git diff --quiet; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add -A .
git commit -m "Deploy to GitHub Pages: ${SHA}"

# Get the deploy key by using Travis's stored variables to decrypt DEPLOY-KEY.enc
ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in ../.travis/${DEPLOY_KEY}.enc -out ../.travis/$DEPLOY_KEY -d
chmod 600 ../.travis/$DEPLOY_KEY
eval `ssh-agent -s`
ssh-add ../.travis/$DEPLOY_KEY

# Git LFS will fail with "You must have push access to verify locks" here.
# Since for the deployment we don't actually touch the LFS, the workaround is
# just to remove the pre-push hook that triggers LFS.  Using `--force` to remove
# it even if it doesn't exist.
# See https://github.com/git-lfs/git-lfs/issues/2284
rm --force .git/hooks/pre-push

# Now that we're all set up, we can push.  If we don't want to keep history, we
# use `--force` to erase the remote branch.
if [ "$KEEP_HISTORY" = true ]; then
    git push $SSH_REPO $TARGET_BRANCH
else
    git push --force $SSH_REPO ${TARGET_BRANCH_TEMP}:${TARGET_BRANCH}
fi

# Clean cloned repo
rm -rf ${OUT_DIR}
