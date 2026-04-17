/*
====================================================================================================================================================================================
WREL061 - Saldo nos Estoques
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
17/04/2026 WILLIAM
	- Incluscao da clausula "COLLATE DATABASE_DEFAULT" no momente de criar as tabelas [#CODIGOSPRO] e, melhora a performance sem estar no "Where";
	- Troca da clausula "IN" pela "EXISTS", no filtro da tabela #TBS010, melhora a performance ja que a "EXISTS" para de pesquisar na subconsulta assim que encontra
	o primeiro registro correspondente;
03/02/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Desativando a detecao de parametros(Parameter Sniffing);
	- Uso da SP "usp_Get_CodigosProdutos";
	- Retirada dos setores loja dos filtros, ja que nao e usado em nenhuma empresa do grupo;
09/02/2024 WILLIAM
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
====================================================================================================================================================================================
*/

ALTER PROC [dbo].[usp_RS_SaldosnosEstoques]
--CREATE PROC [dbo].[usp_RS_SaldosnosEstoques2]
	@empcod int,
	@PROCOD varchar(8000),
	@PRODES varchar(60) = '',
	@MARCOD int = 0,
	@MARNOM varchar(30) = '',
	@PROCURABC varchar(1),
	@LOC varchar(1),
	@SALDO varchar(1),
	@PROLOCFIS varchar(20),
	@PROSTATUS varchar(20),
	@ESTLOC varchar(80)	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @Marca int, @MarcaNome varchar(60), @CurvaProduto varchar(1),
			@Produtos varchar(8000), @DescricaoProduto varchar(60), @STATUS varchar(20), @Localizacao varchar(20), 	@Locais varchar(80), @TipoSaldo varchar(1), @TipoLoc varchar(1),
			@cmdSQL nvarchar (MAX), @ParmDef nvarchar (500);
						
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Produtos = @PROCOD;
	SET @DescricaoProduto = @PRODES;
	SET @Marca = @MARCOD;
	SET @MarcaNome = @MARNOM;
	SET @CurvaProduto = @PROCURABC;
	SET @STATUS = @PROSTATUS;
	SET @Localizacao = RTRIM(LTRIM(UPPER(@PROLOCFIS)));
	SET @Locais = @ESTLOC;
	SET @TipoSaldo = @SALDO;
	SET @TipoLoc = @LOC;

-- Uso da funcao fSplit(), para as clausulas IN()
	-- Status dos produtos
	IF OBJECT_ID('tempdb.dbo.#STATUSPRO') IS NOT NULL
		DROP TABLE #STATUSPRO;
	SELECT
		elemento as valor
	INTO #STATUSPRO FROM fSplit(@STATUS, ',');
	-- Locais de estoque
	IF OBJECT_ID('tempdb.dbo.#LOCAISEST') IS NOT NULL
		DROP TABLE #LOCAISEST;
	SELECT
		elemento as valor
	INTO #LOCAISEST FROM fSplit(@Locais, ',');

-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras, se vazio filtra todos os código da TBS010

	If OBJECT_ID ('tempdb.dbo.#CODIGOSPRO') IS NOT NULL
		DROP TABLE #CODIGOSPRO;

	CREATE TABLE #CODIGOSPRO(
		PROCOD VARCHAR(15) COLLATE DATABASE_DEFAULT
	)
	INSERT INTO #CODIGOSPRO
	EXEC usp_Get_CodigosProdutos @codigoEmpresa, @Produtos, @DescricaoProduto, @Marca, @MarcaNome

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos produtos, usando Query dinamica

	IF OBJECT_ID('tempdb.dbo.#TBS010') IS NOT NULL 
		DROP TABLE #TBS010;

	-- Cria apenas a estrutura para o comando INSERT INTO com o "SELECT TOP 0"
	SELECT TOP 0
		PROSTATUS,
		MARCOD,
		RTRIM(LTRIM(PROLOCFIS)) AS PROLOCFIS,
		RTRIM(LTRIM(PROCOD)) COLLATE DATABASE_DEFAULT AS PROCOD,
		RTRIM(LTRIM(PRODES)) AS PRODES,
		case when len(A.MARCOD) = 4 
			then rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) 
			else right(('00' + ltrim(str(A.MARCOD))),3) + ' - ' + rtrim(A.MARNOM) 
		end as MARNOM,
		CASE WHEN PROUM1QTD > 1 
			THEN RTRIM(LTRIM(PROUM1)) + ' ' + RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '' + 
				CASE WHEN PROUMV = '' 
					THEN PROUM1 
					ELSE PROUMV 
				End 
			ELSE RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '' + 
				CASE WHEN PROUMV = '' 
					THEN PROUM1 
					ELSE PROUMV 
				End 
		End AS PROUM1,
		CASE WHEN PROLOCFIS = ''
			THEN 1 
			ELSE 0
		End AS SEMPROLOCFIS,
		CASE WHEN PROLOCFIS <> '' 
			THEN 1
			ELSE 0
		End AS COMPROLOCFIS, 

		RTRIM(LTRIM(PROSETLOJ1)) AS PROSETLOJ1,
		RTRIM(LTRIM(PROSETLOJ2)) AS PROSETLOJ2,

		CASE WHEN PROSETLOJ1 = '' AND PROSETLOJ2 = ''
			THEN 1
			ELSE 0
		End AS SEMSETLOJ,
		CASE WHEN PROSETLOJ1 <> '' OR PROSETLOJ2 <> ''
			THEN 1
			ELSE 0
		End AS COMSETLOJ,
		isnull(PROCURABC,'') as 'PROCURABC'
	INTO #TBS010 FROM TBS010 A (NOLOCK)

	Set @cmdSQL = N'
		INSERT INTO #TBS010

		SELECT
			PROSTATUS,
			MARCOD,
			RTRIM(LTRIM(PROLOCFIS)) AS PROLOCFIS,
			RTRIM(LTRIM(PROCOD)) AS PROCOD,
			RTRIM(LTRIM(PRODES)) AS PRODES,
			case when len(A.MARCOD) = 4 
				then rtrim(A.MARCOD) + '' - '' + rtrim(A.MARNOM) 
				else right((''00'' + ltrim(str(A.MARCOD))),3) + '' - '' + rtrim(A.MARNOM) 
			end as MARNOM,
			CASE WHEN PROUM1QTD > 1 
				THEN RTRIM(LTRIM(PROUM1)) + '' '' + RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '''' + 
					CASE WHEN PROUMV = '''' 
						THEN PROUM1 
						ELSE PROUMV 
					End 
				ELSE RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '''' + 
					CASE WHEN PROUMV = '''' 
						THEN PROUM1 
						ELSE PROUMV 
					End 
			End AS PROUM1,
			CASE WHEN PROLOCFIS = ''''
				THEN 1 
				ELSE 0
			End AS SEMPROLOCFIS,
			CASE WHEN PROLOCFIS <> '''' 
				THEN 1
				ELSE 0
			End AS COMPROLOCFIS, 

			RTRIM(LTRIM(PROSETLOJ1)) AS PROSETLOJ1,
			RTRIM(LTRIM(PROSETLOJ2)) AS PROSETLOJ2,

			CASE WHEN PROSETLOJ1 = '''' AND PROSETLOJ2 = ''''
				THEN 1
				ELSE 0
			End AS SEMSETLOJ,
			CASE WHEN PROSETLOJ1 <> '''' OR PROSETLOJ2 <> ''''
				THEN 1
				ELSE 0
			End AS COMSETLOJ,
			isnull(PROCURABC, '''') as ''PROCURABC''	
		FROM TBS010 A (NOLOCK)
		WHERE 
			PROEMPCOD = @empresaTBS010
			AND PROSTATUS IN (SELECT valor FROM #STATUSPRO)
			AND EXISTS (SELECT PROCOD FROM #CODIGOSPRO B WHERE B.PROCOD = A.PROCOD)
		'
		+
		IIF(@CurvaProduto = 'T', '', ' AND PROCURABC = @CurvaProduto')
		+
		IIF(@Localizacao = '', '', ' AND PROLOCFIS LIKE @Localizacao')
		
	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 int, @CurvaProduto varchar(1), @Localizacao varchar(20)'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS010, @CurvaProduto, @Localizacao	

--	select * from #TBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	IF OBJECT_ID('tempdb.dbo.#SALDOSNOSESTOQUES') IS NOT NULL 
		DROP TABLE #SALDOSNOSESTOQUES;	
	
	-- Cria apenas a estrutura para o comando INSERT INTO com o "SELECT TOP 0"
	SELECT TOP 0
		ESTLOC, 
		B.*,
		ESTQTDATU,
		ESTQTDRES,
		ESTQTDATU-ESTQTDRES AS ESTQTDDIS
	INTO #SALDOSNOSESTOQUES	FROM TBS032 A (NOLOCK)
		INNER JOIN #TBS010 B (NOLOCK) ON A.PROCOD = B.PROCOD

	SET @cmdSQL = N'
		INSERT INTO #SALDOSNOSESTOQUES

		SELECT
			ESTLOC, 
			B.*,
			ESTQTDATU,
			ESTQTDRES,
			ESTQTDATU - ESTQTDRES AS ESTQTDDIS

		FROM TBS032 A (NOLOCK)
			INNER JOIN #TBS010 B (NOLOCK) ON A.PROCOD = B.PROCOD 

		WHERE 
			PROEMPCOD = @empresaTBS010 AND
			ESTLOC IN (SELECT valor FROM #LOCAISEST)
		'
		+
		-- Verifica opções de localização(COM: 'S'; SEM: 'N')
		IIF(@TipoLoc = 'S' OR @TipoLoc = 'N', ' AND B.SEMPROLOCFIS = ' + (CASE WHEN @TipoLoc = 'S' THEN '1' ELSE '0' END), '')
		+
		IIF(@TipoSaldo = 'S',' AND ESTQTDATU > 0', '')
		+
		IIF(@TipoSaldo = 'N', ' AND ESTQTDATU < 0', '')
		+
		IIF(@TipoSaldo = 'Z', ' AND ESTQTDATU = 0', '')
		+
		IIF(@TipoSaldo = 'D', ' AND ESTQTDATU <> 0', '')

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 int'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS010

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	SELECT 
		* 
	FROM #SALDOSNOSESTOQUES
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End