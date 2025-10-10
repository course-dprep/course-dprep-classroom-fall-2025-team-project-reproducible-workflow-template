# A topic modeling study: The association between Yelp reviews' sentiment and restaurant closures
***Which aspects of the feedback provided by Yelp customer reviews are associated with restaurant closures?*** 


## Motivation
Online customer reviews play a significant role in shaping how restaurants are perceived by consumers. When searching for new places to eat at, consumers may resort to customer review platforms, such as Yelp, to establish which of several would be worth giving a try. Therefore, the valence of a restaurant's reviews on several different aspects can impact its success, and ultimately, its survival. Restaurant closures are the endmost sign that a restaurant was unsuccessful as a business, something that can occur for several reasons. The aim of this project is then to explore which, if any, aspects of customer reviews are associated to restaurant closures. To do so, a sample of Yelp's restaurant reviews will be used.

Investigating the research question *Which aspects of the feedback provided by Yelp customer reviews are associated with restaurant closures?* is crucial, as the insights derived from it may help current and prospective restaurant owners in detecting potential threats to their establishments' survival. That is, restaurant owners can use our results to, for example, be able to identify warning signs of when their restaurant's survival might be at risk, establish which key areas warrant improvement to exceed customer expectations, and adjust their business strategies to address early signs of threats before they escalate into critical issues. 


## Data
The dataset used was Yelp Open Dataset, a public dataset provided by the review platform *Yelp*. This dataset was obtained via the following link: [Yelp Open Dataset](https://business.yelp.com/data/resources/open-dataset/). Given the size of some of the subsets in our dataset the individual `.csv` files can be found in the following drive: [Yelp-Dataset](https://drive.google.com/drive/folders/1WHSh8ZQYzQ3IQI8tJX90cYGR4bDy13v3). 

The dataset contains 5 subsets of data: **business**, **review**, **checkin**, **tip**, and **user**, but only the **business**, **review**, and **checkin** subsets were relevant for our study. The **business** subset contains general business data including location, attributes, categories, and information on whether restaurants are open or closed; the **review** subset contains full review texts and metadata; and the **checkin** subset contains comma-separated timestamps for every logged check-in of each restaurant.

Furthermore, the dataset contains millions of reviews on a variety of types of establishments, services, and experiences that lay outside the scope of our project. Thus, we constructed a balanced dataset that consists of a random sample of 5000 restaurant reviews, ***reviews_sampled.rds***. *?This sample included 100 restaurants (50 of which open, and 50 of which closed) that each have at least 100 reviews since 2018. For closed restaurants, only reviews up to the date of the last check-in (i.e. while they were still active) were considered. For each restaurant, 50 reviews were randomly selected, resuting in the final sample of 5000 observations.?* 

The table below summarizes the most important variables at this stage of the project:
|Variable                        |Description                                                                                     |
|--------------------------------|------------------------------------------------------------------------------------------------|
|Business_ID                     |The business ID of the reviewed company                                                         |
|Review_ID	                     |The ID of the review		                                                                      |
|Text                            |The complete review of the user	                                                              |
|Stars                           |The amount of stars (between 1-5) given by the user                                             |
|Date		                     |The timestamp of the review			                                                          |
|User_ID		                 |The ID of the user who submitted the review                                                     |
|Is_Open                         |Wherther the restaurant is active/open (1) or closed (0)	                                      | 
|Checkin                         |All recorded checkin timestamps of reviews for a company										  |
|Last_Checkin                    |The last recorded checkin timestamps of a review for a company                                  |

## Method

To answer our research question, which is of exploratory nature, we first conducted a **sentiment analysis** on the 5000- reviews sample. In order to do the sentiment analysis we created our own dictionary combining different techniques like reviewing clusters from BERTopic and word frequency tables on usefull identified themes. This allowed us to classify useful themes, variables and key words accross reviews. 

Thereafter, to perform the sentiment analysis we apply Quanteda to compute variables indicating whether each theme appears in a review. These aggregate sentiment scores and theme scores per restaurant are especially useful, and gives us both “what people talk about” (topics) and “how they feel about it”. Which finally will be tested against which of, and whether, these aspects are associated to restaurant closures.

If there is enough time available we could: 

-Fit Statistical Model 

-Model Validation

This integrated approach provides a clear and data-driven way to link review content to business outcomes. 

## Preview of Findings 
- Describe the gist of your findings (save the details for the final paper!)
- How are the findings/end product of the project deployed?
- Explain the relevance of these findings/product. 

## Repository Overview

- **data/** → contains the datasets used in the project.  
	- **raw_data/**  
	- **training_data/**  
	- **final_data/**
- **dependencies/** → contains external libraries, models, or configuration files required for execution.
- **gen/** → contains the created figures and tables used for the final paper.  
	- **figures/**  
	- **tables/**
- **src/** → contains both R and Python scripts developed for the project.  
	- **analysis/** → exploratory data analysis and statistical summaries.  
	- **data_download/** → scripts responsible for downloading external datasets.  
	- **model_validation/** → evaluating and validating model performance.  
	- **reports/** → auto-generated scripts used to create reports.  
		- **data_exploration_and_sampling/**   
		- **final_report/**   
		- **temporary_reports/**   
	- **sampling/** → procedures for generating training samples.  
	- **sentiment/** → sentiment analysis models.  
	- **topic_modelling/** → topic extraction and modelling techniques.  
		- **bert/** → BERT-based topic modelling.  
		- **data_cleaning_for_bert/** → preprocessing for BERT models.  
		- **data_cleaning_for_ner/** → preprocessing for Named Entity Recognition.  
		- **lda/** → Latent Dirichlet Allocation models.  
		- **ner/** → Named Entity Recognition scripts.  
		- **wordcloud_bert/** → word cloud generation using BERT embeddings.


## Dependencies 

Please follow the installation guides on [Tilburg Science Hub](https://tilburgsciencehub.com/)

+ R: 
[R Installation Guide](https://tilburgsciencehub.com/topics/computer-setup/software-installation/rstudio/r/)
+ Make: 
[Installation Guide](https://tilburgsciencehub.com/topics/automation/automation-tools/makefiles/make/)
+ Install required packages: 
[Dependencies/install_packages.R](https://github.com/course-dprep/yelp-restaurant-closures/blob/main/dependencies/install_packages.R)
> [!NOTE]
> There are a lot of packages that could cause errors due to version differences. Therefore, the second code in `install.packages.R` shows all versions of packages and dependancies used for this project to work. 
+ Install Python version 3.11: 
[Python_Instructions.txt](https://github.com/course-dprep/yelp-restaurant-closures/blob/main/dependencies/python_instructions.txt)

## Running Instructions 
For this workflow to run, the following steps should be taken:
> [!IMPORTANT]
> **After** completing the instalation requirements in the Dependencies!

1. Fork the repository
2. Open your command-line (e.g., Git GUI)
3. Create a copy of the repository to your local machine by copying the following sentence in your command-line:
```
git clone [link of this Repository]
```
4. Set your working directory to the just forked repository and run the following command:
```
make
``` 
Additional:
If you want to clean the directory (e.g., data output), run the following command:
```
make clean
``` 

## About 

This repository was made by Geert Huissen, Alice Ruggiero, Mathijs Quarles van Ufford, Nigel de Jong, and Maria Orgaz Jimenez as part of the Master's course [Data Preparation & Programming Skills](https://dprep.hannesdatta.com/) at the [Department of Marketing](https://www.tilburguniversity.edu/about/schools/economics-and-management/organization/departments/marketing), [Tilburg University](https://www.tilburguniversity.edu/), the Netherlands.
