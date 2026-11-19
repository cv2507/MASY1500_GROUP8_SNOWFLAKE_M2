
-- Milestone 3 & 4: SQL Analytics Draft 
-- MASY1-GC1500 Group 8, CFPB Consumer Complaints
 
use database cfpb_capstone_db;
use schema cfpb_schema;
 
 
-- Q1. Which 10 companies receive the most consumer complaints?
-- Why: shows which institutions carry the most complaint volume before we compare how well they handle it
 
select fc.company_name, count(*) as complaint_count
from consumer_complaints cc
join financial_companies fc on fc.company_id = cc.company_id
group by fc.company_name
order by complaint_count desc
limit 10;
 
 
-- Q2. Which financial products get the most complaints?
-- Why: tells us which product lines (credit reporting, credit cards, mortgages etc.) cause the most consumer problems
 
select fp.product_name, count(*) as complaint_count
from consumer_complaints cc
join financial_products fp on fp.product_id = cc.product_id
group by fp.product_name
order by complaint_count desc;
 
 
-- Q3. What are the 10 most common complaint issues?
-- Why: shows what consumers are actually complaining about, so companies know which problems to fix first
 
select gi.issue_name, count(*) as complaint_count
from consumer_complaints cc
join grievance_issues gi on gi.issue_id = cc.issue_id
group by gi.issue_name
order by complaint_count desc
limit 10;
 
 
-- Q4. Which 10 states generate the most complaints, and what share of the total does each make up?
-- Why: regional concentration shows where consumer pain points cluster
 
select gl.state_code, count(*) as complaint_count,
round(ratio_to_report(count(*)) over () * 100, 2) as pct_of_complaints
from consumer_complaints cc
join geographic_locations gl on gl.location_id = cc.location_id
where gl.state_code != 'UNKNOWN'
group by gl.state_code
order by complaint_count desc
limit 10;
 
 
-- Q5. Which companies respond late most often? (companies with 20+ complaints)
-- Why: timely response is the CFPB's own measure of whether a company handles complaints on time
 
select fc.company_name, count(*) as total_complaints,
sum(case when cc.timely_response = 'No' then 1 else 0 end) as late_count,
round(sum(case when cc.timely_response = 'No' then 1 else 0 end) * 100 / count(*), 2) as pct_not_timely
from consumer_complaints cc
join financial_companies fc on fc.company_id = cc.company_id
group by fc.company_name
having count(*) >= 20
and sum(case when cc.timely_response = 'No' then 1 else 0 end) > 0
order by pct_not_timely desc;
 
 
-- Q6. How do companies respond to complaints overall?
-- Why: shows whether complaints usually end in relief for the consumer or just an explanation
 
select company_response, count(*) as complaint_count,
round(ratio_to_report(count(*)) over () * 100, 2) as pct_of_complaints
from consumer_complaints
group by company_response
order by complaint_count desc;
 
-- Q7. Which companies most often close complaints with relief (monetary or non-monetary)? (companies with 20+ complaints)
-- Why: a company that gives relief is fixing the problem, not just explaining it away
 
select fc.company_name, count(*) as total_complaints,
sum(case when cc.company_response like '%relief%' then 1 else 0 end) as relief_count,
round(sum(case when cc.company_response like '%relief%' then 1 else 0 end) * 100 / count(*), 2) as pct_with_relief
from consumer_complaints cc
join financial_companies fc on fc.company_id = cc.company_id
group by fc.company_name
having count(*) >= 20
order by pct_with_relief desc;
 
 
-- Q8. What is the most common issue for each product?
-- Why: lets each product team see its single biggest complaint driver
 
select fp.product_name, gi.issue_name, count(*) as complaint_count
from consumer_complaints cc
join financial_products fp on fp.product_id = cc.product_id
join grievance_issues gi on gi.issue_id = cc.issue_id
group by fp.product_name, gi.issue_name
qualify row_number() over (partition by fp.product_name order by count(*) desc) = 1
order by complaint_count desc;
 
 
-- Q9. What is the most common issue in each of the 10 busiest states?
-- Why: tells us whether consumers in different regions struggle with the same problem or different ones
 
with top_states as (
select gl.state_code
from consumer_complaints cc
join geographic_locations gl on gl.location_id = cc.location_id
where gl.state_code != 'UNKNOWN'
group by gl.state_code
order by count(*) desc
limit 10
)
select gl.state_code, gi.issue_name, count(*) as complaint_count
from consumer_complaints cc
join geographic_locations gl on gl.location_id = cc.location_id
join grievance_issues gi on gi.issue_id = cc.issue_id
join top_states ts on ts.state_code = gl.state_code
group by gl.state_code, gi.issue_name
qualify row_number() over (partition by gl.state_code order by count(*) desc) = 1
order by complaint_count desc;
 
 
-- Q10. How many days on average does it take for a complaint to reach the company, by product?
-- Why: a long gap between the consumer filing and the company receiving it slows down the whole resolution
 
select fp.product_name, count(*) as complaint_count,
round(avg(datediff('day', cc.date_received, cc.date_sent_to_company)), 1) as avg_days_to_company
from consumer_complaints cc
join financial_products fp on fp.product_id = cc.product_id
group by fp.product_name
order by avg_days_to_company desc;


-- Q11. Which sub-products generate the most complaints within Credit Reporting?
-- Why: breaks down the largest product category from Q2 to pinpoint specific reporting failures

select fp.product_name, fp.sub_product_name, count(*) as complaint_count,
       round(ratio_to_report(count(*)) over () * 100, 2) as pct_of_credit_reporting
from consumer_complaints cc
join financial_products fp on fp.product_id = cc.product_id
where fp.product_name ilike '%credit reporting%'
group by fp.product_name, fp.sub_product_name
order by complaint_count desc;


-- Q12. Which submission channels do consumers use most, and how do timely-response rates compare across channels?
-- Why: shows whether web submissions or referrals receive faster company handling

select cc.submitted_via, count(*) as complaint_count,
       round(ratio_to_report(count(*)) over () * 100, 2) as pct_of_complaints,
       round(sum(case when cc.timely_response = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as pct_timely
from consumer_complaints cc
group by cc.submitted_via
order by complaint_count desc;


-- Q13. How do company response outcomes vary across the top 5 most-complained-about institutions?
-- Why: combines Q1 and Q6 to compare whether high-volume firms rely on explanations or provide tangible relief

with top_5_companies as (
    select company_id
    from consumer_complaints
    group by company_id
    order by count(*) desc
    limit 5
)
select fc.company_name, cc.company_response, count(*) as complaint_count,
       round(ratio_to_report(count(*)) over (partition by fc.company_name) * 100, 2) as pct_within_company
from consumer_complaints cc
join financial_companies fc on fc.company_id = cc.company_id
join top_5_companies t5 on t5.company_id = cc.company_id
group by fc.company_name, cc.company_response
order by fc.company_name, complaint_count desc;


-- Q14. Which financial products have the highest rate of consumer relief (monetary or non-monetary)?
-- Why: extends Q7 from company level to product level to see where consumers receive tangible remedies

select fp.product_name, count(*) as total_complaints,
       sum(case when cc.company_response ilike '%relief%' then 1 else 0 end) as relief_count,
       round(sum(case when cc.company_response ilike '%relief%' then 1 else 0 end) * 100.0 / count(*), 2) as pct_with_relief
from consumer_complaints cc
join financial_products fp on fp.product_id = cc.product_id
group by fp.product_name
order by pct_with_relief desc;


-- Q15. How have monthly complaint volumes and timely-response rates trended over time?
-- Why: adds a longitudinal view to test whether industry responsiveness is improving or declining across months

select date_trunc('month', cc.date_received) as complaint_month,
       count(*) as total_complaints,
       round(sum(case when cc.timely_response = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as pct_timely
from consumer_complaints cc
group by complaint_month
order by complaint_month;

-- Q16. How do timely-response and consumer-relief rates vary across the 10 most common complaint issues?
-- Why: shows whether the highest-volume consumer problems receive timely handling and tangible relief

select gi.issue_name, count(*) as complaint_count,
       round(sum(case when cc.timely_response = 'Yes' then 1 else 0 end) * 100.0 / count(*), 2) as pct_timely,
       round(sum(case when cc.company_response ilike '%relief%' then 1 else 0 end) * 100.0 / count(*), 2) as pct_with_relief
from consumer_complaints cc
join grievance_issues gi on gi.issue_id = cc.issue_id
group by gi.issue_name
order by complaint_count desc
limit 10;

--End of Script--
 

