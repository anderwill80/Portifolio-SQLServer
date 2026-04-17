/*
====================================================================================================================================================================================
Procedimento para retornar os codigos dos cliente, para serem usados em outras SP dos relatorios do ReportServer, isso evitara redundancia de codigo;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
30/01/2025 - WILLIAM
	- Alteracao do prefixo do nome de "usp_Get...." para "usp_Get_....";
17/01/2025 - WILLIAM
	- Inclusao do NOME do cliente como parametro de entrada para ser filtrado na consulta;
10/01/2025 - WILLIAM
	- Criacao;
	- Recebe como parametro, opcao para incluir clientes do grupo;
	- Nao utilizar a SP "usp_ClientesGrupo", pois da erro, dessa forma foi unificado o codigo para obter os clientes normais e/ou empresas do grupo;
************************************************************************************************************************************************************************************
*/
--CREATE procedure [dbo].[usp_Get_CodigosClientes_DEBUG]
ALTER procedure [dbo].[usp_Get_CodigosClientes]
	@empcod smallint,
	@pClientes varchar(5000),
	@pNome varchar(60),
	@pIncluirClientesGrupo char(1)
AS 
BEGIN 
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS002 smallint, @cmdSQL nvarchar(MAX), @ParmDef nvarchar(500),
			@Clientes varchar(5000), @CLINOM varchar(60), @IncluirClientesGrupo char(1);

-- Desativando a detecaoo de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Clientes = RTRIM(LTRIM(@pClientes));
	SET @CLINOM = RTRIM(LTRIM(UPPER(@pNome)));
	SET @IncluirClientesGrupo = @pIncluirClientesGrupo;

-- Uso da funcao split, para as claasulas IN()
	--- Codigos dos clientes recebidos via parametro
		If object_id('TempDB.dbo.#PARCLIENTES') is not null
			DROP TABLE #PARCLIENTES;
		SELECT 
			elemento as valor
		INTO #PARCLIENTES FROM fSplit(@Clientes, ',')	
		-- Se parametro vazio, apaga registro sem valor da tabela;
		IF @Clientes = ''
			DELETE #PARCLIENTES;

-- Verificar se tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Otem codigo dos clientes que sao empresas do grupo

	-- IF OBJECT_ID('TEMPDB.DBO.#CLICODGRU') IS NOT NULL
	-- 	DROP TABLE #CLICODGRU;

	-- CREATE TABLE #CLICODGRU (codigo int);

	-- IF @IncluirClientesGrupo = 'S'	
	-- 	INSERT INTO #CLICODGRU
	-- 	EXEC usp_Get_CodigosClientesGrupo @codigoEmpresa;

--	 SELECT * FROM #CLICODGRU

	If object_id('tempdb.dbo.#CLICODGRU') is not null
		drop table #CLICODGRU;

	create table #CLICODGRU (codigo int);
	
	SET @cmdSQL = N'	
		INSERT INTO #CLICODGRU

		select 
			CLICOD 			
		FROM TBS002 A (NOLOCK) 	
		WHERE
		A.CLIEMPCOD = @empresaTBS002 and 
		(A.CLICGC like(''65069593%'') or -- tanbys
		A.CLICGC like(''05118717%'') or -- best bag
		A.CLICGC like(''52080207%'') or -- misaspel
		A.CLICGC like(''44125185%'') or -- papelyna
		A.CLICGC like(''41952080%'')) -- winpack
		'
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS002 smallint'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS002

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- Obtem c�digos dos clientes

	If object_id('tempdb.dbo.#CLICOD') is not null
		DROP TABLE #CLICOD;

	CREATE TABLE #CLICOD (CLICOD INT)

	-- dynamic queries (consultas dinamicas)
	SET @cmdSQL = N'	
		INSERT INTO #CLICOD

		SELECT 
			CLICOD 								
		FROM TBS002 (NOLOCK)
		WHERE
		CLIEMPCOD = @empresaTBS002
		'
		+
		IIF(@Clientes = '', '', ' AND CLICOD IN (SELECT valor from #PARCLIENTES)')	
		+
		IIF(@CLINOM = '', '', ' AND CLINOM LIKE @CLINOM')		
		+
		IIF(@IncluirClientesGrupo = 'S', '', ' AND CLICOD NOT IN (SELECT codigo FROM #CLICODGRU)')
		+
		-- Inclui o c�digo 0(zero), para relat�rios que necessitem filtrar sem cliente;
		' UNION SELECT TOP 1 0 FROM TBS002 (NOLOCK)'

--	print @cmdSQL
	
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS002 smallint, @CLINOM varchar(60)'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS002, @CLINOM
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Executa o select para o resultado da consulta ser usado por quem chamou a SP

	SELECT
		CLICOD
	FROM #CLICOD
	ORDER BY CLICOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END