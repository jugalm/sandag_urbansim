/*
SELECT 
	b.subparcel_id b_spid
	,lc.subParcel lc_spid
	,b.shape
 FROM urbansim.buildings b
 INNER JOIN gis.landcore lc ON lc.Shape.STContains(b.shape.STPointOnSurface()) = 1
WHERE 
  data_source = 'SANDAG BLDG FOOTPRINT'
  AND b.subparcel_id <> lc.subParcel

UPDATE ws.dbo.buildings SET subparcel_id = NULL;
*/
/* ##### STEP 1: TAKE CARE OF FOOTPRINTS FULLY CONTAINED IN SUB-PARCEL ###### */
/*
UPDATE wsb
	SET wsb.subparcel_id = lc.subParcel
		,wsb.subparcel_assignment = 'FULLY CONTAINED'
FROM
	  ws.dbo.buildings wsb
	  JOIN spacecore.gis.landcore lc ON lc.Shape.STContains(wsb.shape) = 1;

*/
/* ##### STEP 2: ASSIGN REMAINING FOOTPRINTS TO SUB-PARCEL WHERE THEY HAVE THE MOST AREA ###### */
/*
WITH bldgs AS (
SELECT
	ROW_NUMBER() OVER (PARTITION BY wsb.building_id ORDER BY wsb.shape.STIntersection(lc.Shape).STArea() desc) as idx
	,wsb.building_id
	,lc.subParcel
	,wsb.shape.STIntersection(lc.Shape).STArea() area
FROM
  (SELECT * FROM ws.dbo.buildings WHERE subparcel_id is null) wsb
  JOIN spacecore.gis.landcore lc ON lc.Shape.STIntersects(wsb.shape) = 1
)

UPDATE wsb
  SET wsb.subparcel_id = bldgs.subparcel
	 ,wsb.subparcel_assignment = 'PROPORTIONALLY'
FROM 
  ws.dbo.buildings wsb
  INNER JOIN bldgs ON wsb.building_id = bldgs.building_id
WHERE
  bldgs.idx = 1
*/
/*################## STEP 3: EXPLODE GIS CREATED FOOTPRINTS TO BE SIMPLE POLYGONS - KEEP LARGEST PART  ###################*/
/*
SET IDENTITY_INSERT ws.dbo.buildings ON;
INSERT INTO ws.dbo.buildings 
	(building_id, development_type_id, parcel_id, improvement_value, residential_units
	 ,residential_sqft, job_spaces, non_residential_rent_per_sqft, price_per_sqft, stories
	 ,year_built, data_source, luz_id, subparcel_id, shape, subparcel_assignment)
SELECT building_id, development_type_id, parcel_id, improvement_value, residential_units
	 ,residential_sqft, job_spaces, non_residential_rent_per_sqft, price_per_sqft, stories
	 ,year_built, data_source, luz_id, null, shape, null FROM spacecore.urbansim.buildings WHERE data_source = 'Building_Footprints_From_Setbacks'
SET IDENTITY_INSERT ws.dbo.buildings OFF;

WITH multis AS (
SELECT
	ROW_NUMBER() OVER (PARTITION BY building_id ORDER BY shape.STGeometryN(n.numbers).STArea() desc) idx
	,building_id
	,shape.STNumGeometries() geoms
	,shape.STGeometryN(n.numbers) shape
	,shape.STGeometryN(n.numbers).STArea() area
FROM ws.dbo.buildings 
JOIN spacecore.ref.numbers n ON n.numbers <= shape.STNumGeometries()
WHERE data_source = 'Building_Footprints_From_Setbacks' AND shape.STGeometryType() = 'MultiPolygon')

UPDATE wsb
  SET wsb.shape = multis.shape
FROM
  ws.dbo.buildings wsb
  JOIN multis ON wsb.building_id = multis.building_id
WHERE
  multis.idx = 1;

*/
/*################## STEP 4: ASSIGN GIS CREATED FOOTPRINTS TO SUB-PARCEL IF FULLY CONTAINED  ###################*/
/*
UPDATE wsb
	SET wsb.subparcel_id = lc.subParcel
		,wsb.subparcel_assignment = 'FULLY CONTAINED'
FROM
	  ws.dbo.buildings wsb
	  JOIN spacecore.gis.landcore lc ON lc.Shape.STContains(wsb.shape) = 1
WHERE
	data_source = 'Building_Footprints_From_Setbacks';


	SELECT COUNT(*) FROM ws.dbo.buildings wsb WHERE
	data_source = 'Building_Footprints_From_Setbacks';

*/
/*################## STEP 5: ASSIGN GIS CREATED FOOTPRINTS TO SUB-PARCEL THAT MOST OF THE BUILDING FALLS ON  ###################*/
/*
WITH bldgs AS (
SELECT
	ROW_NUMBER() OVER (PARTITION BY wsb.building_id ORDER BY wsb.shape.STIntersection(lc.Shape).STArea() desc) as idx
	,wsb.building_id
	,lc.subParcel
	,wsb.shape.STIntersection(lc.Shape).STArea() area
FROM
  (SELECT * FROM ws.dbo.buildings WHERE subparcel_id is null AND data_source = 'Building_Footprints_From_Setbacks') wsb
  JOIN spacecore.gis.landcore lc ON lc.Shape.STIntersects(wsb.shape) = 1
)

UPDATE wsb
  SET wsb.subparcel_id = bldgs.subparcel
	 ,wsb.subparcel_assignment = 'PROPORTIONALLY'
FROM 
  ws.dbo.buildings wsb
  INNER JOIN bldgs ON wsb.building_id = bldgs.building_id
WHERE
  bldgs.idx = 1


*/
/*################## STEP 6: FOR SUB-PARCELS WITH NO BUILDINGS STILL AND DU, ASSIGN FAKE BUILDING POINT  ###################*/
/*
INSERT INTO ws.dbo.buildings (subparcel_id, shape, data_source, subparcel_assignment)
SELECT 
	lc.subParcel
	,lc.Shape.STPointOnSurface().STBuffer(1)
	,'PLACEHOLDER'
	,'PLACEHOLDER'
FROM 
	spacecore.gis.landcore lc
	LEFT JOIN ws.dbo.buildings wsb ON lc.subParcel = wsb.subparcel_id
WHERE 
	du > 0
	AND wsb.subparcel_id is null
*/
/*################## STEP 7: VERIFY THAT ALL SUB-PARCEL WITH DU HAVE A BUILDING  ###################*/
/*
SELECT COUNT(*) missing_res_building FROM 
	spacecore.gis.landcore lc
	LEFT JOIN ws.dbo.buildings wsb ON lc.subParcel = wsb.subparcel_id
WHERE 
	du > 0
	AND wsb.subparcel_id is null

*/
/*###### STEP 8: SET BUILDING'S RESIDENTIAL UNITS ON SUBPARCELS WITH ONLY ONE BUILDING #####*/
/*
UPDATE wsb
  SET wsb.residential_units = lc.du
FROM
  ws.dbo.buildings wsb
  INNER JOIN spacecore.gis.landcore lc ON lc.subParcel = wsb.subparcel_id
WHERE
  wsb.subparcel_id IN (SELECT subparcel_id FROM ws.dbo.buildings wsb GROUP BY subparcel_id HAVING count(*) = 1)

*/
/*###### STEP 9: SET BUILDINGS W/ SUB-PARCELS WITH NO RESIDENTIAL UNITS TO ZERO #####*/
/*
UPDATE wsb
  SET wsb.residential_units = lc.du
FROM
  ws.dbo.buildings wsb
  INNER JOIN spacecore.gis.landcore lc ON lc.subParcel = wsb.subparcel_id
WHERE
  wsb.subparcel_id IN (SELECT subparcel_id FROM ws.dbo.buildings wsb GROUP BY subparcel_id HAVING count(*) > 1)
  AND lc.du = 0
*/
/*########### STEP 10: EVENLY DISTRIBUTE RESIDENTIAL UNITS ON BLDG SIZE WHERE BLDG COUNT > 1 ON SUBPARCEL ############*/
/*
-----MAY WANT TO THINK ABOUT EXCLUDING REALLY SMALL BUILDINGS FROM THIS QUERY
WITH bldgs AS (
  SELECT
    wsb.subparcel_id
   ,wsb.building_id
   ,lc.du/ COUNT(*) OVER (PARTITION BY subparcel_id) +
     CASE 
       WHEN ROW_NUMBER() OVER (PARTITION BY subparcel_id ORDER BY wsb.shape.STArea()) <= (lc.du % COUNT(*) OVER (PARTITION BY subparcel_id)) THEN 1 
       ELSE 0 
	 END units
  FROM
    ws.dbo.buildings wsb
    INNER JOIN spacecore.gis.landcore lc ON wsb.subparcel_id = lc.subParcel
  WHERE
    subparcel_id IN (SELECT subparcel_id FROM ws.dbo.buildings wsb WHERE wsb.residential_units is null GROUP BY subparcel_id HAVING count(*) > 1))


UPDATE wsb
  SET wsb.residential_units = bldgs.units
FROM
	ws.dbo.buildings wsb
	INNER JOIN bldgs ON wsb.building_id = bldgs.building_id
*/
/*################ STEP 11: SOME FINAL CHECKS TO ENSURE MGRA AND REGIONAL UNIT CONSISTENCY ######################*/
/*
SELECT SUM(residential_units) bldg_units FROM ws.dbo.buildings
SELECT SUM(du) lc_units FROM spacecore.gis.landcore

SELECT 
  wsb.subparcel_id
  ,lc.du lc_units
  ,SUM(residential_units) bldg_units
FROM 
  ws.dbo.buildings wsb
  INNER JOIN spacecore.gis.landcore lc ON wsb.subparcel_id = lc.subParcel
GROUP BY
  wsb.subparcel_id
  ,lc.du
HAVING lc.du <> SUM(residential_units)
*/


/*############ STEP 12: UPDATE RESIDENTIAL SQ FT WHERE DATA AVAILABLE ###### */
/*
UPDATE wsb
  SET wsb.residential_sqft = wsb.residential_units * asr_units.avg_unit_size
FROM
  ws.dbo.buildings wsb
  INNER JOIN spacecore.gis.landcore lc ON wsb.subparcel_id = lc.subParcel
  INNER JOIN
    (SELECT
      p.PARCELID
	  ,CAST(TOTAL_LVG_AREA as float) / bldgs.res_units avg_unit_size
    FROM
      (SELECT PARCELID, SUM(TOTAL_LVG_AREA) TOTAL_LVG_AREA FROM spacecore.gis.parcels GROUP BY PARCELID) p
       INNER JOIN (SELECT lc.parcelID, SUM(residential_units) res_units FROM ws.dbo.buildings wsb INNER JOIN spacecore.gis.landcore lc ON wsb.subparcel_id = lc.subParcel GROUP BY lc.parcelID HAVING SUM(residential_units) > 0) bldgs
         ON p.PARCELID = bldgs.parcelID
	   WHERE TOTAL_LVG_AREA IS NOT NULL AND TOTAL_LVG_AREA > 0) asr_units ON lc.parcelID = asr_units.PARCELID

*/
/*################ STEP 13: SOME MORE FINAL CHECKS TO ENSURE MGRA AND REGIONAL UNIT CONSISTENCY ######################*/
/*
SELECT building_id, residential_units, residential_sqft FROM ws.dbo.buildings wsb WHERE residential_units > 0 AND residential_sqft <= 0

SELECT * 
FROM
  (SELECT MGRA, SUM(residential_units) housing_units FROM ws.dbo.buildings wsb INNER JOIN spacecore.gis.landcore lc ON wsb.subparcel_id = lc.subParcel GROUP BY MGRA) urbansim
  INNER JOIN (SELECT mgra_id % 1300000 mgra, SUM(units) housing_units, SUM(occupied) housholds FROM demographic_warehouse.fact.housing WHERE datasource_id = 19 GROUP BY mgra_id) estimates
    ON urbansim.MGRA = estimates.mgra
WHERE
  urbansim.housing_units <> estimates.housing_units

*/
/*################ STEP 14: LOAD HOUSEHOLD TABLE ######################*/
/*
INSERT INTO ws.dbo.households (scenario_id, mgra, tenure, persons, workers, age_of_head, income, children, race_id, cars)
SELECT
  scenario_id, mgra, tenure, persons, workers, age_of_head, income, children,race_id, cars FROM spacecore.input.vi_households
*/

/*################ STEP 15: THIS IS A 2010 HH FILE WITH 2015 BUILDINGS, SHAVE OFF HH WHERE BUILDINGS WERE DEMOLISHED SINCE 2010 ######################*/
/*
WITH hh AS (
SELECT
  hh.mgra
  ,household_id
  ,ROW_NUMBER() OVER (PARTITION BY hh.mgra ORDER BY household_id) idx
  ,bldgs.housing_units
FROM
  ws.dbo.households hh
  INNER JOIN (SELECT MGRA, SUM(residential_units) housing_units FROM ws.dbo.buildings wsb INNER JOIN spacecore.gis.landcore lc ON wsb.subparcel_id = lc.subParcel GROUP BY MGRA) bldgs
    ON hh.mgra = bldgs.MGRA)

SELECT * FROM ws.dbo.households WHERE household_id IN (SELECT household_id FROM hh WHERE idx > housing_units)
DELETE FROM ws.dbo.households WHERE household_id IN (SELECT household_id FROM hh WHERE idx > housing_units)
*/

/*################ STEP 16: EVENLY DISTRIBUTE HOUSEHOLDS ONTO BUILDINGS BY MGRA ######################*/
/*
WITH bldg as (
SELECT
  ROW_NUMBER() OVER (PARTITION BY mgra ORDER BY building_id) idx
  ,building_id
  ,mgra
FROM
(SELECT
  building_id
  ,subparcel_id
  ,residential_units
FROM
ws.dbo.buildings,spacecore.ref.numbers n
WHERE n.numbers <= residential_units) bldgs
INNER JOIN spacecore.gis.landcore lc ON lc.subParcel = bldgs.subparcel_id),
hh AS (
SELECT 
  ROW_NUMBER() OVER (PARTITION BY mgra ORDER BY household_id) idx
  ,household_id
  ,mgra
FROM
  ws.dbo.households
)

UPDATE h
 SET h.building_id = bldg.building_id

FROM
  ws.dbo.households h
  INNER JOIN hh ON h.household_id = hh.household_id
  INNER JOIN bldg ON bldg.MGRA = hh.mgra AND bldg.idx = hh.idx
*/

/*################ STEP 17: SOME MORE FINAL CHECKS TO ENSURE MGRA AND REGIONAL UNIT CONSISTENCY ######################*/
/*
SELECT COUNT(*) FROM ws.dbo.households WHERE building_id = 0

SELECT * FROM
(SELECT COUNT(*) hh, mgra FROM ws.dbo.households GROUP BY mgra) as hh
INNER JOIN (SELECT SUM(residential_units) units, mgra FROM ws.dbo.buildings INNER JOIN spacecore.gis.landcore ON subParcel = subparcel_id GROUP BY mgra) bldg ON hh.mgra = bldg.mgra
WHERE hh > units
*/