/*
====================================================================================================================================================================================
Procedimento para retornar os códigos dos fornecedores, para serem usados em outras SP dos relatórios do ReportServer, isso evitará redundância de código;
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
17/01/2025 - WILLIAM
	- Criação;
	- Recebe como parâmetro, opção para incluir fornecedors do grupo;
************************************************************************************************************************************************************************************
*/
--CREATE procedure [dbo].[usp_GetCodigosFornecedores]
ALTER procedure [dbo].[usp_GetCodigosFornecedores]
	@empcod smallint,
	@pFornecedores varchar(5000),
	@pNome varchar(60),
	@pIncluirForneGrupo char(1)
AS 
BEGIN 
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS006 smallint, @cmdSQL nvarchar(MAX), @ParmDef nvarchar(500),
			@Fornecedores varchar(5000), @FORNOM varchar(60), @IncluirForneGrupo char(1);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Fornecedores = RTRIM(LTRIM(@pFornecedores));
	SET @FORNOM = RTRIM(LTRIM(UPPER(@pNome)));
	SET @IncluirForneGrupo = @pIncluirForneGrupo;

-- Uso da função split, para as claúsulas IN()
	--- Codigos dos vendedores recebidos via parâmetro
		If object_id('TempDB.dbo.#FORNE') is not null
			DROP TABLE #FORNE;
		select 
			elemento as valor
		Into #FORNE
		From fSplit(@Fornecedores, ',')	
		-- Se parâmetro vazio, apaga registro sem valor da tabela;
		IF @Fornecedores = ''
			DELETE #FORNE

-- Verificar se a tabela é compartilhada ou exclusiva			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS006', @empresaTBS006 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Otem código dos Fornecedors que são empresas do grupo

	If object_id('tempdb.dbo.#CodigosFornecedorGrupo') is not null
		drop table #CodigosFornecedorGrupo;

	create table #CodigosFornecedorGrupo (codigo int);
	
	SET @cmdSQL = N'	
		INSERT INTO #CodigosFornecedorGrupo

		SELECT
			FORCOD 	
		FROM TBS006 A (NOLOCK) 	
		WHERE
			A.FOREMPCOD = @EMPRESATBS006 AND 
			(A.FORCGC like(''65069593%'') OR -- tanbys
			A.FORCGC like(''05118717%'') OR -- misaspel
			A.FORCGC like(''52080207%'') OR -- best bag
			A.FORCGC like(''44125185%'') OR	-- papelyna
			A.FORCGC like(''41952080%'')) -- winpack
		ORDER BY
			A.FOREMPCOD,
			A.FORCGC'			
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS006 smallint'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS006

--	 SELECT * FROM #CodigosFornecedorGrupo
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- Obtem códigos dos Fornecedores

	If object_id('tempdb.dbo.#FORCOD') is not null
		DROP TABLE #FORCOD;

	CREATE TABLE #FORCOD (FORCOD INT)

	-- dynamic queries (consultas dinamicas)
	SET @cmdSQL = N'	
		INSERT INTO #FORCOD

		SELECT 
			FORCOD 								
		FROM TBS006 (NOLOCK)
		WHERE
		FOREMPCOD = @empresaTBS006
		'
		+
		IIF(@Fornecedores = '' OR @Fornecedores = '0', '', ' AND FORCOD IN (SELECT valor from #FORNE)')
		+
		IIF(@FORNOM = '', '', ' AND FORNOM LIKE @FORNOM')
		+
		IIF(@IncluirForneGrupo = 'S', '', ' AND FORCOD NOT IN (SELECT codigo FROM #CodigosFornecedorGrupo)')
		+
		-- Inclui o código 0(zero), para relatórios que necessitem filtrar sem Fornecedor;
		' UNION SELECT TOP 1 0 FROM TBS006 (NOLOCK)'

--	print @cmdSQL
	
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS006 smallint, @FORNOM varchar(60)'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS006, @FORNOM
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Executa o select para o resultado da consulta ser usado por quem chamou a SP

	SELECT
		FORCOD
	FROM #FORCOD
	ORDER BY FORCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END