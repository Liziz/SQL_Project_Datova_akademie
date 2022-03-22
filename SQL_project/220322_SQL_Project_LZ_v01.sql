-- ------------------------------------ Datov� akademie - SQL project ------------------------------------------------------------------------------

-- Zadani projektu --
-- 1. Rostou v pr�b�hu let mzdy ve v�ech odv�tv�ch, nebo v n�kter�ch klesaj�?
-- 2. Kolik je mo�n� si koupit litr� ml�ka a kilogram� chleba za prvn� a posledn� srovnateln� obdob� v dostupn�ch datech
--    cen a mezd?
-- 3. Kter� kategorie potravin zdra�uje nejpomaleji (je u n� nejni��� percentu�ln� meziro�n� n�r�st)?
-- 4. Existuje rok, ve kter�m byl meziro�n� n�r�st cen potravin v�razn� vy��� ne� r�st mezd (v�t�� ne� 10 %)?
-- 5. M� v��ka HDP vliv na zm�ny ve mzd�ch a cen�ch potravin? Neboli, pokud HDP vzroste v�razn�ji v jednom roce, projev�
--    se to na cen�ch potravin �i mzd�ch --    ve stejn�m nebo n�sduj�c�m roce v�razn�j��m r�stem?

-- Zad�n� V�stupu - DVE TABULKY v databazi, ze kter�ch se data daj� ziskat: 
-- -> t_libor_zizala_project_SQL_primary_final (pro data mezd a cen potravin za CR sjednocenech na totozne porovnatelne
--    obdobi � spole�n� roky) a
-- -> t_libor_zizala_project_SQL_secondary_final (pro dodatecna data o dalsich evropskych statech)
--
-- -> Pripravte sadu SQL, ktere z pripravenych tabulek ziskaji datovy podklad k odpovezeni na vytycene vyzkumne otazky


-- �E�EN� --

-- (A) AGREGA�N� tabulka -> t_libor_zizala_project_SQL_primary_final 
-- (pro data mezd a cen potravin za CR sjednocenech na totozne porovnatelne obdobi � spole�n� roky)

-- v�b�r a spojen� podstatn�ch pol� kolem MZDY a CENY
CREATE OR REPLACE VIEW v_libor_zizala_project_SQL_primary_final AS -- nejkrpve vytvo�eno VIEW pro snaz�� odlad�n� 
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

CREATE OR REPLACE TABLE t_libor_zizala_project_SQL_primary_final AS   -- n�sledn� vytvo�ena po�adovan� tabulka
SELECT *
FROM v_libor_zizala_project_SQL_primary_final;

    
-- 1.TASK: Rostou v pr�b�hu let mzdy ve v�ech odv�tv�ch, nebo v n�kter�ch klesaj�?
-- 1.V�SLEDEK VAR A - P�ehledov� tabulka s v�ce �daji, z n� lze v�sledek snadno vy��st:
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

-- 1.V�SLEDEK VAR B - Pouze p�ehled odv�tv�, kde v pr�b�hu let mzdy klesaj� (bez dal��ch �daj�).
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


-- 2. TASK: Kolik je mo�n� si koupit litr� ml�ka a kilogram� chleba za prvn� a posledn� srovnateln� obdob� v dostupn�ch
-- ...datech cen a mezd?
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
	 ), -- v�b�r potravin a jejich cen v min a max roku 
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
	) -- v�b�r plat� v min a max roku  
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
	

-- 3. TASK: Kter� kategorie potravin zdra�uje nejpomaleji (je u n� nejni��� percentu�ln� meziro�n� n�r�st)?
-- 3.V�SLEDEK VAR A - srovn�n� jen meziro�n�ho n�r�stu kategorie potravin v historii dat mezi dv�ma roky - od nejni���ho 
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

-- 3.V�SLEDEK VAR B - srovn�n� dle pr�m�rn�ho meziro�n�ho n�r�stu za cel� sledovan� obdob�
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
	) -- p�ehled v�ech meziro�n�h zm�n cen v % po jednotliv�ch kategori�ch potravin
SELECT 
	food_category ,
	round (avg (y_y_koef_pct ), 0)	AS avg_y_y_pct
FROM y_y_all_years
GROUP BY food_category 
ORDER BY avg_y_y_pct  ;

-- 3.V�SLEDEK VAR C - nejni��� n�r�st cen za cel� sledovan� obdob� kumulativn� 
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
	), -- v�tah cen pro nejni��� dostupn� rok 
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
	) -- v�tah cen pro nejvy��� dostupn� rok
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

	
-- 4. TASK: Existuje rok, ve kter�m byl meziro�n� n�r�st cen potravin v�razn� vy��� ne� r�st mezd (v�t�� ne� 10 %)?
-- 4. V�SLEDEK - Z dat vypl�v�, �e nikoliv. 
WITH tot_wages AS -- meziro�n� n�r�st mezd dohromady podle let
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
	tot_prices AS -- mezoro�n� n�r�st cen potravin dohromady podle let 
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
SELECT -- porovn�n� meziro�n�ho n�r�st mezd s meziro�n�m n�r�stem cen potravin se�azen�m dle velikosti diference
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct,
	tot_prices.y_y_price_pct,
	tot_prices.y_y_price_pct - tot_wages.y_y_wages_pct AS y_y_w_p_diff_pct 
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
ORDER BY y_y_w_p_diff_pct ;



-- (B) AGREGA�N� tabulka -> t_libor_zizala_project_SQL_secondary_final (pro dodate�n� data o dal��ch evropsk�ch st�tech)
-- -> v�b�r podstatn�ch pol� pro za v�echny st�ty 
CREATE OR REPLACE VIEW v_libor_zizala_project_SQL_secondary_final AS   -- nejprve pro snaz�� odlad�n� vytvo�eno VIEW
SELECT
	country ,
	`year` ,
	GDP 
FROM economies  
WHERE 
	GDP IS NOT NULL ;

SELECT 	-- kontroln� v�stup z p�edp�ipraven� tabulky pro �R
	*
FROM v_libor_zizala_project_sql_secondary_final  
WHERE 
	country LIKE 'Czech%'	
ORDER BY country ;

CREATE OR REPLACE TABLE t_libor_zizala_project_SQL_secondary_final AS  -- z VIEW vytvo�ena po�adovan� tabulka
SELECT *
FROM v_libor_zizala_project_SQL_secondary_final;



-- 5. M� v��ka HDP vliv na zm�ny ve mzd�ch a cen�ch potravin? Neboli, pokud HDP vzroste v�razn�ji v jednom roce, 
-- ...projev� se to na cen�ch potravin �i mzd�ch ve stejn�m nebo n�sleduj�c�m roce v�razn�j��m r�stem?
-- VAR A - Anal�za dopadu z�vislosti na HDP ze stejn�ho roku 
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
	tot_wages AS -- meziro�n� n�r�st mezd dohromady podle let
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
	tot_prices AS -- mezoro�n� n�r�st cen potravin dohromady podle let 
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
SELECT -- porovn�n� meziro�n�ho n�r�st mezd cen potravin a GDP v t�m�e roce
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct -100 AS wages_growth_pct,
	tot_prices.y_y_price_pct -100 AS price_growth_pct,
	tot_GDP.y_y_gdp_pct -100 AS gdp_growth_pct	
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
JOIN tot_GDP  
	ON tot_wages.year_id = tot_GDP.YEAR       -- ve vazb� na n�r�st GDP z t�ho� roku
ORDER BY tot_wages.year_id ;


-- VAR B - Anal�za dopadu z�vislosti na zm�n� HDP z p�edchoz�ho roku 
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
	tot_wages AS -- meziro�n� n�r�st mezd dohromady podle let
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
	tot_prices AS -- mezoro�n� n�r�st cen potravin dohromady podle let 
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
SELECT -- porovn�n� meziro�n�ho n�r�st mezd cen potravin a n�r�stu GDP v p�edchoz�m roce (vliv dopadu s ro�n�m zpo�d�n�m)
	tot_wages.year_id ,
	tot_wages.y_y_wages_pct -100 AS wages_growth_pct,
	tot_prices.y_y_price_pct -100 AS price_growth_pct,
	tot_GDP.y_y_gdp_pct -100 AS py_gdp_growth_pct	
FROM tot_wages 
JOIN tot_prices 
	ON tot_wages.year_id = tot_prices.year_id
JOIN tot_GDP  
	ON tot_wages.year_id = tot_GDP.YEAR +1      -- ve vazb� na n�r�st GDP z p�edchoz�ho roku  
ORDER BY tot_wages.year_id ;

-- Anal�za z�vislosti provedena v samostatn�m Excel. souboru Task_5_HDP_vliv_na_mzdy_a_ceny.xlsx :
-- Pro jednotliv� zkouman� z�vislosti provedena regresn� anal�za (pro zjednodu�en� omezena na modelaci line�rn� regrese).
-- Vy��� m�ra z�vislosti na GDP nalezena u mezd ne�li u cen potravin - vyj�d�ena prolo�enou regersn� p��mkou a vyj�d�ena rovnic�.



