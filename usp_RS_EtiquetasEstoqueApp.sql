/*
====================================================================================================================================================================================
WREL146 - Etiquetas Estoque (App)
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
03/02/2025 WILLIAM
	- Aplicar refinamento no codigo;
27/06/2024 WILLIAM
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela",  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_EtiquetasEstoqueApp]
--create proc [dbo].[usp_RS_EtiquetasEstoqueApp]
	@empcod smallint,
	@registro int = 0	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@codigoEmpresa smallint, @empresaTBS010 smallint, @empresaTMP022 smallint, 
			@T22_REGISTRO int,
			@Query nvarchar (MAX), @ParmDef nvarchar (500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @T22_REGISTRO = @registro

-- Verificar se a tabela é compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TMP022', @empresaTMP022 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras, se vazio filtra todos os código da TBS010

	IF OBJECT_ID('tempdb.dbo.#T') IS NOT NULL
		DROP TABLE #T;

	CREATE TABLE #T (PROCOD CHAR(15))

	Set @Query = N'
	INSERT #T

	SELECT 
		DISTINCT T22_PROCOD
	FROM TMP022 (NOLOCK) 
	
	WHERE
		T22_EMPRESA = @empresaTMP022 AND
		T22_REGISTRO = @T22_REGISTRO AND
		T22_APLICATIVO = 1
	'
	--SELECT @Query		

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 smallint, @empresaTMP022 smallint, @T22_REGISTRO int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS010, @empresaTMP022, @T22_REGISTRO
	
	--SELECT * FROM #T
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE FILTROS NA TBS010

	IF OBJECT_ID('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;

	-- Cria a estrutura da tabela temporária
	SELECT TOP 0
		A.PROSTATUS AS STS, 
		RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
		RTRIM(LTRIM(A.PRODES))  AS DESCRIÇÃO, 
		RTRIM(LTRIM(MARNOM)) AS MARCA, 
		RTRIM(LTRIM(PROLOCFIS)) AS LOC, 
		RTRIM(LTRIM(PROLOCFIS2)) AS LOC2,
		'*'+RTRIM(A.PROCOD)+'*'  AS CODBAR1,
		CASE WHEN PROUM2QTD > 0 
			THEN '*'+RTRIM(LTRIM(A.PROCOD))+'-2*' 
			ELSE '' 
		END AS CODBAR2,
		CASE WHEN PROUM1QTD = 1 
			THEN RTRIM(PROUM1) 
			ELSE
				CASE WHEN PROUM1QTD > 1 
					THEN rtrim(PROUM1) + ' C/ ' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +' '+ RTRIM(PROUMV) 
					ELSE '' 
				END 
		END AS UN1
	INTO #TBS010 FROM TBS010 A (NOLOCK)

	Set @Query = N'
		INSERT INTO #TBS010

		SELECT  
			A.PROSTATUS AS STS, 
			RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
			RTRIM(LTRIM(A.PRODES))  AS DESCRIÇÃO, 
			RTRIM(LTRIM(MARNOM)) AS MARCA, 
			RTRIM(LTRIM(PROLOCFIS)) AS LOC, 
			RTRIM(LTRIM(PROLOCFIS2)) AS LOC2,
			''*'' + RTRIM(A.PROCOD) + ''*''  AS CODBAR1,
			CASE WHEN PROUM2QTD > 0 
				THEN ''*'' + RTRIM(LTRIM(A.PROCOD)) + ''-2*''
				ELSE ''''
			END AS CODBAR2,
			CASE WHEN PROUM1QTD = 1 
				THEN RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD))
				ELSE
					CASE WHEN PROUM1QTD > 1 
						THEN rtrim(PROUM1) + '' C/'' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) + ''  '' + RTRIM(PROUMV) 
						ELSE ''''
					END 
			END AS UN1
		FROM TBS010 A (NOLOCK)

		WHERE
			PROEMPCOD = @empresaTBS010 AND
			PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T)
		'

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS010

--	select * from #TBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final ETIQUETAS, usando "CTE" With...AS

	;WITH Etiquetas
	AS
	(
		SELECT
		rank() OVER (ORDER BY LOC, CÓDIGO) AS [RANK],
		*
		
		FROM #TBS010
	)

	SELECT * FROM Etiquetas
	ORDER BY RANK 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END