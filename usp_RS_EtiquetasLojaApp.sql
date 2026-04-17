/*
====================================================================================================================================================================================
WREL145 - Etiquetas Loja (App)
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
28/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
20/06/2024	ANDERSON WILLIAM			
	- Conversão para Stored procedure;
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros;
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD;
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_EtiquetasLojaApp]
--CREATE PROC [dbo].[usp_RS_EtiquetasLojaApp]
	@empcod smallint,
	@registro int
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@codigoEmpresa smallint, @empresaTMP022 smallint, @empresaTBS010 smallint, @empresaTBS031 smallint,	@T22_REGISTRO int

	SET @codigoEmpresa = @empcod
	SET @T22_REGISTRO = @registro

-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TMP022', @empresaTMP022 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS031', @empresaTBS031 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtém somente os produtos que foram coletados na TMP022

	IF OBJECT_ID('tempdb.dbo.#T') IS NOT NULL
		DROP TABLE #T;

	CREATE TABLE #T (PROCOD CHAR(15))

	INSERT #T

	SELECT 
		DISTINCT T22_PROCOD
	FROM TMP022 (NOLOCK) 
	
	WHERE
		T22_EMPRESA = @empresaTMP022 AND
		T22_REGISTRO = @T22_REGISTRO AND
		T22_APLICATIVO = 2

	--SELECT * FROM #T
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE PREÇOS

	IF OBJECT_ID('tempdb.dbo.#TBS031') IS NOT NULL
		DROP TABLE #TBS031;

	SELECT 
		TDPPROCOD,
		convert(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S' 
			THEN ROUND(TDPPREPRO1,2) 
			ELSE ROUND(TDPPRELOJ1,2) 
		END) AS PRECO1,

		CONVERT(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S'
			THEN ROUND(TDPPREPRO2,2) -- *round(PROUM2QTD,2)
			ELSE ROUND(TDPPRELOJ2,2) -- *round(PROUM2QTD,2) 
		END) AS PRECO2 ,

		CONVERT(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S'
			THEN ROUND(TDPPREPRO3,2) -- *round(PROUM3QTD,2)
			ELSE ROUND(TDPPRELOJ3,2) -- *round(PROUM3QTD,2) 
		END) AS PRECO3 -- ,
	INTO #TBS031 FROM TBS031 (NOLOCK)

	WHERE 
		TDPEMPCOD = @empresaTBS031 AND
		TDPPROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T)

	--SELECT * FROM #TBS031
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela TBS010 para filtros

	IF OBJECT_ID ('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;

	SELECT  
		A.PROSTATUS , 
		RTRIM(LTRIM(A.PROCOD)) AS PROCOD, 
		RTRIM(LTRIM(A.PRODES)) AS PRODES, 
		RTRIM(LTRIM(A.MARNOM)) AS MARNOM, 
		PROUM1,
		PROUM2,
		PROUM3,
		PROUMV,
		PROUM1QTD,
		PROUM2QTD,
		PROUM3QTD,
		RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD)) as UNIDES, 
		A.PROSETLOJ1, 
		A.PROSETLOJ2,
		A.GRUCOD, 
		isnull((select top 1 rtrim(ltrim(GRUDES)) from TBS012 B (nolock) where A.GRUCOD = B.GRUCOD order by B.GRUEMPCOD, B.GRUCOD),'') as GRUDES
	INTO #TBS010 FROM TBS010 A (NOLOCK)

	WHERE 
		PROEMPCOD = @empresaTBS010 AND
		A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T)

	--select * from #TBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela auxiliar antes da final

	IF OBJECT_ID ('tempdb.dbo.#TBS') IS NOT NULL
		DROP TABLE #TBS;

	SELECT  
		rank() OVER (ORDER BY A.PROCOD) AS [RANKS],
		A.PROSTATUS AS STS, 
		RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
		RTRIM(LTRIM(A.PRODES)) AS DESCRIÇÃO, 
		RTRIM(LTRIM(A.MARNOM)) AS MARCA, 

		'*'+RTRIM(A.PROCOD)+'*'  AS CODBAR1,
		CASE WHEN PROUM2QTD > 0 
			THEN '*'+RTRIM(LTRIM(A.PROCOD))+'-2*' 
			ELSE '' 
		END AS CODBAR2,
		
		PRECO1,
		round(PRECO2 * round(PROUM2QTD,2),2) AS PRECO2,
		round(PRECO3 * round(PROUM3QTD,2),2) AS PRECO3,

		CASE WHEN PROUM1QTD = 1
			THEN RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD))   
			ELSE
				CASE WHEN PROUM1QTD > 1 
				THEN rtrim(PROUM1) + ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) 
				ELSE '' 
			END 
		END  as UN1,
		'R$' sifra,

		CASE WHEN PROUM2QTD > 0 and PRECO2 > 0
			THEN rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) 
			ELSE '' 
		END  as UN2,

		CASE WHEN PROUM3QTD > 0 and PRECO3 > 0
			THEN rtrim(PROUM3) + ' C/' + rtrim(CAST(PROUM3QTD / PROUM2QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1)
			ELSE '' 
		END  as UN3,

		A.GRUCOD, 
		A.GRUDES
	INTO #TBS FROM #TBS010 A (NOLOCK)
		INNER JOIN #TBS031 B (NOLOCK) ON A.PROCOD = B.TDPPROCOD					
	ORDER BY 
		[RANKS]

	--SELECT * FROM #tbs
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	IF OBJECT_ID('tempdb.dbo.#ETIQUETAS') IS NOT NULL
		DROP TABLE #ETIQUETAS;

	CREATE TABLE #ETIQUETAS (
		RANKS INT IDENTITY(1,1) PRIMARY KEY, 
		STS CHAR (1), 
		CÓDIGO CHAR (15), 
		DESCRIÇÃO CHAR(60), 
		MARCA CHAR(60), 
		CODBAR1 CHAR(17), 
		CODBAR2 CHAR(19),
		PRECO1 DECIMAL(10,2) , 
		PRECO2 DECIMAL(10,2), 
		PRECO3 DECIMAL(10,2), 
		UN1 CHAR (15), 
		sifra CHAR (2), 
		UN2 CHAR (15), 
		UN3 VARCHAR (25), 
		codigoGrupo int, 
		descricaoGrupo char(20)
	)

	INSERT #ETIQUETAS	
	SELECT 
		STS, 
		CÓDIGO, 
		DESCRIÇÃO, 
		MARCA, 
		CODBAR1,
		CODBAR2,		
		PRECO1,
		PRECO2,
		PRECO3,
		UN1,
		sifra,
		UN2,
		UN3,
		GRUCOD, 
		GRUDES
	FROM #TBS A (NOLOCK)
		INNER JOIN TMP022 B (NOLOCK) ON A.CÓDIGO = B.T22_PROCOD

	WHERE 
		B.T22_REGISTRO = @T22_REGISTRO AND
		B.T22_APLICATIVO = 2

	ORDER BY 
		CÓDIGO

	SELECT 
		ROW_NUMBER ( ) OVER (ORDER BY CÓDIGO) AS [RANK],
		* 
	FROM #ETIQUETAS
End