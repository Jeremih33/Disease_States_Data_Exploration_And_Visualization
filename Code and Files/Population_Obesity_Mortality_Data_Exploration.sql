-- Postgresql syntax

-- Creates our database. We will be evaluating state populations, mortality
-- by causes and obesity rates in this project.

CREATE DATABASE Disease_State_Mortality;

-- Creates our tables for population, obesity rates and mortality

CREATE TABLE Population (
	Region VARCHAR(50) NOT NULL,
	Year_Data SMALLINT NOT NULL,
	Population BIGINT CHECK (Population >= 0),
	CONSTRAINT PK_Population PRIMARY KEY (Region, Year_Data)
);

CREATE TABLE Obesity (
	FID SMALLINT UNIQUE,
	Region VARCHAR(50) PRIMARY KEY,
	Obesity_Rate DECIMAL(4,1) CHECK (Obesity_Rate >= 0 AND Obesity_Rate <= 100),
	SHAPE_Length DECIMAL(10,2)
);

CREATE TABLE Mortality (
	Year_Data SMALLINT NOT NULL,
	Diagnosis_Code VARCHAR(255) NOT NULL,
	Cause VARCHAR(255),
	Region VARCHAR(50) NOT NULL,
	Deaths INTEGER,
	Age_Adjusted_Death_Rate DECIMAL(5, 1),
	CONSTRAINT PK_Mortality PRIMARY KEY (Year_Data, Diagnosis_Code, Region),
	CONSTRAINT CHK_Not_Negative CHECK (Deaths >= 0 AND Age_Adjusted_Death_Rate >= 0)
);

-- Creates index on cause to allow for faster searching

CREATE INDEX Idx_Cause
ON Mortality (Cause);

-- Imports our csv files into the tables

COPY Population
FROM 'C:\Users\Public\Population.csv'
WITH (FORMAT CSV);

COPY Mortality
FROM 'C:\Users\Public\Mortality.csv'
WITH (FORMAT CSV, HEADER);

COPY obesity
FROM 'C:\Users\Public\Obesity_By_State.csv'
WITH (FORMAT CSV, HEADER);

-- Drops SHAPE_Length column as we will not be working with it.
-- We then select all to check obesity table

ALTER TABLE Obesity
DROP COLUMN SHAPE_Length;

SELECT * FROM Obesity;

-- Data cleaning portion. Making sure there are no null values when not appropriate

SELECT Region, Year_Data
FROM Population
WHERE Population.Population IS NULL;

SELECT Region
FROM Obesity
WHERE FID IS NULL
OR Obesity_Rate IS NULL;

SELECT YEAR_DATA, Diagnosis_Code, Region
FROM Mortality
WHERE Cause IS NULL
OR Deaths IS NULL
OR Age_Adjusted_Death_Rate IS NULL;

-- Checking to see if there are any typos or if all groups come together and have equal values as expected.

SELECT Region, COUNT(*) AS Region_Count
FROM Mortality
GROUP BY Region
ORDER BY COUNT(*) DESC;

SELECT Diagnosis_Code, Count(*) AS Diagnosis_Code_Count
FROM Mortality
GROUP BY Diagnosis_Code
ORDER BY COUNT(*) DESC;

SELECT Cause, COUNT(*) AS Cause_Count
FROM Mortality
GROUP BY Cause
ORDER BY COUNT(*) DESC;

SELECT Region, COUNT(*) AS Region_Count
FROM Population 
GROUP BY Region
ORDER BY Region_Count DESC;

SELECT Year_Data, COUNT(*)
FROM Population
GROUP BY Year_Data;

-- As we can see from the queries, the number of counts is equivalent to all other numbers as expected.
-- Duplicate data for obesity was not checked as FID is unique and region is a primary key, meaning there can be no duplicates.
-- However, when running this query to see all of our regions, we see we have Puerto Rico. We do not have Puerto Rico in any other 
-- table, so we will delete this data.

SELECT DISTINCT Region
FROM Obesity
ORDER BY Region;

SELECT *
FROM Obesity
WHERE Region LIKE '%Puerto%';

DELETE FROM Obesity
WHERE Region = 'Puerto Rico';

-- Queries

-- Calculates number of obese population in United States

CREATE VIEW Obese_Population_2015_US_Total AS
SELECT (SUM(Obesity.Obesity_Rate / 100 * Population.Population))::Integer AS Obese_Population_US
FROM Population
JOIN Obesity
ON Obesity.Region = Population.Region
AND Population.Year_Data = 2015;

-- Calculates obese percentage in United States

CREATE VIEW Obese_Population_2015_US_Percentage AS
SELECT ((
SELECT (SUM(Obesity.obesity_rate / 100 * Population.Population))::Integer AS Obese_Population_US
FROM Population
JOIN Obesity
ON Obesity.Region = Population.Region
AND Population.Year_Data = 2015
) / Population.Population::Decimal(11,1))::Decimal(4,3) AS Obesity_Rate_US
FROM Population
WHERE Region = 'United States'
AND Year_Data = 2015;

-- Calculates next FID available

SELECT MAX(FID) + 1
FROM Obesity;

-- Inserts new value of united states with our new calculated values

INSERT INTO Obesity (FID, Region, Obesity_Rate)
VALUES (53, 'United States', 28.9);

-- Here we calculate mortality rate for all causes and find the states with
-- the 5 highest mortality rates (all causes).

CREATE VIEW Mortality_Rate_5_Highest_States_2015 AS
SELECT Mortality.Region, (Mortality.Deaths / Population.Population::Decimal(15,2)) AS Mortality_Rate
FROM Mortality
JOIN Population
ON Mortality.Region = Population.Region
AND Population.Year_Data = Mortality.Year_Data
WHERE Population.Year_Data = 2015
AND Mortality.cause = 'All causes'
ORDER BY Mortality_Rate DESC
LIMIT 5;

-- Here we find the 5 lowest mortality rates by state (all causes).

CREATE VIEW Mortality_Rate_5_Lowest_States_2015 AS
SELECT Mortality.Region, (Mortality.Deaths / Population.Population::Decimal(15,2)) AS Mortality_Rate
FROM Mortality
JOIN Population
ON Mortality.Region = Population.Region
AND Population.Year_Data = Mortality.Year_Data
WHERE Population.Year_Data = 2015
AND Mortality.cause = 'All causes'
ORDER BY Mortality_Rate
LIMIT 5;

-- Here we find the mortality rates in 2010 and 2017

CREATE VIEW Mortality_Rate_US_2010_And_2017 AS
SELECT (Mortality.Deaths / Population.Population::Decimal(15,2)) AS Mortality_Rate_2010, (M2.Deaths / P2.Population::Decimal(15,2)) AS Mortality_Rate_2017
FROM Mortality
JOIN Population
ON Mortality.Region = Population.Region
AND Population.Year_Data = Mortality.Year_Data
JOIN Mortality M2
ON Mortality.Region = M2.Region
AND Mortality.Cause = M2.Cause
JOIN Population P2
ON P2.Year_Data = M2.Year_Data
AND P2.Region = Mortality.Region
WHERE Population.Year_Data = 2010
AND P2.Year_Data = 2017
AND Population.Region = 'United States'
AND Mortality.Cause = 'All causes';

-- I also did this query while changing the years from 2010 to 2017
-- Interestingly enough, there was a steady and slow increase in mortality rate from 2010 and 2017.

-- Here we study the correlation between obesity rate and mortality rate between the 10 recorded causes (and all causes)

CREATE VIEW Correlation_Obesity_Rate_Mortality_Rate_2015 AS
SELECT Mortality.Cause, Corr(Obesity.Obesity_Rate, (Mortality.Deaths / Population.Population::Decimal(15,2))) AS Correlation
FROM Mortality
JOIN Population
ON Mortality.Region = Population.Region
AND Population.Year_Data = Mortality.Year_Data
JOIN Obesity
ON Mortality.region = Obesity.region
WHERE Mortality.Year_Data = 2015
GROUP BY Mortality.Cause
ORDER BY Correlation DESC;

-- Here we select the 5 states with the highest and lowest obesity rates

CREATE VIEW Highest_Obesity_Rate_5_States AS
SELECT Region, Obesity_Rate
FROM Obesity
ORDER BY Obesity_Rate DESC
LIMIT 5;

CREATE VIEW Lowest_Obesity_Rate_5_States AS
SELECT Region, Obesity_Rate
FROM Obesity
ORDER BY Obesity_Rate
LIMIT 5;

-- Here we find the mortality rates for the 10 most obese states and compare to the 10 least obese states

CREATE VIEW Mortality_Rate_10_Highest_Obesity_Rate_States_2015 AS
SELECT Obesity.Region, Obesity.Obesity_Rate, (Mortality.Deaths / Population.Population::Decimal(15,2)) AS Mortality_Rate
FROM Obesity
JOIN Population
ON Obesity.Region = Population.Region
JOIN Mortality
ON Obesity.Region = Mortality.Region
AND Population.Year_Data = Mortality.Year_Data
WHERE Mortality.Year_Data = 2015
AND Mortality.Cause = 'All causes'
GROUP BY Obesity.Region, Mortality.Deaths, Population.Population
ORDER BY Obesity.Obesity_Rate DESC
LIMIT 10;

CREATE VIEW Mortality_Rate_10_Lowest_Obesity_Rate_States_2015 AS
SELECT Obesity.Region, Obesity.Obesity_Rate, (Mortality.Deaths / Population.Population::Decimal(15,2)) AS Mortality_Rate
FROM Obesity
JOIN Population
ON Obesity.Region = Population.Region
JOIN Mortality
ON Obesity.Region = Mortality.Region
AND Population.Year_Data = Mortality.Year_Data
WHERE Mortality.Year_Data = 2015
AND Mortality.Cause = 'All causes'
GROUP BY Obesity.Region, Mortality.Deaths, Population.Population
ORDER BY Obesity.Obesity_Rate
LIMIT 10;

-- Using a case statement to categorize obesity rates for all regions in our table

CREATE VIEW Obesity_Rate_By_State_2015 AS
SELECT Region, Obesity_Rate, 
CASE
	WHEN Obesity_Rate >= 35 THEN 'High'
	WHEN Obesity_Rate >= 25 THEN 'Medium'
	ELSE 'Low'
END AS Obesity_Category
FROM Obesity
ORDER BY Obesity_Rate;

CREATE TEMPORARY TABLE Obesity_Temp
(LIKE Obesity INCLUDING ALL);

INSERT INTO Obesity_Temp
SELECT *
FROM Obesity;

BEGIN TRANSACTION;

ALTER TABLE Obesity
ADD COLUMN Obesity_Class VARCHAR(10);

ALTER TABLE Obesity_Temp
ADD COLUMN Obesity_Class VARCHAR(10);

UPDATE Obesity_Temp
SET Obesity_Class = CASE
			WHEN Obesity_Rate >= 35 THEN 'High'
			WHEN Obesity_Rate >= 25 THEN 'Medium'
			ELSE 'Low'
		END;
					
SELECT *
FROM Obesity_Temp;

UPDATE Obesity
SET Obesity_Class = OT.Obesity_Class
FROM Obesity_Temp OT 
WHERE Obesity.region = OT.region;

SELECT *
FROM Obesity;

COMMIT;

DROP TABLE Obesity_Temp;

-- Here we use partition by to see the number in each obesity class

SELECT Region, Obesity_Rate, Obesity_Class, 
	COUNT(Obesity_Class) OVER (PARTITION BY Obesity_Class) AS Total_In_Class;

-- Exporting data to public directory

COPY 
(SELECT *
FROM Correlation_Obesity_Rate_Mortality_Rate_2015)
TO 'C:\Users\Public\Correlation_Obesity_Rate_Mortality_Rate_2015.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Highest_Obesity_Rate_5_States)
TO 'C:\Users\Public\Highest_Obesity_Rate_5_States.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Mortality_Rate_5_Highest_States_2015)
TO 'C:\Users\Public\Mortality_Rate_5_Highest_States_2015.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Lowest_Obesity_Rate_5_States)
TO 'C:\Users\Public\Lowest_Obesity_Rate_5_States.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Mortality_Rate_10_Highest_Obesity_Rate_States_2015)
TO 'C:\Users\Public\Mortality_Rate_10_Highest_Obesity_Rate_States_2015.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Mortality_Rate_10_Lowest_Obesity_Rate_States_2015)
TO 'C:\Users\Public\Mortality_Rate_10_Lowest_Obesity_Rate_States_2015.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Mortality_Rate_US_2010_And_2017)
TO 'C:\Users\Public\Mortality_Rate_US_2010_And_2017.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Mortality_Rate_5_Lowest_States_2015)
TO 'C:\Users\Public\Mortality_Rate_5_Lowest_States_2015.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Obese_Population_2015_US_Percentage)
TO 'C:\Users\Public\Obese_Population_2015_US_Percentage.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Obese_Population_2015_US_Total)
TO 'C:\Users\Public\Obese_Population_2015_US_Total.csv'
WITH (FORMAT CSV);

COPY 
(SELECT *
FROM Obesity_Rate_By_State_2015)
TO 'C:\Users\Public\Obesity_Rate_By_State_2015.csv'
WITH (FORMAT CSV);

COPY Mortality
TO 'C:\Users\Public\Mortality.csv'
WITH (FORMAT CSV);

COPY Population
TO 'C:\Users\Public\Population.csv'
WITH (FORMAT CSV);

COPY Obesity
TO 'C:\Users\Public\Obesity.csv'
WITH (FORMAT CSV);