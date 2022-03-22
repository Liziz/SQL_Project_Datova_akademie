-- ------------------------------------ Datová akademie - SQL project ------------------------------------------------------------------------------

-- Zadani projektu --
-- 1. Rostou v prùbìhu let mzdy ve všech odvìtvích, nebo v nìkterých klesají?
-- 2. Kolik je možné si koupit litrù mléka a kilogramù chleba za první a poslední srovnatelné období v dostupných datech
--    cen a mezd?
-- 3. Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroèní nárùst)?
-- 4. Existuje rok, ve kterém byl meziroèní nárùst cen potravin výraznì vyšší než rùst mezd (vìtší než 10 %)?
-- 5. Má výška HDP vliv na zmìny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výraznìji v jednom roce, projeví
--    se to na cenách potravin èi mzdách --    ve stejném nebo násdujícím roce výraznìjším rùstem?

-- Zadání Výstupu - DVE TABULKY v databazi, ze kterých se data dají ziskat: 
-- -> t_libor_zizala_project_SQL_primary_final (pro data mezd a cen potravin za CR sjednocenech na totozne porovnatelne
--    obdobi – spoleèné roky) a
-- -> t_libor_zizala_project_SQL_secondary_final (pro dodatecna data o dalsich evropskych statech)
--
-- -> Pripravte sadu SQL, ktere z pripravenych tabulek ziskaji datovy podklad k odpovezeni na vytycene vyzkumne otazky


-- ØEŠENÍ --

-- (A) AGREGAÈNÍ tabulka -> t_libor_zizala_project_SQL_primary_final 
-- (pro data mezd a cen potravin za CR sjednocenech na totozne porovnatelne obdobi – spoleèné roky)

-- výbìr a spojení podstatných polí kolem MZDY a CENY
CREATE OR REPLACE VIEW v_libor_zizala_project_SQL_primary_final AS -- nejkrpve vytvoøeno VIEW pro snazší odladìní 
SELECT 
	cpc.name AS food_category, 
    cpc.price_value AS price_volume,
    cpc.price_unit AS price_unit,	
	round (AVG(cp.value),2) AS avg_price,
    YEAR(cp.date_from) AS year_id,
    NULL AS industry,
    NULL AS avg_wages    
FROM czechia_price cp 
JOIN czechia_price_category cpc
    ON cp.category_code = cpc.code
WHERE YEAR(cp.date_from) IN 
	(SELECT DISTINCT
    	payroll_year 
    	FROM czechia_payroll	
    	)
GROUP BY food_category, year_id 
UNION  
SELECT 
	NULL AS food_category,
	NULL AS price_volume,
	NULL AS price_unit,
	NULL AS avg_price,
	cpay.payroll_year AS year_id,
	cpib.name AS industry,
    Round (AVG(cpay.value)) AS avg_wages    
FROM czechia_payroll cpay
JOIN czechia_payroll_industry_branch AS cpib
    ON cpay.industry_branch_code = cpib.code 
WHERE 
	cpay.value_type_code = 5958 AND 
    cpay.calculation_code = 100 AND 
    cpay.payroll_year IN
    	(SELECT DISTINCT
    		YEAR(date_from) 
    	FROM czechia_price	
    	)
GROUP BY industry, year_id ;

CREATE OR REPLACE TABLE t_libor_zizala_project_SQL_primary_final AS   -- následnì vytvoøena požadovaná tabulka
SELECT *
FROM v_libor_zizala_project_SQL_primary_final;

    
-- 1.TASK: Rostou v prùbìhu let mzdy ve všech odvìtvích, nebo v nìkterých klesají?
-- 1.VÝSLEDEK VAR A - Pøehledová tabulka s více údaji, z níž lze výsledek snadno vyèíst:
SELECT 
	tlzpspf1.industry,
	tlzpspf1.year_id,
	tlzpspf1.avg_wages ,
	tlzpspf2.year_id  AS prev_year_id,
	tlzpspf2.avg_wages AS py_avg_wages,
	round (tlzpspf1.avg_wages / tlzpspf2.avg_wages,3) AS y_y_koef,
	CASE
        WHEN tlzpspf1.avg_wages < tlzpspf2.avg_wages THEN 'meziroèní pokles'
        WHEN  tlzpspf1.avg_wages = tlzpspf2.avg_wages THEN 'meziroèní stagnace'
        ELSE 'meziroèní rùst'
    END AS wages_mezirocne	
FROM t_libor_zizala_project_sql_primary_final tlzpspf1
JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
	ON tlzpspf1.industry = tlzpspf2.industry
	AND tlzpspf1.year_id = tlzpspf2.year_id +1
WHERE	
	tlzpspf1.avg_wages IS NOT NULL 
	OR tlzpspf1.industry IS NOT NULL
ORDER BY y_y_koef  ; 

-- 1.VÝSLEDEK VAR B - Pouze pøehled odvìtví, kde v prùbìhu let mzdy klesají (bez dalších údajù).
SELECT 
	DISTINCT tlzpspf1.industry 
FROM t_libor_zizala_project_sql_primary_final tlzpspf1
JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
	ON tlzpspf1.industry = tlzpspf2.industry
	AND tlzpspf1.year_id = tlzpspf2.year_id +1
	AND (tlzpspf1.avg_wages / tlzpspf2.avg_wages) < 1
WHERE	
	tlzpspf1.avg_wages IS NOT NULL 
	OR tlzpspf1.industry IS NOT NULL
ORDER BY industry ; 


-- 2. TASK: Kolik je možné si koupit litrù mléka a kilogramù chleba za první a poslední srovnatelné období v dostupných
-- ...datech cen a mezd?
WITH foods AS 
	(SELECT 
		food_category,
		avg_price,
		price_unit, 
		year_id	  
	FROM t_libor_zizala_project_sql_primary_final  
	WHERE 
		(food_category LIKE 'Mlék%'
		OR food_category LIKE 'Chléb%')
		AND 
		(	year_id IN 
			(	SELECT 
					DISTINCT MIN(year_id) 		
				FROM t_libor_zizala_project_sql_primary_final
			) 
		  OR 
			year_id IN 
			(	SELECT 
					DISTINCT MAX(year_id) 		
				FROM t_libor_zizala_project_sql_primary_final
			)
		) 	
	 ), -- výbìr potravin a jejich cen v min a max roku 
	wages AS	
	(SELECT 
		year_id,
		avg (avg_wages) AS cum_avg_wages
	FROM t_libor_zizala_project_sql_primary_final
	WHERE
		year_id IN 
			(	SELECT 
					DISTINCT MIN(year_id) 		
				FROM t_libor_zizala_project_sql_primary_final
			) 
			OR 
			year_id IN 
			(	SELECT 
					DISTINCT MAX(year_id) 		
				FROM t_libor_zizala_project_sql_primary_final
			)	
	GROUP BY year_id 
	) -- výbìr platù v min a max roku  
SELECT 
	foods.food_category,
	foods.avg_price,
	foods.price_unit, 
	foods.year_id,
	wages.cum_avg_wages,
	round( wages.cum_avg_wages / foods.avg_price,2) AS 'units per avg. wage'
FROM foods 
JOIN wages 
	ON foods.year_id = wages.year_id ;
	

-- 3. TASK: Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroèní nárùst)?
-- 3.VÝSLEDEK VAR A - srovnání jen meziroèního nárùstu kategorie potravin v historii dat mezi dvìma roky - od nejnižšího 
SELECT 
	tlzpspf1.food_category,
	tlzpspf2.year_id  AS prev_year_id,
	tlzpspf2.avg_price AS py_avg_price,
	tlzpspf1.year_id,
	tlzpspf1.avg_price ,
	round (tlzpspf1.avg_price / tlzpspf2.avg_price , 2) * 100 AS y_y_koef_pct
FROM t_libor_zizala_project_sql_primary_final tlzpspf1
JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
	ON tlzpspf1.food_category = tlzpspf2.food_category 
	AND tlzpspf1.year_id = tlzpspf2.year_id +1
WHERE	
	tlzpspf1.food_category IS NOT NULL
ORDER BY y_y_koef_pct ;

-- 3.VÝSLEDEK VAR B - srovnání dle prùmìrného meziroèního nárùstu za celé sledované období
WITH y_y_all_years AS 
	(SELECT 
		tlzpspf1.food_category,
		tlzpspf2.year_id  AS prev_year_id,
		tlzpspf2.avg_price AS py_avg_price,
		tlzpspf1.year_id,
		tlzpspf1.avg_price ,
		round (tlzpspf1.avg_price / tlzpspf2.avg_price , 2) * 100 AS y_y_koef_pct
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.food_category = tlzpspf2.food_category 
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.food_category IS NOT NULL
	ORDER BY y_y_koef_pct
	) -- pøehled všech meziroèníh zmìn cen v % po jednotlivých kategoriích potravin
SELECT 
	food_category ,
	round (avg (y_y_koef_pct ), 0)	AS avg_y_y_pct
FROM y_y_all_years
GROUP BY food_category 
ORDER BY avg_y_y_pct  ;

-- 3.VÝSLEDEK VAR C - nejnižší nárùst cen za celé sledované období kumulativnì 
WITH oldest AS 
	(SELECT 
		food_category,
		price_unit, 
		year_id,
		avg_price					  
	FROM t_libor_zizala_project_sql_primary_final  
	WHERE 
		food_category IS NOT NULL 
		AND 
		year_id IN 
			(SELECT 
					DISTINCT MIN(year_id) 		
			 FROM t_libor_zizala_project_sql_primary_final
			)		  
	GROUP BY food_category, year_id
	), -- výtah cen pro nejnižší dostupný rok 
	youngest AS
	(SELECT 
		food_category,
		price_unit,
		year_id,
		avg_price					  
	FROM t_libor_zizala_project_sql_primary_final  
	WHERE 
		food_category IS NOT NULL 
		AND 
		year_id IN 
			(SELECT 
					DISTINCT MAX (year_id) 		
			 FROM t_libor_zizala_project_sql_primary_final
			)		  
	GROUP BY food_category, year_id
	) -- výtah cen pro nejvyšší dostupný rok
SELECT 
	oldest.food_category,
	oldest.price_unit,
	oldest.year_id,
	oldest.avg_price,
	youngest.year_id,
	youngest.avg_price,
	round( youngest.avg_price / oldest.avg_price * 100 -100,0) AS 'total_pct_change'
FROM oldest  
JOIN youngest  
	ON oldest.food_category = youngest.food_category 
ORDER BY total_pct_change ;

	
-- 4. TASK: Existuje rok, ve kterém byl meziroèní nárùst cen potravin výraznì vyšší než rùst mezd (vìtší než 10 %)?
-- 4. VÝSLEDEK - Z dat vyplývá, že nikoliv. 
WITH tot_wages AS -- meziroèní nárùst mezd dohromady podle let
	(SELECT 
		-- tlzpspf1.industry,
		tlzpspf1.year_id,
		-- tlzpspf1.avg_wages ,
		-- tlzpspf2.year_id  AS prev_year_id,
		-- tlzpspf2.avg_wages AS py_avg_wages,
		round( avg(tlzpspf1.avg_wages / tlzpspf2.avg_wages) * 100, 1) AS y_y_wages_pct		
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.industry = tlzpspf2.industry
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.avg_wages / tlzpspf2.avg_wages > 1
		AND tlzpspf1.avg_wages IS NOT NULL	
	GROUP BY tlzpspf1.year_id 
	ORDER BY year_id  
			-- avg_y_wages 
	),
	tot_prices AS -- mezoroèní nárùst cen potravin dohromady podle let 
	(SELECT 
		-- tlzpspf1.food_category,
		-- tlzpspf2.year_id  AS prev_year_id,
		-- tlzpspf2.avg_price AS py_avg_price,
		tlzpspf1.year_id,
		-- tlzpspf1.avg_price ,
		round( avg(tlzpspf1.avg_price / tlzpspf2.avg_price) * 100, 1) AS y_y_price_pct
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.food_category = tlzpspf2.food_category 
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.food_category IS NOT NULL
		AND tlzpspf1.avg_price / tlzpspf2.avg_price > 1
	GROUP BY tlzpspf1.year_id 
	ORDER BY year_id 
			-- y_y_price_pct
	)
SELECT -- porovnání meziroèního nárùst mezd s meziroèním nárùstem cen potravin seøazeným dle velikosti diference
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct,
	tot_prices.y_y_price_pct,
	tot_prices.y_y_price_pct - tot_wages.y_y_wages_pct AS y_y_w_p_diff_pct 
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
ORDER BY y_y_w_p_diff_pct ;



-- (B) AGREGAÈNÍ tabulka -> t_libor_zizala_project_SQL_secondary_final (pro dodateèná data o dalších evropských státech)
-- -> výbìr podstatných polí pro za všechny státy 
CREATE OR REPLACE VIEW v_libor_zizala_project_SQL_secondary_final AS   -- nejprve pro snazší odladìní vytvoøeno VIEW
SELECT
	country ,
	`year` ,
	GDP 
FROM economies  
WHERE 
	GDP IS NOT NULL ;

SELECT 	-- kontrolní výstup z pøedpøipravené tabulky pro ÈR
	*
FROM v_libor_zizala_project_sql_secondary_final  
WHERE 
	country LIKE 'Czech%'	
ORDER BY country ;

CREATE OR REPLACE TABLE t_libor_zizala_project_SQL_secondary_final AS  -- z VIEW vytvoøena požadovaná tabulka
SELECT *
FROM v_libor_zizala_project_SQL_secondary_final;



-- 5. Má výška HDP vliv na zmìny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výraznìji v jednom roce, 
-- ...projeví se to na cenách potravin èi mzdách ve stejném nebo následujícím roce výraznìjším rùstem?
-- VAR A - Analýza dopadu závislosti na HDP ze stejného roku 
WITH tot_GDP AS -- meziroèní nárùst GDP podle let pro ÈR 
	(SELECT 
		tlzpssf1.country ,	
		tlzpssf1.`year`,
		round ((tlzpssf1.GDP / tlzpssf2.GDP) * 100, 1) AS y_y_gdp_pct		
	FROM t_libor_zizala_project_sql_secondary_final tlzpssf1 
	JOIN t_libor_zizala_project_sql_secondary_final tlzpssf2 
		ON tlzpssf1.country = tlzpssf2.country 
		AND tlzpssf1.year = tlzpssf2.year +1
	WHERE 
		tlzpssf1.country LIKE 'Czech%'	
	GROUP BY tlzpssf1.country, tlzpssf1.`year`
	ORDER BY tlzpssf1.`year` 
	),
	tot_wages AS -- meziroèní nárùst mezd dohromady podle let
	(SELECT 
		tlzpspf1.year_id,		
		round( avg(tlzpspf1.avg_wages / tlzpspf2.avg_wages) * 100, 1) AS y_y_wages_pct		
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.industry = tlzpspf2.industry
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.avg_wages / tlzpspf2.avg_wages > 1
		AND tlzpspf1.avg_wages IS NOT NULL	
	GROUP BY tlzpspf1.year_id 
	ORDER BY year_id  
			-- avg_y_wages 
	),
	tot_prices AS -- mezoroèní nárùst cen potravin dohromady podle let 
	(SELECT 
		tlzpspf1.year_id,		
		round( avg(tlzpspf1.avg_price / tlzpspf2.avg_price) * 100, 1) AS y_y_price_pct
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.food_category = tlzpspf2.food_category 
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.food_category IS NOT NULL
		AND tlzpspf1.avg_price / tlzpspf2.avg_price > 1
	GROUP BY tlzpspf1.year_id 
	ORDER BY year_id		
	)
SELECT -- porovnání meziroèního nárùst mezd cen potravin a GDP v témže roce
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct -100 AS wages_growth_pct,
	tot_prices.y_y_price_pct -100 AS price_growth_pct,
	tot_GDP.y_y_gdp_pct -100 AS gdp_growth_pct	
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
JOIN tot_GDP  
	ON tot_wages.year_id = tot_GDP.YEAR       -- ve vazbì na nárùst GDP z téhož roku
ORDER BY tot_wages.year_id ;


-- VAR B - Analýza dopadu závislosti na zmìnì HDP z pøedchozího roku 
  WITH tot_GDP AS -- meziroèní nárùst GDP podle let pro ÈR 
	(SELECT 
		tlzpssf1.country ,	
		tlzpssf1.`year`,
		round ((tlzpssf1.GDP / tlzpssf2.GDP) * 100, 1) AS y_y_gdp_pct		
	FROM t_libor_zizala_project_sql_secondary_final tlzpssf1 
	JOIN t_libor_zizala_project_sql_secondary_final tlzpssf2 
		ON tlzpssf1.country = tlzpssf2.country 
		AND tlzpssf1.year = tlzpssf2.year +1
	WHERE 
		tlzpssf1.country LIKE 'Czech%'	
	GROUP BY tlzpssf1.country, tlzpssf1.`year`
	ORDER BY tlzpssf1.`year` 
	),
	tot_wages AS -- meziroèní nárùst mezd dohromady podle let
	(SELECT 
		tlzpspf1.year_id,		
		round( avg(tlzpspf1.avg_wages / tlzpspf2.avg_wages) * 100, 1) AS y_y_wages_pct		
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.industry = tlzpspf2.industry
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.avg_wages / tlzpspf2.avg_wages > 1
		AND tlzpspf1.avg_wages IS NOT NULL	
	GROUP BY tlzpspf1.year_id 
	ORDER BY year_id  
			-- avg_y_wages 
	),
	tot_prices AS -- mezoroèní nárùst cen potravin dohromady podle let 
	(SELECT 
		tlzpspf1.year_id,		
		round( avg(tlzpspf1.avg_price / tlzpspf2.avg_price) * 100, 1) AS y_y_price_pct
	FROM t_libor_zizala_project_sql_primary_final tlzpspf1
	JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
		ON tlzpspf1.food_category = tlzpspf2.food_category 
		AND tlzpspf1.year_id = tlzpspf2.year_id +1
	WHERE	
		tlzpspf1.food_category IS NOT NULL
		AND tlzpspf1.avg_price / tlzpspf2.avg_price > 1
	GROUP BY tlzpspf1.year_id 
	ORDER BY year_id		
	)
SELECT -- porovnání meziroèního nárùst mezd cen potravin a nárùstu GDP v pøedchozím roce (vliv dopadu s roèním zpoždìním)
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct -100 AS wages_growth_pct,
	tot_prices.y_y_price_pct -100 AS price_growth_pct,
	tot_GDP.y_y_gdp_pct -100 AS py_gdp_growth_pct	
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
JOIN tot_GDP  
	ON tot_wages.year_id = tot_GDP.YEAR +1      -- ve vazbì na nárùst GDP z pøedchozího roku  
ORDER BY tot_wages.year_id ;

-- Analýza závislosti provedena v samostatném Excel. souboru Task_5_HDP_vliv_na_mzdy_a_ceny.xlsx :
-- Pro jednotlivé zkoumané závislosti provedena regresní analýza (pro zjednodušení omezena na modelaci lineární regrese).
-- Vyšší míra závislosti na GDP nalezena u mezd nežli u cen potravin - vyjádøena proloženou regersní pøímkou a vyjádøena rovnicí.



