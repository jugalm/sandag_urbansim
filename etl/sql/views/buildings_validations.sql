/****** Script for SelectTopNRows command from SSMS  ******/
USE spacecore

SELECT *
  FROM [spacecore].[urbansim].[buildings]



SELECT COUNT(*)
FROM pecas_sr13.[urbansim].[building]
WHERE non_residential_sqft > 0

SELECT COUNT(*) ressqft
FROM [spacecore].[urbansim].[buildings]
WHERE residential_sqft > 0

SELECT COUNT(*) nonressqft
FROM [spacecore].[urbansim].[buildings]
WHERE non_residential_sqft > 0

SELECT COUNT(*) year_
FROM [spacecore].[urbansim].[buildings]
WHERE year_built > 0

SELECT *
FROM [spacecore].[urbansim].[buildings]
WHERE non_residential_sqft = 99999
OR residential_sqft = 99999

--BUILDINGS WITH NO SQ_FT
SELECT COUNT(*), buildings.development_type_id, d.name
FROM [spacecore].[urbansim].[buildings]
INNER JOIN ref.development_type d
ON d.development_type_id = buildings.development_type_id
WHERE non_residential_sqft = 0
AND residential_sqft = 0
GROUP BY buildings.development_type_id, d.name
ORDER BY 1 DESC
