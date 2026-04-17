/*
====================================================================================================================================================================================
WREL036 - Notas que Compoem o ICMS de Entrada por CFOP
Observacoes do Lima:
-- MUDEI A CONTABILIZAÇÃO DA BASE E DO VALOR DE ICMS, CONDICIONANDO SE O VALOR DO CREDITO DO SIMPLES É MAIOR QUE 0 ENTÃO PEGA O VALOR DO VREDITO DO SIMPLES 
-- SE NÃO PEGA O VALOR NORMAL DO ICMS 15/02/2018
-- TIREI A FINALIDADE DE EMISSÃO = DEVOLUÇÃO (TBS080), PQ PODE TER RECOMPRA COM FINALIDADE = 1 (NORMAL) (16/02/2018)
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
20/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;		
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_NotasCompoemICMSEntradaPorCFOP]
--ALTER PROCEDURE [dbo].[usp_RS_NotasCompoemICMSEntradaPorCFOP]
	@empcod smallint,
	@dataDe datetime, 
	@dataAte datetime,
	@tiposNota varchar(100),
	@CFOP varchar(100),
	@NFE int
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @Data_De datetime, @Data_Ate datetime, @TiposNotaFiscal varchar(100), @CFOPS varchar(100), @NumeroNFe int;
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = @dataDe;
	SET @Data_Ate = @dataAte;
	SET @TiposNotaFiscal = @tiposNota;
	SET @CFOPS = @CFOP;
	SET @NumeroNFe = @NFE;

-- Uso da funcao fSplit, para filtros com clausula IN()
	-- Grupos de vendedores
	IF object_id('TempDB.dbo.#TIPOSNOTAS') IS NOT NULL
		DROP TABLE #TIPOSNOTAS;
    SELECT 
		elemento as valor
	INTO #TIPOSNOTAS FROM fSplit(@TiposNotaFiscal, ',');
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TIREI A FINALIDADE DE EMISSÃO = DEVOLUÇÃO (TBS080), PQ PODE TER RECOMPRA COM FINALIDADE = 1 (NORMAL) (16/02/2018)
	-- TABELA TBS080 

	if object_id('tempdb.dbo.#TBS080') is not null
	begin
		drop table #TBS080
	end

	SELECT
		ENFNUM ,
		ENFCODDES
	INTO #TBS080 FROM TBS080 (NOLOCK)
	WHERE 
		ENFSIT = 6 AND 		
		ENFTIPDOC = 0 AND 
		ENFDATEMI BETWEEN @data_De AND @data_Ate 
 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	if object_id('tempdb.dbo.#CFOP1') is not null
	begin
		drop table #CFOP1  
	end
 
	DECLARE @sql varchar (500)
 
	IF @CFOPS <> ''
	BEGIN 
	set @sql = 'SELECT DISTINCT NFECFOP COLLATE DATABASE_DEFAULT AS NFECFOP FROM TBS0591 (NOLOCK) WHERE NFECFOP IN ('''+replace(rtrim(@CFOPS),',',''',''')+''')
				UNION 
				SELECT DISTINCT CPACFOP COLLATE DATABASE_DEFAULT AS NFECFOP FROM TBS057 (NOLOCK) WHERE CPACFOP IN ('''+replace(rtrim(@CFOPS),',',''',''')+''')
				UNION 
				SELECT TOP 1 ''1.353'' FROM TBS001 NOLOCK WHERE ''1.353'' IN ('''+replace(rtrim(@CFOPS),',',''',''')+''')
				UNION
				SELECT TOP 1 ''2.353'' FROM TBS001 NOLOCK WHERE ''2.353'' IN ('''+replace(rtrim(@CFOPS),',',''',''')+''') '
	END

	IF @CFOPS = ''
	BEGIN 
	set @sql = 'SELECT DISTINCT NFECFOP COLLATE DATABASE_DEFAULT AS NFECFOP FROM TBS0591 (NOLOCK)
				UNION 
				SELECT DISTINCT CPACFOP COLLATE DATABASE_DEFAULT AS NFECFOP FROM TBS057 (NOLOCK) WHERE CPACFOP <> ''''
				UNION 
				SELECT TOP 1 ''1.353'' FROM TBS001 
				UNION
				SELECT TOP 1 ''2.353'' FROM TBS001 		
				'
	END

	CREATE TABLE #CFOP1 (NFECFOP CHAR (5))
	INSERT INTO #CFOP1
	EXEC(@sql)

	-- SELECT * FROM #CFOP1
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TODOS OS CFOPS TEM QUE APARECER NO RELATORIO 

	if object_id('tempdb.dbo.#CFOP') is not null
	begin
		drop table #CFOP
	end
   
	create table #CFOP (TIPO CHAR (1), CFOP CHAR(5) , PAGAR CHAR(1))

	-- ENTRADAS '1.922','2.922', VALOR ANTECIPADO '1.403','2.403' -- PAGAR '1.252','1.352','2.352'
	INSERT INTO #CFOP VALUES ('E','1.403','N') -- ESSE VALOR TENHO QUE ZERAR NO RELATORIO
	INSERT INTO #CFOP VALUES ('E','2.403','N') -- ESSE VALOR TENHO QUE ZERAR NO RELATORIO
	INSERT INTO #CFOP VALUES ('E','1.922','N')
	INSERT INTO #CFOP VALUES ('E','2.922','N')

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	--UNION

	if object_id('tempdb.dbo.#NFE') is not null
	BEGIN
		drop table #NFE
	END

	SELECT
	convert(CHAR(10),B.NFEDATEFE,111) AS DATAS,
	convert(CHAR(10),B.NFEDATEFE,103) AS NFEDATEFE,
	A.NFENUM AS NFE,
	B.NFECHAACE,
	B.NFETIP AS TIPO,
	A.NFECFOP COLLATE DATABASE_DEFAULT AS CFOP,	
	A.NFECST COLLATE DATABASE_DEFAULT AS CST,
	1 AS QTD,
	dbo.NFETOTITEBRU(A.NFEEMPCOD, A.NFETIP, A.NFENUM, A.NFECOD, A.SEREMPCOD, A.SERCOD, A.NFEITE) AS NFETOTITE,
	NFETOTOPEITE,

	CASE WHEN (NFEVALICMSST > 0 AND B.NFETIP NOT IN ('D')) OR SUBSTRING(NFECFOP,3,3) IN ('556','557') OR (A.LESCOD = 6 AND SUBSTRING(NFECFOP,3,3) IN ('910'))
		THEN 0
		ELSE 
			CASE WHEN NFEVCRESN > 0 
				THEN NFETOTOPEITE
				ELSE A.NFEBASICMS
			END
	END AS NFEBASICMS, 

	CASE WHEN (NFEVALICMSST > 0 AND B.NFETIP NOT IN ('D')) OR SUBSTRING(NFECFOP,3,3) IN ('556','557') OR (A.LESCOD = 6 AND SUBSTRING(NFECFOP,3,3) IN ('910'))
		THEN 0
		ELSE 
			CASE WHEN NFEVCRESN > 0 
				THEN NFEVCRESN
				ELSE A.NFEVALICMS
			END
	END AS NFEVALICMS,


	CASE WHEN (NFEVALICMSST > 0 AND B.NFETIP NOT IN ('D')) -- RESPOSTA DE UM E-MAIL 28/02/2018, NA QUAL A CONTABILIADE DISSE QUE NA DEVOLUÇÃO TOMO CREDITO DE ICMS MESMO TENDO ST
		THEN 
			CASE WHEN NFEVCRESN > 0 
				THEN NFETOTOPEITE
				ELSE A.NFEBASICMS
			END
		ELSE 0
	END AS NFEBASICMSANT, 

	CASE WHEN (NFEVALICMSST > 0 AND B.NFETIP NOT IN ('D'))
		THEN 
			CASE WHEN NFEVCRESN > 0 
				THEN NFEVCRESN
				ELSE A.NFEVALICMS
			END
		ELSE 0
	END AS NFEVALICMSANT, 

	NFEBASICMSST ,
	NFEVALICMSST ,
	NFEVALIPI ,

	CASE WHEN SUBSTRING(NFECST,2,3) IN ('30','40','103','203','300') AND A.NFEVCRESN = 0
		THEN NFETOTOPEITE 
		ELSE 0
	END AS ICMSISENTO,		-- ICMS ISENTO

	CASE WHEN SUBSTRING(NFECST,2,3) IN ('41','50','400','102') AND A.NFEVCRESN = 0
		THEN NFETOTOPEITE 
		ELSE 0
	END AS ICMSNAOTRI,		-- ICMS NÃO TRIBUTADO

	CASE WHEN SUBSTRING(NFECST,2,3) IN ('60','500') AND A.NFEVCRESN = 0
		THEN NFETOTOPEITE
		ELSE 0
	END AS ICMSTRIANT,		-- ICMS TRIBUTADO ANTERIORMENTE

	NFEVALDESITE

	 /* CONTABIL - BASE - ISENTO - NÃO TRIBUTADO = ICMSOUTROS */

	INTO #NFE 
	FROM TBS0591 A (NOLOCK)
	INNER JOIN TBS059 B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND 
	A.NFETIP = B.NFETIP AND A.SERCOD = B.SERCOD AND  A.SEREMPCOD = B.SEREMPCOD
	LEFT JOIN #TBS080 D ON A.NFENUM = D.ENFNUM AND A.NFECOD = D.ENFCODDES
		
	WHERE
	B.NFEDATEFE BETWEEN @data_De AND @data_Ate AND 
	(D.ENFNUM IS NOT NULL OR (NFENOSFOR <> 'S' AND B.NFECAN <> 'S' AND NFEDATEFE <> '' )) and 
	A.NFECFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'E' AND PAGAR = 'S')

	--GROUP BY 
	--A.NFECFOP, A.NFECST, SUBSTRING(NFECST,2,3), B.NFETIP



	-- select * from #NFE


	------------------------------------------------------------------------------------------------------------------------------------------

	-- FRETE 

	if object_id('TempDB.dbo.#FRE') is not null
	BEGIN
	   drop table #FRE
	END

	SELECT 
	convert(CHAR(10),CTEENTDATENT,111) AS DATAS,
	convert(CHAR(10),CTEENTDATENT,103) AS NFEDATEFE,
	CTEENTNUM AS NFE,
	A.CTEENTCHA,
	'F' AS TIPO,
	-- B.UFESIG AS UF,
	CASE WHEN SUBSTRING(CTEENTCHA,1,2) = 35
		THEN '1.353'
		ELSE '2.353'
	END AS CFOP,
	'' AS CST,
	1 AS QTD,
	CTEENTFREVAL AS NFETOTITE,
	CTEENTFREPES + CTEENTFREVAL + CTEENTGRIS + CTEENTPED + CTEENTTRT + CTEENTTDE + CTEENTSECCAT + CTEENTDES + CTEENTSEG + CTEENTTAX + CTEENTOUT as NFETOTOPEITE,
	CTEENTBASICM AS NFEBASICMS,
	(CTEENTBASICM * ((100 - CTEENTBASRED) / 100)) * CTEENTPERICM / 100 AS NFEVALICMS,
	0 AS NFEBASICMSANT ,
	0 AS NFEVALICMSANT,
	0 AS NFEBASICMSST,
	0 AS NFEVALICMSST,
	0 AS NFEVALIPI,
	0 AS ICMSISENTO,
	CASE WHEN CTEENTBASICM > 0 
		THEN 0
		ELSE CTEENTFREPES + CTEENTFREVAL + CTEENTGRIS + CTEENTPED + CTEENTTRT + CTEENTTDE + CTEENTSECCAT + CTEENTDES + CTEENTSEG + CTEENTTAX + CTEENTOUT
	END AS ICMSNAOTRI,
	0 AS ICMSTRIANT, 
	0 AS NFEVALDESITE
	/* CONTABIL - BASE - ISENTO - NÃO TRIBUTADO = ICMSOUTROS */

	INTO #FRE
	FROM TBS130 A (NOLOCK)
	LEFT JOIN TBS001 B (NOLOCK) ON SUBSTRING(A.CTEENTCHA,1,2) = B.UFECODIBGE

	WHERE
	CTEENTCHA COLLATE DATABASE_DEFAULT IN(SELECT DISTINCT CTEENTCHA FROM TBS1301 NOLOCK WHERE CTEENTCHADOC COLLATE DATABASE_DEFAULT IN (SELECT DISTINCT NFECHAACE FROM #NFE WHERE NFECHAACE <> ''))

	-- SELECT * FROM #FRE
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL DE SOMATORIO DE ICMS POR CFOP DE ENTRADA 
	-- ENTRADA NFE

	SELECT 
	TIPO,
	DATAS,
	NFEDATEFE,
	CFOP,
	NFE,
	SUM(QTD) AS QTD,
	ROUND(SUM(NFETOTITE),2)		AS NFETOTITE,
	ROUND(SUM(NFETOTOPEITE),2)	AS NFETOTOPEITE,
	ROUND(SUM(NFEBASICMS),2)	AS NFEBASICMS,
	ROUND(SUM(NFEVALICMS),2)	AS NFEVALICMS,
	ROUND(SUM(NFEBASICMSANT),2)	AS NFEBASICMSANT, 
	ROUND(SUM(NFEVALICMSANT),2)	AS NFEVALICMSANT, 
	ROUND(SUM(NFEBASICMSST),2)	AS NFEBASICMSST,
	ROUND(SUM(NFEVALICMSST),2)	AS NFEVALICMSST,
	ROUND(SUM(NFEVALIPI),2)		AS NFEVALIPI,
	ROUND(SUM(ICMSISENTO),2)	AS ICMSISENTO,		-- ICMS ISENTO
	ROUND(SUM(ICMSNAOTRI),2)	AS ICMSNAOTRI,		-- ICMS NÃO TRIBUTADO
	ROUND(SUM(ICMSTRIANT),2)	AS ICMSTRIANT,		-- ICMS TRIBUTADO ANTERIORMENTE
	ROUND(SUM(NFETOTOPEITE - NFEBASICMS - ICMSNAOTRI - ICMSISENTO),2) AS ICMSOUTROS,
	ROUND(SUM(NFEVALDESITE),2)	AS NFEVALDESITE

	FROM #NFE 

	WHERE 
	TIPO IN (SELECT valor FROM #TIPOSNOTAS) AND 
	CFOP COLLATE DATABASE_DEFAULT IN (SELECT NFECFOP FROM #CFOP1) AND
	NFE = CASE WHEN @NumeroNFe = 0 THEN NFE ELSE @NumeroNFe END

	GROUP BY 
	TIPO,
	DATAS,
	NFEDATEFE,
	CFOP,
	NFE

	UNION 

	-- FRETE

	SELECT 
	TIPO,
	DATAS,
	NFEDATEFE,
	CFOP,
	NFE,
	SUM(QTD) AS QTD,
	ROUND(SUM(NFETOTITE),2)		AS NFETOTITE,
	ROUND(SUM(NFETOTOPEITE),2)	AS NFETOTOPEITE,
	ROUND(SUM(NFEBASICMS),2)	AS NFEBASICMS,
	ROUND(SUM(NFEVALICMS),2)	AS NFEVALICMS,
	ROUND(SUM(NFEBASICMSANT),2)	AS NFEBASICMSANT, 
	ROUND(SUM(NFEVALICMSANT),2)	AS NFEVALICMSANT, 
	ROUND(SUM(NFEBASICMSST),2)	AS NFEBASICMSST,
	ROUND(SUM(NFEVALICMSST),2)	AS NFEVALICMSST,
	ROUND(SUM(NFEVALIPI),2)		AS NFEVALIPI,
	ROUND(SUM(ICMSISENTO),2)	AS ICMSISENTO,		-- ICMS ISENTO
	ROUND(SUM(ICMSNAOTRI),2)	AS ICMSNAOTRI,		-- ICMS NÃO TRIBUTADO
	ROUND(SUM(ICMSTRIANT),2)	AS ICMSTRIANT,		-- ICMS TRIBUTADO ANTERIORMENTE
	ROUND(SUM(NFETOTOPEITE - NFEBASICMS - ICMSNAOTRI - ICMSISENTO),2) AS ICMSOUTROS,
	ROUND(SUM(NFEVALDESITE),2)	AS NFEVALDESITE

	FROM #FRE 

	WHERE 
	TIPO IN (SELECT valor FROM #TIPOSNOTAS) AND 
	CFOP COLLATE DATABASE_DEFAULT IN (SELECT NFECFOP FROM #CFOP1) AND
	NFE = CASE WHEN @NumeroNFe = 0 THEN NFE ELSE @NumeroNFe END

	GROUP BY 
	TIPO,
	DATAS,
	NFEDATEFE,
	CFOP,
	NFE
END