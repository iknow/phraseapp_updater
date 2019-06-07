#!/usr/bin/env bash

set -e
set -o pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPTPATH}/phraseapp_common.sh"

if [ ! -d ".git" ]; then
    echo "Error: must be run in a git checkout root" >&2
    exit 1
fi

# Configuration is via environment, and expected to be provided from a Ruby
# driver.
for variable in PHRASEAPP_API_KEY PHRASEAPP_PROJECT_ID BRANCH REMOTE PREFIX FILE_FORMAT NO_COMMIT VERBOSE; do
    if [ -z "${!variable}" ]; then
        echo "Error: must specify $variable" >&2
        exit 1
    fi
done

# Ensure we're up to date
git fetch "${REMOTE}"

current_branch=$(git rev-parse "${REMOTE}/${BRANCH}")

# If there's a local checkout of that branch, for safety's sake make sure that
# it's up to date with the remote one.
local_branch=$(git rev-parse --quiet --verify "${BRANCH}" || true)
if [ "$local_branch" ] && [ "$current_branch" != "$local_branch" ]; then
   echo "Error: local branch '${BRANCH}' exists but does not match '${REMOTE}/${BRANCH}'." >&2
   exit 1
fi

# First, fetch the current contents of PhraseApp's staged ("verified") state.
current_phraseapp_path=$(make_temporary_directory)
common_ancestor=$(phraseapp_updater download "${current_phraseapp_path}" \
                      --phraseapp_api_key="${PHRASEAPP_API_KEY}" \
                      --phraseapp_project_id="${PHRASEAPP_PROJECT_ID}" \
                      --verbose="${VERBOSE}" \
                      --file_format="${FILE_FORMAT}")

# If common_ancestor is not available or reachable from BRANCH, we've been
# really naughty and rebased without uploading the result to PhraseApp
# afterwards. If it's not available, we lose: the best we can do is manually
# perform a 2-way diff and force upload to phraseapp. If it's still available
# but not reachable, we can still try and perform a 3 way merge, but the results
# will not be as accurate and we can't record it as a merge: warn the user.
if ! git cat-file -e "${common_ancestor}^{commit}"; then
    echo "Common ancestor commit could not be found: was '${BRANCH}' rebased without updating PhraseApp?" >&2
    exit 1
elif ! git merge-base --is-ancestor "${common_ancestor}" "${current_branch}"; then
    echo "Warning: ancestor commit was not reachable from '${BRANCH}': "\
         "3-way merge may be inaccurate, and PhraseApp parent commit will not be recorded" >&2

    # If the merge base isn't an ancestor, then creating a merge commit from it
    # will create a really misleading git history, as it will appear to be
    # merging extra commits but in fact not take any contents from them. Avoid
    # doing this.
    skip_ancestor_merge=t
fi

current_branch_path=$(extract_commit "${current_branch}")
common_ancestor_path=$(extract_commit "${common_ancestor}")

current_phraseapp_tree=$(make_tree_from_directory "${current_phraseapp_path}")

# We have four cases to handle:
# 1: PhraseApp and BRANCH locales both changed since common_ancestor:
#  * Record current PhraseApp in a commit A with parent `common_ancestor`
#  * 3-way merge BRANCH locales and PhraseApp contents
#  * Commit the result to BRANCH with parents BRANCH and A, yielding B
#  * Push the result to phraseapp with new common_ancestor B
# 2: Only BRANCH changed since common_ancestor:
#  * Push BRANCH locales to PhraseApp with new common_ancestor BRANCH
# 3: Only PhraseApp changed since common_ancestor:
#  * Commit and push PhraseApp contents to BRANCH yielding commit A
#  * Update PhraseApp common_ancestor to A
# 4: Neither changed:
#  * Do nothing

phraseapp_changed=$(if locales_changed "${common_ancestor_path}" "${current_phraseapp_path}"; then echo t; else echo f; fi)
branch_changed=$(if locales_changed "${common_ancestor_path}" "${current_branch_path}"; then echo t; else echo f; fi)

if [ "${phraseapp_changed}" = 't' ] && [ "${branch_changed}" = 't' ]; then
    echo "$BRANCH branch and PhraseApp both changed: 3-way merging" >&2

    # 3-way merge
    merge_resolution_path=$(make_temporary_directory)
    phraseapp_updater merge "${common_ancestor_path}" "${current_branch_path}" "${current_phraseapp_path}" \
                      --to "${merge_resolution_path}" \
                      --verbose="${VERBOSE}"          \
                      --file_format="${FILE_FORMAT}"

    if [ "$NO_COMMIT" != 't' ]; then
        # Commit merge result to PREFIX in BRANCH
        merge_resolution_tree=$(make_tree_from_directory "${merge_resolution_path}")
        merged_branch_tree=$(replace_nested_tree "${current_branch}^{tree}" "${PREFIX}" "${merge_resolution_tree}")


        if [ "$skip_ancestor_merge" = 't' ]; then
            merge_args=()
        else
            # Create a commit to record the pre-merge state of PhraseApp
            phraseapp_commit_tree=$(replace_nested_tree "${common_ancestor}^{tree}" "${PREFIX}" "${current_phraseapp_tree}")
            phraseapp_commit=$(git commit-tree "${phraseapp_commit_tree}" \
                                   -p "${common_ancestor}" \
                                   -m "Remote locale changes made on PhraseApp" \
                                   -m "These changes may be safely flattened into their merge commit when rebasing.")

            merge_args=("-p" "${phraseapp_commit}")
        fi



        merge_commit=$(git commit-tree "${merged_branch_tree}" \
                           -p "${current_branch}" \
                           "${merge_args[@]}" \
                           -m "Merged locale changes from PhraseApp" \
                           -m "Since common ancestor ${common_ancestor}" \
                           -m "X-PhraseApp-Merge: ${phraseapp_commit}")

        # Push to BRANCH
        git push "${REMOTE}" "${merge_commit}:refs/heads/${BRANCH}"
        new_parent_commit="${merge_commit}"
    else
        # Merge is only to phraseapp: record current branch as new common ancestor
        echo "Not committing to $BRANCH" >&2
        new_parent_commit="${current_branch}"
    fi

    # Push merge result to phraseapp
    phraseapp_updater upload "${merge_resolution_path}" \
                      --parent_commit="${new_parent_commit}" \
                      --phraseapp_api_key="${PHRASEAPP_API_KEY}" \
                      --phraseapp_project_id="${PHRASEAPP_PROJECT_ID}" \
                      --verbose="${VERBOSE}" \
                      --file_format="${FILE_FORMAT}"

elif [ "${branch_changed}" = 't' ]; then
    echo "Only $BRANCH branch changed: updating PhraseApp" >&2

    # Upload to phraseapp
    phraseapp_updater upload "${current_branch_path}" \
                      --parent_commit="${current_branch}" \
                      --phraseapp_api_key="${PHRASEAPP_API_KEY}" \
                      --phraseapp_project_id="${PHRASEAPP_PROJECT_ID}" \
                      --verbose="${VERBOSE}" \
                      --file_format="${FILE_FORMAT}"

elif [ "${phraseapp_changed}" = 't' ]; then
    if [ "$NO_COMMIT" != 't' ]; then
        echo "Only PhraseApp changed: updating $BRANCH branch" >&2

        updated_branch_tree=$(replace_nested_tree "${current_branch}^{tree}" "${PREFIX}" "${current_phraseapp_tree}")
        update_commit=$(git commit-tree "${updated_branch_tree}" \
                            -p "${current_branch}" \
                            -m "Incorporate locale changes from PhraseApp" \
                            -m "Since common ancestor ${common_ancestor}")

        git push "${REMOTE}" "${update_commit}:refs/heads/${BRANCH}"

        # Set ancestor on phraseapp
        phraseapp_updater update_parent_commit \
                          --parent_commit="${update_commit}" \
                          --phraseapp_api_key="${PHRASEAPP_API_KEY}" \
                          --verbose="${VERBOSE}" \
                          --phraseapp_project_id="${PHRASEAPP_PROJECT_ID}"
    else
        echo "Only PhraseApp changed: not committing to $BRANCH branch" >&2
    fi
else
    echo "No changes made since common ancestor" >&2
fi
