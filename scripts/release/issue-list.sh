#!/bin/bash

programname=$0
function usage()
{
    echo "usage: $programname -r repository -m milestone"
    echo "  -r  repository name"
    echo "  -m  milestone id"
    exit 1
}

function print_content_with_nonempty_issues() {
  echo $1 | grep -q '[0-9]'
  if [[ "$?" == 0 ]]; then
    echo -e "$1"
  fi
}

# Given a minishift repo name and a milestone, generates a sorted list of issues for this milestone.
# Can be used to update the GitHub replease page as part of cutting a release.
function milestone_issues()
{
  # get the raw data
  milestone_data="`curl -s https://api.github.com/repos/minishift/$repository/issues?milestone=$milestone\&state=closed`"

  issue_list=`echo $milestone_data | jq '.[] | "- Issue [#" + (.number|tostring) + "](" + .url + ") ("
  + (reduce .labels[] as $item (""; (if $item.color == "84b6eb" then (. + $item.name[5:]) else . end)))
  + ") - " + .title'`

  # sort first on issue type, then issue id
  issue_list=`echo "$issue_list" | sort  -k4,4 -k2n`

  # Remove enclosing quotes on each line
  issue_list=`echo "$issue_list" | tr -d \"`

  # Replace \ which is left over from above command with "(double quote) and suppress warning
  issue_list=`echo "$issue_list" | tr '\' '"' 2> /dev/null`

  # Adjust the issue links
  issue_list=`echo "$issue_list" | sed -e s/api.github.com.repos/github.com/g`

  features="# Features\n"
  bugs="\n# Bugs\n"
  tasks="\n# Tasks\n"
  while read line; do
    if [[ "$line" == *"(feature)"* ]]; then features="$features\n$line"; fi
    if [[ "$line" == *"(bug)"* ]]; then bugs="$bugs\n$line"; fi
    if [[ "$line" == *"(task)"* ]]; then tasks="$tasks\n$line"; fi
  done <<< "$issue_list"

  for content in "$features" "$bugs" "$tasks"; do
    print_content_with_nonempty_issues "$content"
  done
}

while getopts ":r:m:" opt; do
  case $opt in
    r)
      repository=$OPTARG
      ;;
    m)
      milestone=$OPTARG
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND-1))

if [ -z "${repository}" ] || [ -z "${milestone}" ]; then
    usage
    exit 1
fi

milestone_issues