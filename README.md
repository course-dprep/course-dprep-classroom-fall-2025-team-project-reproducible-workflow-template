# A topic modeling study: The association between Yelp reviews' sentiment and restaurant closures
***Which aspects of the feedback provided by Yelp customer reviews are associated with restaurant closures?*** 


## Motivation
Online customer reviews play a significant role in shaping how restaurants are perceived by consumers. When searching for new places to eat at, consumers may resort to customer review platforms, such as Yelp, to establish which of several would be worth giving a try. Therefore, the valence of a restaurant's reviews on several different aspects can impact its success, and ultimately, its survival. Restaurant closures are the endmost sign that a restaurant was unsuccessful as a business, something that can occur for several reasons. The aim of this project is then to explore which, if any, aspects of customer reviews are associated to restaurant closures. To do so, a sample of Yelp's restaurant reviews will be used.

Investigating the research question *Which aspects of the feedback provided by Yelp customer reviews are associated with restaurant closures?* is crucial, as the insights derived from it may help current and prospective restaurant owners in detecting potential threats to their establishments' survival. That is, restaurant owners can use our results to, for example, be able to identify warning signs of when their restaurant's survival might be at risk, establish which key areas warrant improvement to exceed customer expectations, and adjust their business strategies to address early signs of threats before they escalate into critical issues. 

## Data
The dataset used was Yelp Open Dataset, a public dataset provided by the review platform *Yelp*. This dataset was obtained via the following link: [Yelp Open Dataset](https://business.yelp.com/data/resources/open-dataset/). Given the size of some of the subsets in our dataset the individual `.csv` files can be found in the following drive: [Yelp-Dataset](https://drive.google.com/drive/folders/1WHSh8ZQYzQ3IQI8tJX90cYGR4bDy13v3). 

The dataset contains 5 subsets of data: **business**, **review**, **checkin**, **tip**, and **user**, but only the **business**, **review**, and **checkin** subsets were relevant for our study. 

The **business** subset contains general business data including location, attributes, categories, and information on whether restaurants are open or closed; the **review** subset contains full review texts and metadata; and the **checkin** subset contains comma-separated timestamps for every logged check-in of each restaurant.

The **business** subset contains general business data including location, attributes, categories, and information on whether restaurants are open or closed.

The **review** subset contains full review texts and metadata.

The **checkin** subset contains comma-separated timestamps for every logged check-in of each restaurant.

Furthermore, the dataset contains millions of reviews on a variety of types of establishments, services, and experiences that lay outside the scope of our project. Thus, we constructed a balanced dataset that consists of a random sample of 5000 restaurant reviews, ***reviews_sampled.rds***. This sample includes 200 restaurants (100 of which are open, and 100 of which are closed) that each have at least 100 reviews since 2018. For closed restaurants, only reviews up to the date of the last check-in (i.e. while they were still active) were considered. For each restaurant, 25 reviews were randomly selected, resulting in the final sample of 5000 observations.

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
To answer our research question, which is of exploratory nature, we conducted the following analysis on the 5000- reviews sample: - **topic modelling analysis** - **sentiment analysis** - **regression**

**Topic modelling analysis** was conducted to identify common themes in restaurant reviews. We combined **BERTopic** and **Latent Dirichlet Allocation (LDA)** methods to perform it. BERTopic (using MiniLM embeddings, UMAP and HDBSCAN) was tested to group reviews based on semantic similarity, but results were too broad and overlapping for detailed analysis. Thus, we applied LDA, a probabilistic topic model that identifies interpretable and distinct themes. After tuning parameters with coherence and FREX scores, the final LDA model produced clear topics describing key aspects of customer experience — such as service quality, food variety, and ambiance — which were used for the final analysis.

**Sentiment analysis** was conducted to capture how reviewers feel. In order to perform it, we used **VADER (Valence Aware Dictionary and sEntiment Reasoner)** — a rule-based model designed for short, informal texts such as social media posts and reviews. Sentiment was computed in R using the NER-cleaned text, which retains natural wording while removing HTML, links, and numbers. The vader_df() function produced four sentiment metrics for each review: compound score (from −1 = very negative to +1 = very positive) and the proportions of positive, neutral, and negative expressions. Each review’s sentiment scores were linked to its ID and later aggregated per business. These values were then used alongside topic prevalence as predictors in the final logistic regression analysis.

The final step aimed to understand whether certain topics and sentiments were associated with a restaurant remaining open or closing. To this scope, a **logistic regression model** was fitted. Preliminary experiments with alternative models, such as random forests, were also explored to capture potential non-linear relationships. The model produced interpretable results showing which topics and sentiment patterns are most related to business survival, highlighting how textual information can predict real-world outcomes in the restaurant industry.

This integrated approach provides a clear and data-driven way to link review content to business outcomes. 

## Preview of Findings 
The **LDA** script produced a set of interpretable topics tailored to restaurant reviews:

**PICTURE**

These topics served as the main input for sentiment analysis and logistic regression. BERTopic clusters were not sufficiently granular.

**Sentiment analysis** showed that: - Topics 2, 6, and 7 have the highest average sentiment (≈ 0.83–0.89), indicating these clusters contain mostly positive reviews — likely related to good service, food quality, or atmosphere. - Topics 4 and 3 show moderately positive sentiment (≈ 0.60–0.81), reflecting mixed experiences. - Topics 1 and 5 display the lowest sentiment (≈ 0.28–0.34), suggesting these topics capture complaints or negative feedback, possibly about poor service, pricing, or hygiene.

![sentiment](images/sentiment.png){width="356"}

Finally, the **logistic regression** revealed that certain topics and their interaction with sentiment significantly influence whether a restaurant remains open. Specifically, Topic 1 and Topic 6 show strong positive associations with restaurant survival (p \< 0.05), suggesting that reviews emphasizing these themes—likely related to service quality and customer experience are typical of open restaurants. However, when these same topics are paired with negative sentiment, the probability of remaining open decreases sharply (negative and significant interaction terms), indicating that dissatisfaction within these key areas can be particularly harmful to business continuity.

![regression](images/regression.png){width="239"}

These findings are relevant because they show how text data from reviews can predict real-world outcomes. By quantifying which topics and emotions most affect business survival, the model provides a foundation for data-driven decision-making — helping restaurant owners, analysts, or platforms like Yelp to identify at-risk businesses and understand the drivers of customer satisfaction.

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
#### Additional:
Since some of the subsets of our data is very large, we have a "nodownload" automation. For this, download the `.csv` files from the [Yelp-Dataset](https://drive.google.com/drive/folders/1WHSh8ZQYzQ3IQI8tJX90cYGR4bDy13v3). Then run the following command: 
```
make nodownload
```
If you want to clean the directory (e.g., data output), run the following command:
```
make clean
``` 

## About 

This repository was made by Geert Huissen, Alice Ruggiero, Mathijs Quarles van Ufford, Nigel de Jong, and Maria Orgaz Jimenez as part of the Master's course [Data Preparation & Programming Skills](https://dprep.hannesdatta.com/) at the [Department of Marketing](https://www.tilburguniversity.edu/about/schools/economics-and-management/organization/departments/marketing), [Tilburg University](https://www.tilburguniversity.edu/), the Netherlands.
