-- ------------------------------------ Datová akademie - SQL project ------------------------------------------------------------------------------

-- Zadáni projektu --
-- 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
-- 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech
--    ... cen a mezd?
-- 3. Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální mezirořní nárůst)?
-- 4. Existuje rok, ve kterém byl mezirořní nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
-- 5. Má výša HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví
--    se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?

-- Zadání Výstupu - DVĚ TABULKY v databázi, ze kterých se data dají ziskat: 
-- -> t_libor_zizala_project_SQL_primary_final (pro data mezd a cen potravin za CR sjednocenech na totozne porovnatelne
--    obdobi – společné roky) a
-- -> t_libor_zizala_project_SQL_secondary_final (pro dodatecna data o dalsich evropskych statech)

-- -> Připravte sadu SQL, které z připravených tabulek získaji datový podklad k odpovězení na vytyčené výzkumne otázky.


-- ŘEŠENÍ --

-- (A) AGREGAČNÍ tabulka -> t_libor_zizala_project_SQL_primary_final 
-- (pro data mezd a cen potravin za CR sjednocených na totožné porovnatelné období - společné roky)

-- výběr a spojení podstatných polí kolem MZDY a CENY
CREATE OR REPLACE VIEW v_libor_zizala_project_SQL_primary_final AS -- nejrpve vytvořeno VIEW pro snazší odladění 
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

CREATE OR REPLACE TABLE t_libor_zizala_project_SQL_primary_final AS   -- následně vytvořena požadovaná tabulka
SELECT *
FROM v_libor_zizala_project_SQL_primary_final;

    
-- 1.TASK: Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
-- Odpověď TASK 1: V některých odvětvích mzdy meziročně klesají. Přehled odvětví a roky, kdy mzdy mezoričně klesaly lze vidět ve výsledku 
-- ... dotazu 1 VAR A - všude, kde je ve sloupci "y_y_koef" číslo menší než 1, se jedná o meziroční pokles mezd. Slovně je pak uvedeno 
-- ... ve sloupci "Wages-mezirocne".   
-- ... Ve výsledku dotazu 1 VAR B je pak pouze výpis odvětví, ve kterých doško kdykoliv během sledovaného období k mezirčnímu poklesu mezd.

-- 1.VÝSLEDEK VAR A - Přehledová tabulka s více údaji, z níž lze výsledek snadno vyčíst:
SELECT 
	tlzpspf1.industry,
	tlzpspf1.year_id,
	tlzpspf1.avg_wages ,
	tlzpspf2.year_id  AS prev_year_id,
	tlzpspf2.avg_wages AS py_avg_wages,
	round (tlzpspf1.avg_wages / tlzpspf2.avg_wages,3) AS y_y_koef,
	CASE
        WHEN tlzpspf1.avg_wages < tlzpspf2.avg_wages THEN 'meziro�n� pokles'
        WHEN  tlzpspf1.avg_wages = tlzpspf2.avg_wages THEN 'meziro�n� stagnace'
        ELSE 'meziro�n� r�st'
    END AS wages_mezirocne	
FROM t_libor_zizala_project_sql_primary_final tlzpspf1
JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
	ON tlzpspf1.industry = tlzpspf2.industry
	AND tlzpspf1.year_id = tlzpspf2.year_id +1
WHERE	
	tlzpspf1.avg_wages IS NOT NULL 
	OR tlzpspf1.industry IS NOT NULL
ORDER BY y_y_koef  ; 

-- 1.VÝSLEDEK VAR B - Pouze přehled odvětví, kde v průběhu let mzdy klesají (bez dalších údajů).
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



-- 2. TASK: Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných
-- ...datech cen a mezd?
-- Odpověď TASK 2: 
-- ... Za první sledované období (2006) lze za průmněrnou mzdu koupit 1.261,9 chlebů a 1.408,8 mlék.
-- ... Za poslední sledované období (2018) lze za průmněrnou mzdu koupit 1.319,3 chlebů a 1.613,6 mlék. 

WITH foods AS 
	(SELECT 
		food_category,
		avg_price,
		price_unit, 
		year_id	  
	FROM t_libor_zizala_project_sql_primary_final  
	WHERE 
		(food_category LIKE 'Ml�k%'
		OR food_category LIKE 'Chl�b%')
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
	 ), -- výběr potravin a jejich cen v min a max roku 
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
	) -- výběr platů v min a max roku  
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
	

-- 3. TASK: Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
-- Odpověď TASK 3: Otázka je položena velmi obecně, proto podle mne existuje více odpovědí polde kontextu:
-- Nejmenší meziroční změna cen (pokud nás zajímá i pokles cen) byla zaznamenána u rajských jablek v roce 2007 - pokles na 70% cen př. roku.
-- Nejmenší změna cen v kumulaci za celé sledované období bylo vidět u cukru krytsalového - pokles ceny o více jak 27%

-- 3.VÝSLEDEK VAR A - srovnání jen meziročního nárůstu kategorie potravin v historii dat mezi dvěma roky - od nejnižšího  
SELECT 
	tlzpspf1.food_category,
	tlzpspf2.year_id  AS prev_year_id,
	tlzpspf2.avg_price AS py_avg_price,
	tlzpspf1.year_id,
	tlzpspf1.avg_price ,
	round (tlzpspf1.avg_price / tlzpspf2.avg_price , 4) * 100 AS y_y_koef_pct
FROM t_libor_zizala_project_sql_primary_final tlzpspf1
JOIN t_libor_zizala_project_sql_primary_final tlzpspf2
	ON tlzpspf1.food_category = tlzpspf2.food_category 
	AND tlzpspf1.year_id = tlzpspf2.year_id +1
WHERE	
	tlzpspf1.food_category IS NOT NULL
ORDER BY y_y_koef_pct ;

-- 3.VÝSLEDEK VAR B - srovnání dle průměrného meziročního nárůstu za celé sledované období
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
	) -- přehled všech meziročníh změn cen v % po jednotlivých kategoriích potravin
SELECT 
	food_category ,
	round (avg (y_y_koef_pct ), 0)	AS avg_y_y_pct
FROM y_y_all_years
GROUP BY food_category 
ORDER BY avg_y_y_pct  ;

-- 3.VÝSLEDEK VAR C - nejnižší nárůst cen za celé sledované období kumulativně 
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
	round( youngest.avg_price / oldest.avg_price * 100 -100,2) AS 'total_pct_change'
FROM oldest  
JOIN youngest  
	ON oldest.food_category = youngest.food_category 
ORDER BY total_pct_change ;

	
-- 4. TASK: Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
-- Odpověď TASK 4: V rámci sledovaného období je nejvyšší rozdíl mezi růstem cen potravin a růstem mezd 8,3% (v roce 2010). 
-- ... Proto nelze říci, že by ve sledovaném období existoval rok, kde by potraviny rostly o více jak 10% rychleji než mzdy.
 
WITH tot_wages AS -- meziroční nárůst mezd dohromady podle let
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
	tot_prices AS -- mezoroční nárůst cen potravin dohromady podle let 
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
SELECT -- porovnání meziročního nárůst mezd s meziročním nárůstem cen potravin seřazeným dle velikosti diference
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct,
	tot_prices.y_y_price_pct,
	tot_prices.y_y_price_pct - tot_wages.y_y_wages_pct AS y_y_w_p_diff_pct 
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
ORDER BY y_y_w_p_diff_pct ;



-- (B) AGREGAČNÍ tabulka -> t_libor_zizala_project_SQL_secondary_final (pro dodatečná data o dalších evropských státech)
-- -> výběr podstatných polí pro za všechny státy  
CREATE OR REPLACE VIEW v_libor_zizala_project_SQL_secondary_final AS   -- nejprve pro snaz�� odlad�n� vytvo�eno VIEW
SELECT
	country ,
	`year` ,
	GDP 
FROM economies  
WHERE 
	GDP IS NOT NULL ;

SELECT 	-- kontrolní výstup z předpřipravené tabulky pro ČR
	*
FROM v_libor_zizala_project_sql_secondary_final  
WHERE 
	country LIKE 'Czech%'	
ORDER BY country ;

CREATE OR REPLACE TABLE t_libor_zizala_project_SQL_secondary_final AS  -- z VIEW vytvořena požadovaná tabulka
SELECT *
FROM v_libor_zizala_project_SQL_secondary_final;



-- 5. TASK: Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, 
-- ...projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?
-- Odpověď TASK 5: Srovnání proběhlo ve dvou variantách - VAR A (mezroční nůrůsty u GDP, cen i mezd porovnány za stejná období) a 
-- ... VAR B (mezroční nůrůsty cen i mezd porovnány s meziročním růstem GDP vždy z předchozího roku - zkoumán vliv při ročním zpoždění). 
-- Analýza závislosti provedena v samostatném Excel. souboru Task_5_HDP_vliv_na_mzdy_a_ceny.xlsx, kam byla výsledná data z dotazů vyexportována.
-- Pro jednotlivé zkoumané závislosti provedena regresní analýza (pro zjednodušení omezena jen na modelaci lineární regrese).
-- Do grafů byla doplněna rovnice lineárního trendu a koeficient spolehlivosti (R2).
-- Z výsledků vyplývá, že závislost cen potravin a mezd na GDP není ani v jednom z případů vysoká. V rámci analýzy dle VAR A (stejný rok)
-- ... byl interval spolehlivosti na velmi nízké úrovni (R2 < 0,15), tj. lineární závislost je velice nízká.
-- V rámci analýzy dle VAR B (tj. GDP změna předchozí rok) byla závislst cen potravin prakticky nulová. Naopak závislost růstu mezd  
-- ... na změně GDP byla ze všech analyzovaných případů nejvyšší (R2 = 0,52). Tato vyšší hodnota potvrzuje určitou míru závislosti
-- ... růstu mezd na růstu GDP z předchozího roku, ale ani tato závislost není nijak zásadně silná.   

-- VAR A - Analýza dopadu závislosti na HDP ze stejného roku 
WITH tot_GDP AS -- meziro�n� n�r�st GDP podle let pro �R 
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
	tot_wages AS -- meziroční nárůst mezd dohromady podle let
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
	tot_prices AS -- meziroční nárůst cen potravin dohromady podle let  
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
SELECT -- porovnání meziročního nárůst mezd cen potravin a GDP v témže roce
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct -100 AS wages_growth_pct,
	tot_prices.y_y_price_pct -100 AS price_growth_pct,
	tot_GDP.y_y_gdp_pct -100 AS gdp_growth_pct	
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
JOIN tot_GDP  
	ON tot_wages.year_id = tot_GDP.YEAR       -- ve vazbě na nárůst GDP z téhož roku
ORDER BY tot_wages.year_id ;


-- VAR B - Analýza dopadu závislosti na změně HDP z předchozího roku 
  WITH tot_GDP AS -- meziroční nárůst GDP podle let pro ČR
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
	tot_wages AS -- meziroční nárůst mezd dohromady podle let
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
	tot_prices AS -- meziroční nárůst cen potravin dohromady podle let 
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
SELECT -- porovnání meziročního nárůst mezd cen potravin a nárůstu GDP v předchozím roce (vliv dopadu s ročním zpožděním)
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct -100 AS wages_growth_pct,
	tot_prices.y_y_price_pct -100 AS price_growth_pct,
	tot_GDP.y_y_gdp_pct -100 AS py_gdp_growth_pct	
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
JOIN tot_GDP  
	ON tot_wages.year_id = tot_GDP.YEAR +1      -- ve vazbě na nárůst GDP z předchozího roku  
ORDER BY tot_wages.year_id ;





