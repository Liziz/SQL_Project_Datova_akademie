# SQL_Project_Datová_akademie
Projekt v rámci datové akademie Engeto.

-- ZADÁNÍ PROJEKTU--
1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech
   cen a mezd?
3. Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální mezirořní nárůst)?
4. Existuje rok, ve kterém byl mezirořní nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
5. Má výša HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví
   se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?

Zadání Výstupu - DVĚ TABULKY v databázi, ze kterých se data dají ziskat: 
-> t_libor_zizala_project_SQL_primary_final (pro data mezd a cen potravin za CR sjednocenech na totozne porovnatelne
   obdobi – společné roky) a
-> t_libor_zizala_project_SQL_secondary_final (pro dodatecna data o dalsich evropskych statech)

-> Připravte sadu SQL, které z připravených tabulek získaji datový podklad k odpovězení na vytyčené výzkumne otázky.


-- ŘEŠENÍ --

(A) Sestavění AGREGAČNÍ tabulky -> t_libor_zizala_project_SQL_primary_final 
(pro data mezd a cen potravin za CR sjednocených na totožné porovnatelné období - společné roky)
    - spojení dvou rozdílných datových sad přes UNION do jedné tabulky, kde bude možné dále zpracovat dle časového hlediska

1.TASK: Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
  Odpověď: V některých odvětvích mzdy meziročně klesají. Přehled odvětví a roky, kdy mzdy mezoričně klesaly lze vidět ve výsledku 
  dotazu 1 VAR A - všude, kde je ve sloupci "y_y_koef" číslo menší než 1, se jedná o meziroční pokles mezd. Slovně je pak uvedeno 
  ve sloupci "Wages-mezirocne".   
  Ve výsledku dotazu 1 VAR B je pak pouze výpis odvětví, ve kterých doško kdykoliv během sledovaného období k mezirčnímu poklesu mezd.

2.TASK: Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných
  datech cen a mezd?
  Odpověď: 
  Za první sledované období (2006) lze za průmněrnou mzdu koupit 1.261,9 chlebů a 1.408,8 mlék.
  Za poslední sledované období (2018) lze za průmněrnou mzdu koupit 1.319,3 chlebů a 1.613,6 mlék. 

3.TASK: Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
  Odpověď: Otázka je položena velmi obecně, proto podle mne existuje více odpovědí polde kontextu:
  Nejmenší meziroční změna cen (pokud nás zajímá i pokles cen) byla zaznamenána u rajských jablek v roce 2007 - pokles na 70% cen př. roku (viz VAR A).
  Nejmenší změna cen v kumulaci za celé sledované období bylo vidět u cukru krytsalového - pokles ceny o více jak 27% (viz. VAR C).

4.TASK: Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
  Odpověď: V rámci sledovaného období je nejvyšší rozdíl mezi růstem cen potravin a růstem mezd 8,3% (v roce 2010). 
  Proto nelze říci, že by ve sledovaném období existoval rok, kde by potraviny rostly o více jak 10% rychleji než mzdy.



(B) Sestavení AGREGAČNÍ tabulky -> t_libor_zizala_project_SQL_secondary_final (pro dodatečná data o dalších evropských státech)
    - výběr podstatných polí z původní tabulky pro za všechny státy

5.TASK: Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, 
  projeví se to na cenách potravin či mzdách ve stejném nebo následujícím roce výraznějším růstem?
  Odpověď: Srovnání proběhlo ve dvou variantách 
    - VAR A (mezroční nůrůsty u GDP, cen i mezd porovnány za stejná období) a 
    - VAR B (mezroční nůrůsty cen i mezd porovnány s meziročním růstem GDP vždy z předchozího roku - zkoumán vliv při ročním zpoždění). 
  Analýza závislosti provedena v samostatném Excel. souboru Task_5_HDP_vliv_na_mzdy_a_ceny.xlsx, kam byla výsledná data z dotazů vyexportována.
  Pro jednotlivé zkoumané závislosti provedena regresní analýza (pro zjednodušení omezena jen na modelaci lineární regrese).
  Do grafů byla doplněna rovnice lineárního trendu a koeficient spolehlivosti (R2).
  Z výsledků vyplývá, že závislost cen potravin a mezd na GDP není ani v jednom z případů vysoká. V rámci analýzy dle VAR A (stejný rok)
  byl interval spolehlivosti na velmi nízké úrovni (R2 < 0,15), tj. lineární závislost je velice nízká.
  V rámci analýzy dle VAR B (tj. GDP změna předchozí rok) byla závislst cen potravin prakticky nulová. Naopak závislost růstu mezd  
  na změně GDP byla ze všech analyzovaných případů nejvyšší (R2 = 0,52). Tato vyšší hodnota potvrzuje určitou míru závislosti
  růstu mezd na růstu GDP z předchozího roku, ale ani tato závislost není nijak zásadně silná.   
