# misctools
miscellaneous shell scripts for routine tasks  

* *gitacp.sh* gitacp.sh - runs 'git add' and 'git commit' for a file or directory then runs git push (optional - if '-p' is used)
* *createdevice.sh* creates a thing o AWS IoT, creates a user on Cognito, saves the user and password on Dynamo, attaches the IoT policy to the cognito user identityId. Reads configuration from a json file
