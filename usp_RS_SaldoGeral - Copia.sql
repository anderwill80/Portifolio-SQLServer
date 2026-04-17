/*
====================================================================================================================================================================================
WREL059 - Saldo Geral
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
24/01/2025 WILLIAM
	- Inclusão da técnica de Parameter Sniffing;
08/02/2024 WILLIAM			
	- Conversão do script SQL para StoredProcedure;
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Alteração para dar "select" nas tabelas somente das empresas selecionadas no filtro do relatório, antes se dava select na tabela de cada empresa, 
	e somente na tabela final, aplicava o filtro por UNIDADE;
************************************************************************************************************************************************************************************
*/
--CREATE PROC [dbo].[usp_RS_SaldoGeral]
ALTER PROC [dbo].[usp_RS_SaldoGeral]
	@COD varchar(15) = '', 
	@DESCRI varchar(60) = '',
	@MARCOD int = 0,
	@MARNOM varchar(30) = '',
	@Opcao varchar(200)	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	declare	@Query nvarchar (MAX) = '', @ParmDef nvarchar (500) = '', @CODIGO varchar(15) = '', @DESCRICAO varchar(60) = '', @CODMARCA int, @NOMEMARCA varchar(30),
			@Empresa varchar(200);

	-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @CODIGO = @COD;
	SET @DESCRICAO = @DESCRI;
	SET @CODMARCA = @MARCOD;
	SET @NOMEMARCA = @MARNOM;
	SET @Empresa = @Opcao;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF object_id('tempdb.dbo.#SALDOGERAL') IS NOT NULL
		DROP TABLE #SALDOGERAL;	
		
	-- Cria a tabela #SALDOGERAL
	CREATE TABLE #SALDOGERAL(
		[UNIDADE] [varchar](8) NULL,
		[CODIGO] [varchar](15) NULL,
		[DESCRICAO] [varchar](60) NULL,
		[MARCA] [varchar](39) NULL,
		[UNIDMEDIDA] [varchar](49) NULL,
		[UN2] [varchar](49) NULL,
		[LOJA] [decimal](13, 6) NOT NULL,
		[DISPONIVEL] [decimal](13, 6) NOT NULL,
		[RESERVADO] [decimal](38, 6) NOT NULL,
		[PENDENTE] [decimal](38, 6) NOT NULL,
		[COMPRAS] [decimal](38, 8) NOT NULL,
		[PRE_ENT] [datetime] NOT NULL,
		[COMPRASTT] [decimal](38, 6) NOT NULL,
		[DESCRICAOPDC] [varchar](60) NOT NULL,
		[DATULTATU] [datetime] NOT NULL,
		[PROPREUM1LOJ] [decimal](11, 4) NULL,
		[PROPREUM2LOJ] [decimal](31, 8) NULL,
		[PROPREUM1COR] [decimal](11, 4) NULL,
		[PROPREUM2COR] [decimal](31, 8) NULL,
		[QTDTRANSITO] [decimal](38, 4) NOT NULL
		)
	----------------------------------------------------------------------------------------------------------------

	IF PATINDEX('%ND%', @Empresa) > 0
	begin
		-- Tanby Matriz
		Set @Query = N'
		INSERT INTO #SALDOGERAL
		
		SELECT 
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
		DATULTATU,
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR, 
		QTDTRANSITO

		FROM ndsaldoatual (nolock)

		WHERE 1 = 1
		'		
		IF LTRIM(RTRIM(@DESCRICAO)) <> ''
			Set @Query += N' AND DESCRICAO LIKE(Upper(RTRIM(@DESCRICAO)) + ''%'')'
		IF LTRIM(RTRIM(@NOMEMARCA)) <> ''
			Set @Query += N' AND MARNOM LIKE(Upper(RTRIM(@NOMEMARCA)) + ''%'')'
		If @CODIGO <> ''
			Set @Query += N' AND CODIGO = @CODIGO'
		IF @CODMARCA > 0
			Set @Query += N' AND MARCOD = @CODMARCA'	  
	End
---------------------------------------------------------------------------------------------------------------------
	 -- CD
	IF PATINDEX('%CD%', @Empresa) > 0
	begin		
		Set @Query += N'
		INSERT INTO #SALDOGERAL
		
		SELECT 
		UNIDADE 	COLLATE DATABASE_DEFAULT AS UNIDADE,
		CODIGO 		COLLATE DATABASE_DEFAULT AS CODIGO ,
		DESCRICAO 	COLLATE DATABASE_DEFAULT AS DESCRICAO,							
		MARCA 		COLLATE DATABASE_DEFAULT AS MARCA,
		UNIDMEDIDA	COLLATE DATABASE_DEFAULT AS UNIDMEDIDA,
		UN2			COLLATE DATABASE_DEFAULT AS UN2,
		LOJA,						
		DISPONIVEL,
		RESERVADO,
		PENDENTE,
		COMPRAS,
		PRE_ENT,
		COMPRASTT,
		DESCRICAOPDC COLLATE DATABASE_DEFAULT AS DESCRICAOPDC,
		DATULTATU,
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR,
		QTDTRANSITO

		FROM cdsaldoatual (nolock)

		WHERE 1 = 1
		'		
		IF LTRIM(RTRIM(@DESCRICAO)) <> ''
			Set @Query += N' AND DESCRICAO LIKE(Upper(RTRIM(@DESCRICAO)) + ''%'')'
		IF LTRIM(RTRIM(@NOMEMARCA)) <> ''
			Set @Query += N' AND MARNOM LIKE(Upper(RTRIM(@NOMEMARCA)) + ''%'')'
		If @CODIGO <> ''
			Set @Query += N' AND CODIGO = @CODIGO'
		IF @CODMARCA > 0
			Set @Query += N' AND MARCOD = @CODMARCA'
	End
---------------------------------------------------------------------------------------------------------------------
	-- MISASPEL
	IF PATINDEX('%MISASPEL%', @Empresa) > 0
	begin	
		Set @Query += N'
		INSERT INTO #SALDOGERAL
		
		SELECT
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
		DATULTATU,
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR,
		QTDTRANSITO

		FROM misaldoatual (nolock)

		WHERE 1 = 1
		'		
		IF LTRIM(RTRIM(@DESCRICAO)) <> ''
			Set @Query += N' AND DESCRICAO LIKE(Upper(RTRIM(@DESCRICAO)) + ''%'')'
		IF LTRIM(RTRIM(@NOMEMARCA)) <> ''
			Set @Query += N' AND MARNOM LIKE(Upper(RTRIM(@NOMEMARCA)) + ''%'')'
		If @CODIGO <> ''
			Set @Query += N' AND CODIGO = @CODIGO'
		IF @CODMARCA > 0
			Set @Query += N' AND MARCOD = @CODMARCA'	
	End

---------------------------------------------------------------------------------------------------------------------
	-- BEST BAG
	IF PATINDEX('%BEST BAG%', @Empresa) > 0
	begin
		Set @Query += N'
		INSERT INTO #SALDOGERAL
		
		SELECT
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
		DATULTATU,
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR,
		QTDTRANSITO

		FROM bbsaldoatual (nolock)

		WHERE 1 = 1
		'		
		IF LTRIM(RTRIM(@DESCRICAO)) <> ''
			Set @Query += N' AND DESCRICAO LIKE(Upper(RTRIM(@DESCRICAO)) + ''%'')'
		IF LTRIM(RTRIM(@NOMEMARCA)) <> ''
			Set @Query += N' AND MARNOM LIKE(Upper(RTRIM(@NOMEMARCA)) + ''%'')'
		If @CODIGO <> ''
			Set @Query += N' AND CODIGO = @CODIGO'
		IF @CODMARCA > 0
			Set @Query += N' AND MARCOD = @CODMARCA'	
	End
---------------------------------------------------------------------------------------------------------------------
	-- PAPELYNA
	IF PATINDEX('%PAPELYNA%', @Empresa) > 0
	begin
		Set @Query += N'
		INSERT INTO #SALDOGERAL
		
		SELECT
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
		DATULTATU,
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR,
		QTDTRANSITO

		FROM pysaldoatual (nolock)

		WHERE 1 = 1
		'		
		IF LTRIM(RTRIM(@DESCRICAO)) <> ''
			Set @Query += N' AND DESCRICAO LIKE(Upper(RTRIM(@DESCRICAO)) + ''%'')'
		IF LTRIM(RTRIM(@NOMEMARCA)) <> ''
			Set @Query += N' AND MARNOM LIKE(Upper(RTRIM(@NOMEMARCA)) + ''%'')'
		If @CODIGO <> ''
			Set @Query += N' AND CODIGO = @CODIGO'
		IF @CODMARCA > 0
			Set @Query += N' AND MARCOD = @CODMARCA'	
	End
---------------------------------------------------------------------------------------------------------------------
 -- TAUBATÉ	
	IF PATINDEX('%TAUBATÉ%', @Empresa) > 0
	begin
		Set @Query += N'
		INSERT INTO #SALDOGERAL
		
		SELECT
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
		DATULTATU,
		PROPREUM1LOJ,
		PROPREUM2LOJ,
		PROPREUM1COR,
		PROPREUM2COR,
		QTDTRANSITO

		FROM ttsaldoatual (nolock)

		WHERE 1 = 1
		'		
		IF LTRIM(RTRIM(@DESCRICAO)) <> ''
			Set @Query += N' AND DESCRICAO LIKE(Upper(RTRIM(@DESCRICAO)) + ''%'')'
		IF LTRIM(RTRIM(@NOMEMARCA)) <> ''
			Set @Query += N' AND MARNOM LIKE(Upper(RTRIM(@NOMEMARCA)) + ''%'')'
		If @CODIGO <> ''
			Set @Query += N' AND CODIGO = @CODIGO'
		IF @CODMARCA > 0
			Set @Query += N' AND MARCOD = @CODMARCA'	
	End
	
	--SELECT @Query

	-- Executa a Query dinâminca(QD)
	-- Prepara a SP "sp_executesql"	 
	SET @ParmDef = N'@CODIGO varchar(15), @DESCRICAO varchar(60), @CODMARCA int, @NOMEMARCA varchar(30)'
	
	EXEC sp_executesql @Query, @ParmDef, @CODIGO, @DESCRICAO, @CODMARCA, @NOMEMARCA

---------------------------------------------------------------------------------------------------------------------		
	-- Tabela final

	SELECT * FROM #SALDOGERAL
---------------------------------------------------------------------------------------------------------------------		
End
