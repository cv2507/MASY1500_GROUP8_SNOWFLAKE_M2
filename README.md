# MASY1500_GROUP8_SNOWFLAKE_M2

a) Dataset selection
Name: U.S. Consumer Financial Protection Bureau (CFPB) Consumer Complaint Database

Source: consumerfinance.gov/data-research/consumer-complaints
Direct download: files.consumerfinance.gov/ccdb/complaints.csv.zip

Description: The dataset is a single CSV file containing every complaint submitted to the CFPB about a consumer financial product or service since 2011. Each row is one complaint and includes the date received, product and sub-product, issue and sub-issue, the company the complaint was sent to, the consumer's state and ZIP code, how the complaint was submitted, the company's response, whether it was responded to in a timely way, and whether the consumer disputed the outcome. It also includes an optional free-text consumer narrative. The file holds over 3 million records across roughly 18 columns and is around 1.5 to 2 GB uncompressed. It is updated daily, so our team will download and freeze a single snapshot to work from for the semester.

Why we chose it: We considered a few alternatives, including NYC Open Data 311 service requests, the Kaggle Olist e-commerce dataset and the FDA adverse event reports. We chose the CFPB data for the following reasons :
It comfortably exceeds the 10,000-record minimum and is large enough to make performance and design choices matter, which is where Snowflake's strengths come in.
It is realistically messy. It has missing values, inconsistent company name spellings, free-text fields, blank ZIP codes and mixed date formats, which gives us real material for the Python DQA report rather than a dataset that is already clean. The raw file is fully denormalised, one wide table with repeating company, product, issue and location values, so normalising it into 3NF is a meaningful exercise rather than a formality.
The business questions are clear and useful. Anyone working in financial services, compliance or customer experience would want to know which institutions resolve disputes fastest and where complaints cluster.

c) Problem statement
Our project will answer the question:
“ Which financial institutions, products and regions generate the most consumer complaints, and how quickly and effectively do companies resolve them? “


Specifically, we will measure dispute resolution speed and timely-response rates by company, rank institutions on how often consumers dispute their response, identify the top grievance issues by state and by product type, and track how complaint volumes and resolution performance have changed over time. These questions will drive our design decisions: the schema needs clean company and product dimensions to make rankings reliable, a location dimension to support regional analysis, and date fields structured for time-series queries. The end result should let a compliance or customer experience analyst see at a glance where consumer pain points are concentrated and which institutions are falling behind their peers.

updated to : “Which financial institutions, products and regions generate the most consumer complaints, and how well do companies respond to them?”

Specifically, we will rank institutions by complaint volume and by their timely-response rate, and measure how often each company resolves complaints with monetary or non-monetary relief rather than an explanation alone. We will also identify the top grievance issues by state and by product type, and track how complaint volumes and response outcomes have changed over time. These questions drive our design: clean company and product dimensions make rankings reliable, a location dimension supports regional analysis, and date fields support time-series queries. The result should let a compliance or customer experience analyst see where consumer pain points are concentrated and which institutions are falling behind their peers. 



