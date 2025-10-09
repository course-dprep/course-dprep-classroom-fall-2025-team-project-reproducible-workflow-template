# Packages used in this project

install.packages(c(
	"compositions", "data.table", "gt", "here", "lme4", "lmerTest",
	"performance", "pROC", "stargazer", "tibble", "tidyverse", "googledrive",
	"cld3", "quanteda", "textclean", "textmineR", "tidytext", "tm",
	"vader", "rmarkdown", "rstudioapi", "tinytex", "dplyr",
	"readr", "digest", "proxy", "RColorBrewer", "scales", "tidyr",
	"wordcloud"
))


# For debugging, a list of packages and dependencies, and their versions,
# on which the code did execute without errors:
lockfile <- jsonlite::fromJSON("renv.lock")
names(lockfile$Packages)            # all package names
sapply(lockfile$Packages, `[[`, "Version")
