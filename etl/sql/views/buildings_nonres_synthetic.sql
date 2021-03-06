USE spacecore
IF OBJECT_ID('urbansim.buildings_nonres_synthetic') IS NOT NULL
    DROP TABLE urbansim.buildings_nonres_synthetic
GO

CREATE TABLE urbansim.buildings_nonres_synthetic(
	building_id int IDENTITY(1,1) NOT NULL
	,parcel_id int
	,development_type_id smallint
	,emp int
	,sqft_per_emp float
	,emp_sqft float
	,parcel_sqft float
	,par_emp_sqft_ratio decimal(10,2)
	,apn8 int
	,parcel_nrsf float
	,costar_nrsf float
	,costar_stories int
	,stories int
)
/**1 IDENTIFY PARCELS WHERE EDD DATA HAS BEEN SITED, BUT NO BUILDING EXISTS IN OUR DATABASE **/
INSERT INTO urbansim.buildings_nonres_synthetic WITH (TABLOCK) (
	parcel_id
	,development_type_id
	,parcel_sqft
	,emp
)
SELECT usp.parcel_id
	,usp.development_type_id
	,usp.parcel_acres*43560
	,SUM(emp.emp_adj) emp
FROM urbansim.parcels usp
	JOIN socioec_data.ca_edd.emp_2013 emp
	ON usp.parcel_id = emp.parcelId		--emp.shape.STWithin(usp.shape) = 1								--EDD DATA SITED
WHERE usp.parcel_id NOT IN (SELECT DISTINCT parcel_id FROM urbansim.buildings)							--NO BUILDING
--AND usp.development_type_id != ref.[development_type_id]													--PARCEL LEVEL DEVTYPE != LCKEY LEVEL LU TO DEVTYPE
GROUP BY usp.parcel_id, usp.development_type_id, usp.parcel_acres
ORDER BY usp.parcel_id, usp.development_type_id, usp.parcel_acres
;

/**2 USING THE SQUARE FOOT PER EMPLOYEE DATA, DETERMINE THE NON-RESIDENTIAL SQUARE FOOTAGE NECESSARY TO SUPPORT THE EDD NUMBER OF EMPLOYEES **/
UPDATE
	usbs
SET
	usbs.sqft_per_emp = sqft.sqft_per_emp
	,usbs.emp_sqft = usbs.emp * sqft.sqft_per_emp			--REQUIRED SQFT
	,usbs.par_emp_sqft_ratio = usbs.emp_sqft/parcel_sqft	--REQUIRED SQFT RATIO
FROM
	urbansim.buildings_nonres_synthetic usbs
JOIN socioec_data.ca_edd.emp_2013 emp
ON usbs.parcel_id = emp.parcelId

--JOIN [ref].[development_type_lu_code] ref																	--LCKEY LEVEL LU TO DEVTYPE
--ON emp.lu = ref.[lu_code]

JOIN [spacecore].[input].[sqft_per_emp_by_dev_type] sqft
ON usbs.development_type_id = sqft.development_type_id 	

--REQUIRED SQFT RATIO
UPDATE
	urbansim.buildings_nonres_synthetic
SET
	par_emp_sqft_ratio = emp_sqft/parcel_sqft	--REQUIRED SQFT RATIO

/**3 USE PAR / COSTAR DATA, IF AVAILABLE, TO VALIDATE DERIVED NON-RESIDENTIAL SQUARE FOOTAGE **/
--PAR
UPDATE
	usbs
SET
	usbs.parcel_nrsf = l.sqft
	,usbs.apn8 = l.apn8
FROM
	urbansim.buildings_nonres_synthetic usbs
	LEFT JOIN
		(SELECT l.parcelID
			,LEFT(par.apn,8) apn8
			,SUM([TOTAL_LVG_AREA]+[ADDITION_AREA]) sqft
		FROM spacecore.input.assessor_par par
		JOIN
			(SELECT parcelID
				,MIN(apn) apn											--GRAB LOWEST APN
			FROM spacecore.gis.landcore
			GROUP BY parcelID) l
		ON l.apn = LEFT(par.apn,8)										--ONE TO MANY, SELECT MIN APN
		GROUP BY l.parcelID, LEFT(par.apn,8)
		) l
	ON usbs.parcel_id = l.parcelID

--COSTAR
UPDATE
	usbs
SET
	usbs.costar_nrsf = c.rentable_building_area
	,usbs.costar_stories = c.stories
FROM
	urbansim.buildings_nonres_synthetic usbs
	LEFT JOIN
		(SELECT parcel_id
			,SUM([rentable_building_area]) rentable_building_area
			,AVG([number_of_stories]) stories
		FROM input.costar
		GROUP BY parcel_id) c
	ON usbs.parcel_id = c.parcel_id
/**4 IDENTIFY THE NUMBER OF BUILDING STORIES BY DIVIDING THE DERIVED NON-RESIDENTIAL SQUARE FOOTAGE DIVIDED BY THE SYNTHESIZED, SETBACK-DERIVED FOOTPRINT AREA OF THE BUILDING **/
--UPDATE
--	usbs
--SET
--	usbs.stories = usbs.emp_sqft
--FROM
--	urbansim.buildings_nonres_synthetic usbs

/**5 USE THE LODES CENSUS BLOCK LEVEL DATA TO ASSIGN JOBS TO THE TOTALITY BUILDINGS **/

/**6 IDENTIFY REMAINING NON-RESIDENTIAL, NON-VACANT PARCELS WITH NO BUILDINGS AND DETERMINE WORKFLOW TO SYNTHESIZE FLOOR SPACE ON THESE USE CASES **/


