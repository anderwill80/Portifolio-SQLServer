/*
====================================================================================================================================================================================
WREL059 - Saldo Geral
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
08/04/2026 WILLIAM
	- Uso da funcao "fSplit" para transformar a string de empresas selecionadas no filtro do relatorio em uma tabela temporaria, 
	para facilitar o filtro na tabela [SaldoGeragrupo] que contem os saldos de todas as empresas do grupo BMPT;
	- Refinamento do codigo, retirando os selects individuais por empresa, e dando um select unico na tabela [SaldoGeralGrupo], 
	aplicando o filtro por empresa utilizando a tabela temporaria gerada pela funcao "fSplit";
07/04/2026 WILLIAM
	- Altercao no nome da SP, com o sufixo WREL059, que representa o nome do relatorio na tabela de programas(TBS018) do sistema Integros;
	- Utilizacao da tabela [SaldoGeralGrupo] que foi unificada com os saldos de todas as empresas do grupo BMPT;
	- Refinamento do codigo devido a unificacao das tabelas de saldos de cada empresa em apenas uma tabela, deixando mais limpo;
24/01/2025 WILLIAM
	- Inclusao da tecnica de Parameter Sniffing;
08/02/2024 WILLIAM			
	- Conversao do script SQL para StoredProcedure;
	- Uso de querys dinamicas utilizando a "sp_executesql" para executar comando sql com parametros
	- Alteracao para dar "select" nas tabelas somente das empresas selecionadas no filtro do relatorio, antes se dava select na tabela de cada empresa, 
	e somente na tabela final, aplicava o filtro por UNIDADE;
************************************************************************************************************************************************************************************
*/
CREATE PROC [dbo].[usp_RS_WREL059_SaldoGeral]
--ALTER PROC [dbo].[usp_RS_WREL059_SaldoGeral]
	@COD varchar(15) = '', 
	@DESCRI varchar(60) = '',
	@MARCOD int = 0,
	@MARNOM varchar(30) = '',
	@Opcao varchar(200)	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declaracoes das variaveis locais
	declare	@Query nvarchar (MAX) = '', @ParmDef nvarchar (500) = '', @CODIGO varchar(15) = '', @DESCRICAO varchar(60) = '', @CODMARCA smallint, @NOMEMARCA varchar(30),
			@Empresas varchar(200);

	-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @CODIGO = RTRIM(LTRIM(@COD));
	SET @DESCRICAO = UPPER(RTRIM(LTRIM(@DESCRI)));
	SET @CODMARCA = @MARCOD;
	SET @NOMEMARCA = UPPER(RTRIM(LTRIM(@MARNOM)));
	SET @Empresas = @Opcao;

-- Uso da funcao split, para as clausulas IN()
	IF OBJECT_ID('tempdb.dbo.#EMPRESAS') IS NOT NULL
		DROP TABLE #EMPRESAS;
    SELECT 
		elemento as empresa 
	INTO #EMPRESAS FROM fSplit(@Empresas, ',')	

--	SELECT * FROM #EMPRESAS;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Cria tabela temporaria para armazenar os dados de saldo geral das empresas via script dinâmico;
	IF object_id('tempdb.dbo.#SALDOGERAL') IS NOT NULL
		DROP TABLE #SALDOGERAL;	

	SELECT TOP 0
		DATULTATU,
		UNIDADE,
		CODIGO ,
		DESCRICAO,							
		MARCA,
		UNIDMEDIDA,
		UN2,
		LOJA,						
		DISPONIVEL,
		RESERVADO,
		PENDENTE,
		COMPRAS,
		PRE_ENT,
		COMPRASTT,
		DESCRICAOPDC,			
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR, 
		QTDTRANSITO
	INTO #SALDOGERAL
	FROM SaldoGeralGrupo (NOLOCK);

	SET @Query = N'
	INSERT INTO #SALDOGERAL
	
	SELECT 
		DATULTATU,
		UNIDADE,
		CODIGO ,
		DESCRICAO,							
		MARCA,
		UNIDMEDIDA,
		UN2,
		LOJA,						
		DISPONIVEL,
		RESERVADO,
		PENDENTE,
		COMPRAS,
		PRE_ENT,
		COMPRASTT,
		DESCRICAOPDC,			
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR, 
		QTDTRANSITO
	FROM SaldoGeralGrupo (NOLOCK)
	WHERE 1 = 1
	'
	+
	IIF(@Empresas = '', '', ' AND UNIDADE IN(SELECT empresa FROM #EMPRESAS)')
	+
	IIF(@CODIGO = '', '',  ' AND CODIGO = @CODIGO')
	+
	IIF(@DESCRICAO = '', '',  ' AND DESCRICAO LIKE @DESCRICAO')
	+
	IIF(@CODMARCA <= 0, '',  ' AND MARCOD = @CODMARCA')
	+
	IIF(@NOMEMARCA = '', '',  ' AND MARNOM LIKE @NOMEMARCA')					
	
	--SELECT @Query

	-- Executa a Query dinaminca(QD)
	-- Prepara a SP "sp_executesql"	 
	SET @ParmDef = N'@CODIGO varchar(15), @DESCRICAO varchar(60), @CODMARCA smallint, @NOMEMARCA varchar(30)'
	
	EXEC sp_executesql @Query, @ParmDef, @CODIGO, @DESCRICAO, @CODMARCA, @NOMEMARCA
---------------------------------------------------------------------------------------------------------------------		

	-- Tabela final
	SELECT 
		DATULTATU,
		CASE
			WHEN UNIDADE = 'BB' THEN 'BESTBAG'
			WHEN UNIDADE = 'MI' THEN 'MISASPEL'
			WHEN UNIDADE = 'PY' THEN 'PAPELYNA'			
			WHEN UNIDADE = 'TM' THEN 'TANBY MATRIZ'
			WHEN UNIDADE = 'TT' THEN 'TANBY TAUBATE'
			WHEN UNIDADE = 'TD' THEN 'TANBY CD'			
		END AS UNIDADE,
		CODIGO ,
		DESCRICAO,							
		MARCA,
		UNIDMEDIDA,
		UN2,
		LOJA,						
		DISPONIVEL,
		RESERVADO,
		PENDENTE,
		COMPRAS,
		PRE_ENT,
		COMPRASTT,
		DESCRICAOPDC,			
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR, 
		QTDTRANSITO
	FROM #SALDOGERAL
	ORDER BY CODIGO;
	
---------------------------------------------------------------------------------------------------------------------		
End
