/*
====================================================================================================================================================================================
Procedimento para retornar os códigos dos vendedores, para serem usados em outras SP dos relatórios do ReportServer, isso evitará redundância de código;
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
29/01/2025 - WILLIAM
	- Inclusão do NOME do vendedor como parametro de entrada para ser filtrado na consulta;
	- Troca dos nomes das tabelas temporarias(#) para evitar conflitos com os objetos chamadores da SP;
	- Alteracao do prefixo do nome de "usp_Get...." para "usp_Get_....";
	- Inclusao do parametro @pComZero, para permitir incluir o registro 0(zero) na tabela de retorno, caso nao tenha passado nenhum codigo especifico de vendedor;
13/01/2025 - WILLIAM
	- Correção ao realizar o UNION quando código 0(zero) for passado por parâmetro;
	- Inclusão do hint "OPTION(MAXRECURSION 0)"´, após a chamada da função fSplit() do Municipios para lista de valores do subgrupo, pois tem mais de 100 itens;
10/01/2025 - WILLIAM
	- Criação;
====================================================================================================================================================================================
*/
CREATE PROC [dbo].[usp_Get_CodigosVendedores]
--ALTER PROC [dbo].[usp_Get_CodigosVendedores]
	@empcod smallint,
	@pVendedores varchar(500),
	@pNome varchar(60),
	@pComZero bit
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS004 smallint,
			@Vendedores varchar(500), @VENNOM varchar(60), @ComZero bit,
			@cmdSQL nvarchar(MAX), @ParmDef nvarchar(500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Vendedores = RTRIM(LTRIM(@pVendedores));	
	SET @VENNOM = RTRIM(LTRIM(UPPER(@pNome)));
	SET @ComZero = @pComZero;

-- Uso da função split, para as claúsulas IN()
	-- Codigos dos vendedores recebidos via parâmetro
	IF OBJECT_ID('tempdb.dbo.#PARVENDEDORES') IS NOT NULL
		DROP TABLE #PARVENDEDORES;

	SELECT 
		elemento AS valor
	INTO #PARVENDEDORES FROM fSplit(@Vendedores, ',') OPTION(MAXRECURSION 0)

	IF @Vendedores = ''
		DELETE #PARVENDEDORES; -- Se parâmetro vazio, apaga registro sem valor da tabela;

-- Verificar se a tabela é compartilhada ou exclusiva			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	If OBJECT_ID('tempdb.dbo.#VENCOD') IS NOT NULL
		DROP TABLE #VENCOD;

	CREATE TABLE #VENCOD (VENCOD INT)

	-- dynamic queries (consultas dinamicas)
	SET @cmdSQL = N'	
		INSERT INTO #VENCOD

		SELECT 
			VENCOD 								
		FROM TBS004 (NOLOCK)

		WHERE
			VENEMPCOD = @empresaTBS004
		'
		+
		IIF(@Vendedores = '', '', ' AND VENCOD IN (SELECT valor from #PARVENDEDORES)')		
		+		
		IIF(@VENNOM = '', '', ' AND VENNOM LIKE @VENNOM')	
		+		
		IIF(@Vendedores = '', '', ' UNION SELECT TOP 1 0 FROM TBS004 (NOLOCK) WHERE 0 IN (SELECT valor from #PARVENDEDORES)')
		+		
		IIF(@Vendedores <> '' OR @VENNOM <> '' OR @ComZero = 0, '', ' UNION SELECT TOP 1 0 FROM TBS004 (NOLOCK)')
	
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS004 smallint, @VENNOM varchar(60)'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS004, @VENNOM

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Executa o select para o resultado da consulta ser usado por quem chamou a SP

	SELECT
		VENCOD
	FROM #VENCOD	
	ORDER BY 
		VENCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END