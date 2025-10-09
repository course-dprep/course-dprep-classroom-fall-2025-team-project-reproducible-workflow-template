# Install renv
install.packages("renv")

# Make sure the current working directory is the same as the file location of this script!

# Set working directory to /src/
setwd("../src")

# Activate the renv project
source("renv/activate.R")

# Restore the environment using src/renv.lock
# This sets the versions to versions known to work :)
renv::restore(prompt = FALSE)

