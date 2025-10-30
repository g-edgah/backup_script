the script uploads(backs up) to github. I created it to automatically upload documents tied to software development to github everytime it runs


#setting up environment variables

set up environment variables as ussual
example 
URL="https://username:token@github.com/username/important.git"
in a .env file in the same folder.
the script contains code to automatically import environment variables

when creating tokens for pull and push requests to github, consider creating a fine grained token with read and write for only the repo to be backed up

