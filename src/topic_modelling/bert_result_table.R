
#### Topic modeling steps

#Downloading the dataset


folder_id <- "1oRNbZpA4kXZRsvcNe5K1FRYFKqqT5W2h"	#folder id
googledrive::drive_deauth()
folder <- drive_ls(as_id(folder_id))
filename <- "reviews_python_out.csv"
file_id <- folder[folder$name==filename,] %>% pull(id) %>% as.character()
drive_download(as_id(file_id), path = here("data",filename), overwrite = TRUE)

reviews_python_out <- read.csv(here("data", filename))

#prepare dataset

reviews_python_out_aggregated = reviews_python_out %>% arrange(assigned_topic_id)

reviews_python_out_aggregated = reviews_python_out_aggregated %>% filter(assigned_topic_id !=-1)

reviews_python_out_aggregated = reviews_python_out_aggregated %>% select(-(prob_topic_0:prob_topic_18))

# create a dataset describing each topic_id and its utility

topic_dict <- tibble(
  assigned_topic_id = c(0:18),
  theme = c(
    "Wait times & table service",          # 0
    "Asian hot dishes (thai/pho/ramen)",   # 1
    "Mexican (tacos/burritos/margaritas)", # 2
    "Seafood & po' boy",                   # 3
    "Overall experience (atmosphere/staff)",# 4
    "Burgers & fries",                     # 5
    "Pub/bar (beer, wings, bartender)",    # 6
    "Italian (pasta/sauces)",              # 7
    "Nashville hot chicken",               # 8
    "Pizza (incl. deep-dish)",             # 9
    "Breakfast (eggs/pancakes/benedict)",  # 10
    "Mediterranean/Middle Eastern",        # 11
    "Vegan/vegetarian options",            # 12
    "Sushi & hot pot / K-BBQ",             # 13
    "Service/staff praised",               # 14
    "Steakhouse (cuts/doneness)",          # 15
    "Brunch",                              # 16
    "New Orleans / NOLA (geo)",            # 17
    "Nashville & tapas/small plates (geo)" # 18
  ), utility=c("high", "low", "low", "low", "high","low","low", "low", "low", "low", "low", "low", "low", "low", "high", "low", "low", "low", "low")
)

# merge datasets

reviews_with_theme <- reviews_python_out_aggregated %>%
  left_join(topic_dict, by = "assigned_topic_id")



