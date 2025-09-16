# A topic modeling study: The association between Yelp reviews' sentiment and restaurant closures
*Which aspects of the feedback provided by Yelp customer reviews are associated with restaurant closures?* 


## Motivation
Online customer reviews play a significant role in shaping how restaurants are perceived by consumers. When searching for new places to eat at, consumers may resort to customer review platforms, such as Yelp, to establish which of several would be worth giving a try. Therefore, the valence of a restaurant's reviews on several different aspects can impact its success, and ultimately, its survival. Restaurant closures are the endmost sign that a restaurant was unsuccessful as a business, something that can occur for several reasons. The aim of this project is then to explore which, if any, aspects of customer reviews are associated to restaurant closures. To do so, a sample of Yelp's restaurant reviews will be used.

Investigating the research question *Which aspects of the feedback provided by Yelp customer reviews are associated with restaurant closures?* is crucial, as the insights derived from it may help current and prospective restaurant owners in detecting potential threats to their establishments' survival. That is, restaurant owners can use our results to, for example, be able to identify warning signs of when their restaurant's survival might be at risk, establish which key areas warrant improvement to exceed customer expectations, and adjust their business strategies to address early signs of threats before they escalate into critical issues. 


## Data
The dataset used was Yelp Open Dataset, a public dataset provided by the review platform *Yelp*. This dataset was obtained via the following link: [Yelp Open Dataset](https://business.yelp.com/data/resources/open-dataset/). 

The dataset contains 5 subsets of data: *business*, *review*, *checkin*, *tip*, and *user*, but only the *business*, *review*, and *checkin* subsets were relevant for our study. The *business* subset contains general business data including location, attributes, categories, and information on whether restaurants are open or closed; the *review* subset contains full review texts and metadata; and the *checkin* subset contains comma-separated timestamps for every logged check-in of each restaurant.

Furthermore, the dataset contains millions of reviews on a variety of types of establishments, services, and experiences that lay outside the scope of our project. Thus, we constructed a balanced dataset that consists of a random sample of 5000 restaurant reviews, ***reviews_sampled.rds***. This sample included 100 restaurants (50 of which open, and 50 of which closed) that each have at least 100 reviews since 2018. For closed restaurants, only reviews up to the date of the last check-in (i.e. while they were still active) were considered. For each restaurant, 50 reviews were randomly selected, resuting in the final sample of 5000 observations. 

The table below summarizes the most important variables at this stage of the project:

```{r}
# Create a table with the variable names

variable_table <- data.frame(
  Variable = c("business_id", "review_id", "text", "stars", "date", "user_id", "is_open", "checkin", "last_checkin"),
  Description = c("The business ID of the reviewed company", "The ID of the review", "The complete review of the user", "The amount of stars (between 1-5) given by the user", "The timestamp of the review", "The ID of the user who submitted the review", "Whether the restaurant is active/open (1) or closed (0)", "All recorded checkin timestamps of reviews for a company", "The last recorded checkin timestamp of a review for a company")
)

variable_table
```

## Method

To answer our research question, which is of exploratory nature, we first conducted a sentiment analysis on the 5000- reviews sample. This allowed us to classify the reviews as being of positive or negative nature. We then used topic modeling to identify relevant aspects of positive vs. negative reviews. Lastly, we checked which of, and whether, these aspects are associated to restarant closures.

This integrated approach provides a clear and data-driven way to link review content to business outcomes. 

## Preview of Findings 
- Describe the gist of your findings (save the details for the final paper!)
- How are the findings/end product of the project deployed?
- Explain the relevance of these findings/product. 

## Repository Overview 

**Include a tree diagram that illustrates the repository structure*

## Dependencies 

Please follow the installation guides on [Tilburg Science Hub](https://tilburgsciencehub.com/)

+ R
[R Installation Guide](https://tilburgsciencehub.com/topics/computer-setup/software-installation/rstudio/r/)
+ Make
[Installation Guide](https://tilburgsciencehub.com/topics/automation/automation-tools/makefiles/make/)

Now, copy and run the following code in R:

```{r}
required_packages <- c("tidyverse", "data.table", "here", "googledrive", "dplyr")

for (pkg in required_packages) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		suppressMessages(install.packages(pkg))
	}
}
#load all the dependencies
invisible(lapply(required_packages, function(pkg) {
	suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}))

```

## Running Instructions 

Here’s a concise **Step-by-Step** :

1. **install packages**
   
install.packages(c("rmarkdown","knitr","tidyverse","data.table","here","googledrive"))

2. **Download data** form Yelp

Downloads Yelp CSVs from Google Drive (public folder) only if not present, converts to `.rds`.

3. **Load data** into the environment

4. **create the sample**

- From `business`, keep only businesses with category *Restaurants*.

- Extract their `business_id` values and join with the `review` dataset.

- Compute the number of reviews per restaurant (`n_reviews`).

- Keep only restaurants with at least 50 reviews.

- Merge in the `is_open` variable from `business`.

- Check the proportion of open vs. closed restaurants.

- Define selection criteria: close vs open, where:

Closed\_ids: closed restaurants with **100+ reviews since Jan 1, 2018**, counted only until their last check-in.
Open\_ids: open restaurants with **100+ reviews since Jan 1, 2018**.

- Sample restaurants
50 closed restaurants
50 open restaurants

- Sample reviews

For each selected restaurant, randomly sample **50 reviews** (after 2018, and before last check-in if closed).

Final dataset size: (50 × 50) + (50 × 50) = **5,000 reviews**.

Add the `is_open` variable to the sampled reviews (label open/closed).

- Save final dataset

- Alternatively, download it directly from Google Drive.

## About 

This repository was made by Geert Huissen, Alice Ruggiero, Mathijs Quarles van Ufford, Nigel de Jong, and Maria Orgaz Jimenez as part of the Master's course [Data Preparation & Programming Skills](https://dprep.hannesdatta.com/) at the [Department of Marketing](https://www.tilburguniversity.edu/about/schools/economics-and-management/organization/departments/marketing), [Tilburg University](https://www.tilburguniversity.edu/), the Netherlands.
