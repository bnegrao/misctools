#!/bin/bash
# Run 'git add' and 'git commit' for one file, in a single command!


function usage {
    echo "Usage: $(basename $0) <filename> <commit_message>"    
}

function die {
    declare MSG="$@"
    echo -e "$0: Error: $MSG">&2
    exit 1
}

(( "$#" == 2 )) || die "Wrong arguments.\n\n$(usage)"

FILE=$1
COMMIT_MESSAGE=$2

[ -f $FILE ] || die "File $FILE does not exist"

echo -n adding $FILE to git...
git add $FILE || die "git add $FILE has failed."
echo done

echo "commiting $file to git..."
git commit -m "$COMMIT_MESSAGE" || die "git commit has failed."

exit 0
