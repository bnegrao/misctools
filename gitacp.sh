#!/bin/bash
# gitacp.sh - runs git add and commit for a file or directory then runs git push (optional - if '-p' is used)

function usage {
    echo "Usage: $(basename $0) <filename> <commit_message> [-p]"    
}

function die {
    declare MSG="$@"
    echo -e "$0: Error: $MSG">&2
    exit 1
}

(( "$#" < 2 )) && die "Wrong arguments.\n\n$(usage)"

FILE=$1
COMMIT_MESSAGE=$2
PUSH=$3

[ -f $FILE ] || die "File $FILE does not exist"

if [ ! -z "$PUSH" ] && [ "$PUSH" != "-p" ]; then
    die "third argument, if existent, must be '-p', and not '$PUSH'"
fi

echo -n adding $FILE to git...
git add $FILE || die "git add $FILE has failed."
echo done

echo "Invoking git commit for file $FILE..."
git commit -m "$COMMIT_MESSAGE" || die "git commit has failed."

if [ ! -z "$PUSH" ]; then
    echo "Invoking git push..."
    git push || die 'git push has failed.'
fi

exit 0
