# Brandon Feder and Atticus Wang Data Science 2 Project

This repository contains our final project for our school's Data Science 2 course. 

The project's main code is `code.R`, you can find the paper at `paper-writeup.Rmd` and its compiled pdf `paper-writeup.pdf`. You can also find the presentation slides in `./presentation`.

## Dataset

The only dataset we used is `./data/pton-market-data.csv`. This file 15 columns by 3332 rows. 

We were not yet able to obtain the US census data due to an issue with our API key.

## Our plan

Response variable: soldPrice (price at which the house was sold)

Possible predictors: 

- nbhd (neighborhood) 
- bed (number of bedrooms) 
- fullBath (number of full baths) 
- halfBath (number of half baths) 
- style (style) 
- age (yearSold minus yearBuilt) 
- originalPrice (original price) 
- lastPrice (price at which the house was last sold) 
- marketDays (days the house was on market) 
- yearSold, daySold, monthSold (date at which the house was sold)

Regression methods we will use: 

- full linear model (lm) 
- subset selection (forward, backward) 
- ridge (ridge) 
- lasso (lasso) 
- elastic net (ela) 
- principal components regression (pcr)
