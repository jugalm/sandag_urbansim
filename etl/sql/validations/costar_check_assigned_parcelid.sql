/****** Script for SelectTopNRows command from SSMS  ******/
USE spacecore

--COUNT COSTAR
SELECT COUNT(*) FROM [spacecore].[input].[costar]

--JOIN COSTAR TO PARCLES ON APN, CHECK PARCEL_ID MATCH
SELECT APN_8
	,[parcel_number_1(min)]
	,parcelID
	,[parcel_id]
	,[location]
	,CASE WHEN parcelID = [parcel_id] THEN 'MATCH'
	ELSE 'NO'
	END AS check_
FROM [spacecore].[input].[costar] c
JOIN GIS.parcels p
ON p.APN_8 = REPLACE(c.[parcel_number_1(min)], '-', '')
WHERE [parcel_number_1(min)] IS NOT NULL
AND [parcel_number_1(min)]  != ''
ORDER BY 6 DESC --[parcel_number_1(min)], [parcel_number_2(max)]
;

--CHECK COSTAR APN
SELECT [property_id]
	,[propertytype]
	,[parcel_number_1(min)]
	,[parcel_number_2(max)]
	,[secondary_type]
	,[centroid]
	,[parcel_id]
	,[location]
FROM [spacecore].[input].[costar]
WHERE [parcel_number_1(min)] IS NOT NULL
AND [parcel_number_1(min)]  != ''
ORDER BY [parcel_number_1(min)], [parcel_number_2(max)]
;

--CHECK GIS PARCELS APN
SELECT APN, APN_8
FROM GIS.parcels
WHERE APN_8 IS NOT NULL
ORDER BY APN_8

