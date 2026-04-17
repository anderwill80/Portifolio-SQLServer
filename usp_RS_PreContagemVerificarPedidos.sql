/*
====================================================================================================================================================================================
WREL045 -  Pré contagem - verificar pedidos
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
16/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parametros de entrada da SP;	
	- Uso da SP "usp_GetCodigosProdutos" para obter os codigos dos produtos;
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_PreContagemVerificarPedidos]
--ALTER PROCEDURE [dbo].[usp_RS_PreContagemVerificarPedidos]
	@empcod smallint,
	@marca int,
	@marcanom varchar(60),
	@localizacao varchar(50),
	@CONF varchar(50)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	DECLARE @codigoEmpresa smallint, 
			@MARCOD int, @MARNOM varchar(60), @Conferidos varchar(50), @PROLOCFIS varchar(50);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @MARCOD = @marca;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@MARCANOM)));
	SET @PROLOCFIS = LTRIM(RTRIM(UPPER(@localizacao)))
	SET @Conferidos = @CONF;

-- Uso da funcao split, para as clausulas IN()
	-- Tipos de notas
	IF object_id('TempDB.dbo.#CONFERIDOS') IS NOT NULL
		DROP TABLE #CONFERIDOS;
	SELECT 
		elemento as valor
	INTO #CONFERIDOS FROM fSplit(@Conferidos, ',');
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos dos produtos

	IF OBJECT_ID ('TempDB.dbo.#TBS010') IS NOT NULL 
		DROP TABLE #TBS010;

	SELECT 
		RTRIM(LTRIM(PROLOCFIS)) AS PROLOCFIS, 
		PROCOD,
		MARCOD
	INTO #TBS010 FROM TBS010 A (NOLOCK)
	WHERE 
		MARCOD = (CASE WHEN @MARCOD = 0 THEN MARCOD ELSE @MARCOD END ) AND 
		MARNOM LIKE(CASE WHEN @MARNOM = '' THEN MARNOM ELSE @MARNOM END) AND
		LTRIM(RTRIM(PROLOCFIS)) LIKE(CASE WHEN @PROLOCFIS = '' THEN PROLOCFIS ELSE @PROLOCFIS END)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os pedidos de vendas reservados que movimentam estoque

	IF OBJECT_ID ('tempdb.dbo.#TBS') IS NOT NULL	
		DROP TABLE #TBS;	

	SELECT 
		'PEDIDOS' AS OP,
		PRPNUM, 
		PRPITEM,
		PROCOD,
		PRPPRODES,
		PRPUNI,
		PRPQTDEMB,
		PRPQTDCONF,
		PRPQTD - PRPQTDCONF AS PRPQTDEST,
		CASE WHEN PRPQTDCONF > 0 
			THEN 
				CASE WHEN PRPQTD = PRPQTDCONF 
					THEN 'TOTAL'
					ELSE 'PARCIAL'
				END
			ELSE 'NÃO'
		END CONFERIDO,
		ISNULL(RTRIM(LTRIM(STR(PRPVENCOD)))+'-'+ (SELECT RTRIM(LTRIM(VENNOM)) FROM TBS004 C (NOLOCK) WHERE B.PRPVENCOD = C.VENCOD),str(ltrim(rtrim(B.PRPCLICOD)))) AS VENNOM
	INTO #TBS FROM TBS058 B (NOLOCK) 
	WHERE 
		B.PROCOD IN (SELECT PROCOD FROM #TBS010) AND 
		B.PRPSIT= 'R' AND 
		B.PRPMOVEST = 'S'

	UNION 
		SELECT 
		'MOV. INTERNOS' AS OP,
		A.MVIDOC,
		B.MVIITE,
		B.PROCOD,
		B.MVIPRODES,
		B.MVIPROUNI,
		B.MVIQTDEMB,
		B.MVIQTDATD,
		B.MVIQTDPED,
		'NÃO',
		RTRIM(LTRIM(STR(A.CCSCOD))) + ' - ' + ISNULL((SELECT CCSNOM FROM TBS036 C (NOLOCK) WHERE C.CCSCOD = A.CCSCOD),'') AS USUCUS
	FROM TBS037 A (NOLOCK)
		LEFT JOIN TBS0371 B (NOLOCK) ON A.MVIDOC = B.MVIDOC AND A.MVIEMPCOD = B.MVIEMPCOD 
	WHERE 
		TMVCOD= 501 AND 
		MVILOCORI = 1 AND 
		MVIDATEFE = '17530101' AND 
		B.PROCOD IS NOT NULL AND 
		B.PROCOD IN (SELECT PROCOD FROM #TBS010)

	UNION 
	SELECT 
		'SOL. COMPRAS' AS OP,
		A.SDCNUM,
		B.SDCITE,
		B.PROCOD,
		B.SDCPRODES,
		B.SDCUNI,
		B.SDCQTDEMB,
		0,
		SDCQTDATD - SDCQTDBAI,
		'NÃO',
		RTRIM(LTRIM(STR(A.CCSCOD))) + ' - ' + ISNULL((SELECT CCSNOM FROM TBS036 C (NOLOCK) WHERE C.CCSCOD = A.CCSCOD),'') AS USUCUS
	FROM TBS0761 B (NOLOCK) 
		INNER JOIN TBS076 A (NOLOCK) ON A.SDCEMPCOD = B.SDCEMPCOD AND A.SDCNUM = B.SDCNUM					    
	WHERE 
		SDCQTDRES = 0 AND -- SE ESTIVER COM RESIDUO, SIGNIFICA QUE NÃO ESTÁ RESERVADO
		SDCQTDATD - SDCQTDBAI > 0 AND -- QUANTIDADE ATENDIDA - QUANTIDADE BAIXADA > 0 , SIGNIFICA QUE TEM ALGO RESERVADO
		B.PROCOD IS NOT NULL AND 
		B.PROCOD IN (SELECT PROCOD FROM #TBS010)
	
	-- ORDER BY SDCDATCAD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL 

	SELECT 
		A.*, 
		B.PROLOCFIS
	FROM #TBS A 
		LEFT JOIN #TBS010 B ON A.PROCOD = B.PROCOD 
	WHERE 
		CONFERIDO IN (SELECT valor from #CONFERIDOS)
END