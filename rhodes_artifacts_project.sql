-- Check if each museum number is unique. Each museum number corresponds to a single object.

SELECT TOP 10 Museum_number, COUNT(Museum_number) as id_count
FROM objects
GROUP BY Museum_number
ORDER BY id_count DESC

-- There are 23 repeated values named "No: null". . 
-- Select all the columns that we need into the temp table. Exclude null values in [Museum_number] column.

SELECT DISTINCT Museum_number AS object_id, object_class, Culture, Production_date, Production_place, Acq_date, Location
INTO #temp_rhodes
FROM objects JOIN object_types ON objects.Object_type = object_types.object_type
WHERE Museum_number NOT LIKE '%null%'

SELECT *
FROM #temp_rhodes

-- For future analysis and visualization purposes, the data should be normalized.
-- Update [object_id] column with values without 'No:' in front of the number.

UPDATE #temp_rhodes
SET object_id = RIGHT(object_id, CHARINDEX(':', reverse(object_id)) - 1) 
FROM #temp_rhodes

SELECT *
FROM #temp_rhodes

-- Let's check the count of [Culture] column. 

SELECT DISTINCT Culture, COUNT(culture) AS culture_count
FROM #temp_rhodes
GROUP BY Culture
ORDER BY culture_count DESC

-- Some cultures have multiple names. Keep only the first name.

UPDATE #temp_rhodes
SET Culture = CASE
  WHEN Charindex(';', Culture) > 0 THEN LEFT(Culture, (CHARINDEX(';', Culture) - 1))
  ELSE Culture
  END
FROM #temp_rhodes

SELECT *
FROM #temp_rhodes

-- Rename cultures where the count is less than 30 to 'Others'. 

UPDATE #temp_rhodes
SET Culture = CASE
    WHEN Culture IN (SELECT Culture FROM #temp_rhodes GROUP BY Culture HAVING COUNT(*) > 30) THEN Culture
    ELSE 'Others'
END 
FROM #temp_rhodes

SELECT *
FROM #temp_rhodes


--Check for missing values in [Production_place] and [Production_date] columns.

SELECT object_id, production_place, production_date
FROM #temp_rhodes
WHERE production_place IS NULL OR Production_date IS NULL


-- There are a lot of missing values. We can use that information for the future analysis.
-- Update [Production_place] and [Production_date] columns, replace missing values with "Unidentified" and "Undated" respectively

UPDATE #temp_rhodes
SET Production_place = 'Unidentified'
WHERE Production_place is NULL

UPDATE #temp_rhodes
SET Production_date = 'Undated'
WHERE Production_date IS NULL

SELECT *
FROM #temp_rhodes

-- [Production_date] column needs some serious work. There are dates with a hyphen, letter designations of the era, and additional clarifying words.

-- Let's create two new columns that split dates with a hyphen into two parts: early date and late date.

ALTER TABLE #temp_rhodes
ADD early_date VARCHAR(100), late_date VARCHAR(100)

UPDATE #temp_rhodes
SET early_date = (CASE
	WHEN Charindex('-', Production_date) > 0 THEN left(Production_date, (Charindex('-', Production_date)-1))
	ELSE Production_date
END), late_date = (CASE
	WHEN Charindex('-', Production_date) > 0 THEN substring(Production_date, (Charindex('-', Production_date)+1), (len(Production_date) - Charindex('-', Production_date)))
	ELSE Production_date
END)

SELECT *
FROM #temp_rhodes

 -- Remove all characters except numbers in both columns.

UPDATE #temp_rhodes
SET early_date = (CASE
WHEN early_date = 'Undated' THEN NULL
ELSE LEFT(REPLACE(REPLACE(TRANSLATE(early_date, 'abcdefghijklmnopqrstuvwxyz+()? ,;#+', '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'), '@', ''), '"', ''), 3)
END), late_date = (CASE
WHEN late_date = 'Undated' THEN NULL
ELSE LEFT(REPLACE(REPLACE(TRANSLATE(late_date, 'abcdefghijklmnopqrstuvwxyz+()? ,;#+', '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'), '@', ''), '"', ''), 3)
END)

SELECT * FROM #temp_rhodes

-- Add negative signs to the dates that were previously in the BC era.

UPDATE #temp_rhodes
SET early_date = (CASE
WHEN Production_date LIKE '%BC%' THEN early_date * -1
ELSE early_date
END) WHERE early_date IS NOT NULL

UPDATE #temp_rhodes
SET late_date = (CASE
WHEN Production_date LIKE '%BC%' THEN late_date * -1
ELSE late_date
END) WHERE late_date IS NOT NULL

SELECT * FROM #temp_rhodes

-- Multiply single-digit years by 100 to represent a full century.

UPDATE #temp_rhodes
SET early_date = early_date * 100 WHERE early_date LIKE '-_' OR early_date LIKE '_'

UPDATE #temp_rhodes
SET late_date = late_date * 100 WHERE late_date LIKE '-_' OR late_date LIKE '_'

SELECT * FROM #temp_rhodes

-- Cast dates as integers.

ALTER TABLE #temp_rhodes
ALTER COLUMN early_date INT;

ALTER TABLE #temp_rhodes
ALTER COLUMN late_date INT;

SELECT * FROM #temp_rhodes

-- Finally add a new column with the average production date.

ALTER TABLE #temp_rhodes
ADD Average_production_date INT

UPDATE #temp_rhodes
SET Average_production_date = (early_date + late_date)/2

SELECT * FROM #temp_rhodes

-- Drop [early_date] and [late_date] columns

ALTER TABLE #temp_rhodes
DROP COLUMN early_date, late_date

SELECT * FROM #temp_rhodes


-- [Production_place] column has unnecessary phrases and additional explanations.
-- Remove everything before ":"

UPDATE #temp_rhodes
SET Production_place = CASE 
WHEN Charindex(':', Production_place) > 0 THEN substring(Production_place, (Charindex(':', Production_place)+2), (len(Production_place) - Charindex(':', Production_place)))
ELSE Production_place
END

SELECT * FROM #temp_rhodes

-- Remove everythin after the first space. 

UPDATE #temp_rhodes
SET Production_place = CASE
	WHEN Charindex(' ', Production_place) > 0 THEN left(Production_place, (Charindex(' ', Production_place)-1))
	ELSE Production_place
	END 

SELECT * FROM #temp_rhodes

-- Remove ";" after several values.

UPDATE #temp_rhodes
SET Production_place = REPLACE(Production_place, ';', '')

SELECT * FROM #temp_rhodes

 -- [Production_place] columns has a lot of values named simply "Greece" which is too vague. Also there are areas of Greece with their own name but with very low count.
 -- Rename "Greece" and low count greek territores to "Other parts of Greece"

UPDATE #temp_rhodes
SET Production_place = CASE 
WHEN Production_place = 'Greece' THEN 'Other parts of Greece'
WHEN Production_place IN (SELECT Production_place FROM #temp_rhodes GROUP BY Production_place HAVING COUNT(*) < 30) 
AND Production_place NOT IN ('Italy', 'Apulia', 'Campania', 'Phrygia', 'Levant', 'Macedon', 'Spain', 'Pamphylia') THEN 'Other parts of Greece'
ELSE Production_place
END

-- Rename low-count non-greek territories to "Others"

UPDATE #temp_rhodes
SET Production_place = CASE 
WHEN Production_place IN (SELECT Production_place FROM #temp_rhodes GROUP BY Production_place HAVING COUNT(*) < 30) AND 
Production_place IN ('Italy', 'Apulia', 'Campania', 'Phrygia', 'Levant', 'Macedon', 'Spain', 'Pamphylia') THEN 'Others'
ELSE Production_place
END

SELECT * FROM #temp_rhodes


-- Let's check the count of [Acq_date] column. 

SELECT Acq_date, COUNT(Acq_date) as counted
FROM #temp_rhodes
GROUP BY Acq_date
ORDER BY counted DESC

-- It has the same problems as [Production_date] column before

-- Add two new columns that split dates with a hyphen into two parts

ALTER TABLE #temp_rhodes
ADD early_acq_date VARCHAR(100), late_acq_date VARCHAR(100)

UPDATE #temp_rhodes
SET early_acq_date = (CASE
	WHEN Charindex('-', Acq_date) > 0 THEN left(Acq_date, (Charindex('-', Acq_date)-1))
	ELSE Acq_date
END), late_acq_date = (CASE
	WHEN Charindex('-', Acq_date) > 0 THEN substring(Acq_date, (Charindex('-', Acq_date)+1), (len(Acq_date) - Charindex('-', Acq_date)))
	ELSE Acq_date
END)

SELECT *
FROM #temp_rhodes

-- Remove all characters except for the numbers

UPDATE #temp_rhodes
SET early_acq_date = LEFT(REPLACE(REPLACE(TRANSLATE(early_acq_date, 'abcdefghijklmnopqrstuvwxyz+''()? ,;#+', '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'), '@', ''), '"', ''), 4),
late_acq_date = LEFT(REPLACE(REPLACE(TRANSLATE(late_acq_date, 'abcdefghijklmnopqrstuvwxyz+''()? ,;#+', '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@'), '@', ''), '"', ''), 4)

SELECT * FROM #temp_rhodes


-- Cast acquisition dates as integers

ALTER TABLE #temp_rhodes
ALTER COLUMN early_acq_date INT;

ALTER TABLE #temp_rhodes
ALTER COLUMN late_acq_date INT;

SELECT * FROM #temp_rhodes

-- Add a new column with average acquistion dates.

ALTER TABLE #temp_rhodes
ADD average_acq_date INT

UPDATE #temp_rhodes
SET average_acq_date = (early_acq_date + late_acq_date)/2

SELECT * FROM #temp_rhodes

-- Drop previous two columns

ALTER TABLE #temp_rhodes
DROP COLUMN early_acq_date, late_acq_date

SELECT * FROM #temp_rhodes

-- Remove unnessesary section information from [Location] column.

UPDATE #temp_rhodes
SET Location = CASE
WHEN Location LIKE '%(%)%' THEN 'On display'
ELSE Location
END

SELECT * FROM #temp_rhodes

-- Final SELECT statement for exporting as CSV file

SELECT object_id, object_class, culture, production_date, average_production_date, production_place, average_acq_date as acquisition_date, location
FROM #temp_rhodes