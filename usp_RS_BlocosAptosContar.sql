/*
====================================================================================================================================================================================
WREL004 - /Release/TanbyMatriz/Relatorios/Blocos aptos a contar
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
21/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_BlocosAptosContar]
--ALTER PROCEDURE [dbo].[usp_RS_BlocosAptosContar]
	@empcod smallint,
	@apto char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @QuemApto char(1);
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @QuemApto = @apto;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Produtos reservados	

	IF object_id('tempdb.dbo.#TBS') IS NOT NULL	
		DROP TABLE #TBS;	

	SELECT
		PROCOD,
		(SELECT RTRIM(LTRIM(SUBSTRING(PROLOCFIS,1,3))) FROM TBS010 A (NOLOCK) WHERE A.PROCOD = B.PROCOD) AS PROLOC
	INTO #TBS FROM TBS058 B (NOLOCK) 
	WHERE 
		B.PRPSIT = 'R' AND 
		B.PRPMOVEST = 'S'	

	-- Movimentos internos
	UNION 
	SELECT 
		B.PROCOD,
		(SELECT RTRIM(LTRIM(SUBSTRING(PROLOCFIS,1,3))) FROM TBS010 A (NOLOCK) WHERE A.PROCOD = B.PROCOD) AS PROLOC
	FROM TBS037 A (NOLOCK)
		LEFT JOIN TBS0371 B (NOLOCK) ON A.MVIDOC = B.MVIDOC AND A.MVIEMPCOD = B.MVIEMPCOD 
	WHERE 
		TMVCOD= 501 AND 
		MVILOCORI = 1 AND 
		MVIDATEFE = '17530101' AND 
		B.PROCOD IS NOT NULL	

	-- Solicitacoes de compras
	UNION 
	SELECT 
		B.PROCOD,
		(SELECT RTRIM(LTRIM(SUBSTRING(PROLOCFIS,1,3))) FROM TBS010 A (NOLOCK) WHERE A.PROCOD = B.PROCOD) AS PROLOC
	FROM TBS0761 B (NOLOCK) 
		INNER JOIN TBS076 A (NOLOCK) ON A.SDCEMPCOD = B.SDCEMPCOD AND A.SDCNUM = B.SDCNUM					    
	WHERE 
		SDCQTDRES = 0 AND -- SE ESTIVER COM RESIDUO, SIGNIFICA QUE NÃO ESTÁ RESERVADO
		SDCQTDATD - SDCQTDBAI > 0 AND -- QUANTIDADE ATENDIDA - QUANTIDADE BAIXADA > 0 , SIGNIFICA QUE TEM ALGO RESERVADO
		B.PROCOD IS NOT NULL 
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	-- Se blobo ou rua apto para contagem

	IF @QuemApto = 'B' 
	BEGIN 
		SELECT 
			DISTINCT SUBSTRING(PROLOCFIS, 1, 3) as ID 
		FROM TBS010 (NOLOCK)
		WHERE 
			SUBSTRING(PROLOCFIS, 1, 3) NOT IN (select DISTINCT PROLOC FROM #TBS WHERE PROLOC <> '') AND 
			PROLOCFIS <> ''
		ORDER BY 
			SUBSTRING(PROLOCFIS, 1, 3)
	END
	ELSE 
	BEGIN
		SELECT 
			DISTINCT SUBSTRING(PROLOCFIS, 1, 2) as ID 
		FROM TBS010 (NOLOCK)
		WHERE 
			SUBSTRING(PROLOCFIS, 1, 2) NOT IN ( select DISTINCT SUBSTRING(PROLOC, 1, 2) FROM #TBS WHERE PROLOC <> '') AND
			PROLOCFIS <> ''
		ORDER BY 
			SUBSTRING(PROLOCFIS, 1, 2)
	END
END