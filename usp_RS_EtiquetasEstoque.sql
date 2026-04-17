/*
====================================================================================================================================================================================
WREL105 - Etiquetas Estoque
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
29/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Utilizacao da SP "usp_GetCodigoProdutos";
	- Melhoria nos filtros para obter os codigos dos produtos;
27/06/2024 WILLIAM
	- Filtro por MARCA, já na TBS032, assim quando for na TBS010 já está refinado a consulta;
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_EtiquetasEstoque]
--CREATE PROC [dbo].[usp_RS_EtiquetasEstoque]
	@empcod smallint,
	@COD  varchar(8000) = '',
	@Loces varchar(20) = '',
	@Locger varchar(20) = '',
	@MARCOD int = 0,
	@saldo char(1) = 'N',
	@OPCAO smallint = 0
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@codigoEmpresa smallint, @empresaTBS010 int,			
			@PROCOD varchar(8000), @PROLOCFIS VARCHAR(20), @CodMarca int, @Locgeral varchar(20), @SomenteComSaldo char(1), @OpcaoLoc smallint,
			@Query nvarchar (MAX), @ParmDef nvarchar (500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @PROCOD = @COD;
	SET @PROLOCFIS = @Loces;
	SET @CodMarca = @MARCOD;
	SET @Locgeral = IIF(RTRIM(@Locger) = '', '', UPPER(RTRIM(@Locger)) + '%')
	SET @SomenteComSaldo = @saldo
	SET @OpcaoLoc = @OPCAO

-- Uso da funcao split, para as clausulas IN()
	If object_id('TempDB.dbo.#LOCALIZACOES') is not null
		DROP TABLE #LOCALIZACOES;
	SELECT 
		elemento AS valor
	INTO #LOCALIZACOES FROM fSplit(@PROLOCFIS, ',')
	IF @PROLOCFIS = ''
		DELETE #LOCALIZACOES;

	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras e codigo da marca, se vazio filtra todos os código da TBS010, via SP

	If OBJECT_ID ('tempdb.dbo.#CODIGOSPRO') IS NOT NULL
		DROP TABLE #CODIGOSPRO;

	CREATE TABLE #CODIGOSPRO (PROCOD VARCHAR(15))

	INSERT INTO #CODIGOSPRO
	EXEC usp_GetCodigosProdutos @codigoEmpresa, @PROCOD, '', @CodMarca, ''

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos produtos, realizando filtros por localizao nos codigos de produtos obtidos via SP

	IF OBJECT_ID('tempdb.dbo.#T') IS NOT NULL
		DROP TABLE #T;

	CREATE TABLE #T (PROCOD VARCHAR(15))
			
	SET @Query = N'
		INSERT INTO #T

		SELECT 
			PROCOD
		FROM TBS010 (NOLOCK) 
		WHERE
			PROEMPCOD = @empresaTBS010 AND
			PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #CODIGOSPRO)
		'
		+
		IIF(@PROLOCFIS = '', '', ' AND PROLOCFIS IN (SELECT valor FROM #LOCALIZACOES)')
		+
		IIf(@Locgeral = '', '', ' AND PROLOCFIS LIKE @Locgeral')
		+
		IIf(@OpcaoLoc = 0, '', IIF(@OpcaoLoc = 1, ' AND PROLOCFIS <> ''''', ' AND PROLOCFIS = '''''))
			
	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 smallint, @Locgeral varchar(20)'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS010, @Locgeral
	
	-- SELECT * FROM #T
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- FILTRO SE TEM SALDO OU NÃO 

	IF OBJECT_ID('TempDB.dbo.#TBS032') IS NOT NULL
		DROP TABLE #TBS032;

	-- Cria a estrutura da tabela temporária
	SELECT TOP 0
		PROCOD,
		ESTQTDATU
	INTO #TBS032 FROM TBS032 (NOLOCK)
	----------------------------------------
	Set @Query = N'
		INSERT INTO #TBS032
	
		SELECT
			PROCOD,
			ESTQTDATU
		FROM TBS032 (NOLOCK)

		WHERE 
			PROEMPCOD = @empresaTBS010 AND
			PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T) AND
			ESTLOC = 1
		'
		+
		IIF(@SomenteComSaldo = 'N', '', ' AND (ESTQTDATU - ESTQTDRES) > 0')
	
	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS010

--	SELECT * FROM #TBS032
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE FILTROS NA TBS010

	If OBJECT_ID('TempDB.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;	

		SELECT  
			A.PROSTATUS AS STS, 
			RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
			RTRIM(LTRIM(A.PRODES))  AS DESCRIÇÃO, 
			RTRIM(LTRIM(MARNOM)) AS MARCA, 
			RTRIM(LTRIM(PROLOCFIS)) AS LOC, 
			RTRIM(LTRIM(PROLOCFIS2)) AS LOC2,
			'*' + RTRIM(A.PROCOD) + '*'  AS CODBAR1,
			CASE WHEN PROUM2QTD > 0 
				THEN '*' + RTRIM(LTRIM(A.PROCOD)) + '-2*'
				ELSE ''
			END AS CODBAR2,
			CASE WHEN PROUM1QTD = 1 
				THEN RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD))
				ELSE
					CASE WHEN PROUM1QTD > 1 
						THEN RTRIM(PROUM1) + ' C/' + RTRIM(CAST(PROUM1QTD AS DECIMAL(10,0))) + '  ' + RTRIM(PROUMV) 
						ELSE ''
					END 
			END AS UN1

		INTO #TBS010 FROM TBS010 A (NOLOCK)

		WHERE
		PROEMPCOD = @empresaTBS010 AND
		PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS032) -- Obtem os produtos da tabela de saldo, já filtrados com ou sem saldo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final ETIQUETAS, usando "CTE" With...AS

	;WITH ETIQUETAS
	AS
	(
		SELECT
			RANK() OVER (ORDER BY LOC, CÓDIGO) AS [RANK],
			*		
		FROM #TBS010
	)

	SELECT 
		* 
	FROM ETIQUETAS
	ORDER BY 
		RANK 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End