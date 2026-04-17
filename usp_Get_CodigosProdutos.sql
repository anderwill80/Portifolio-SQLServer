/*
====================================================================================================================================================================================
Procedimento para retornar os codigos dos produtos, para serem usados em outras SP dos relatorios do ReportServer, isso evitara redundancia de codigo;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
07/10/2025 - WILLIAM
	- Inclusao do parametro de entrada "@pPontoPedido", para listar produtos que calculam ponto de pedido;
	- Atribuicao de valores default aos parametros de entrada, com excecao da "@empcod"
31/01/2025 - WILLIAM
	- Alteracao do prefixo do nome de "usp_Get...." para "usp_Get_....";
16/01/2025 - WILLIAM
	- Alteracao do nome da tabela temporaria para #PROCOD;
15/01/2025 - WILLIAM
	- Criacao;	
====================================================================================================================================================================================
*/
--ALTER procedure [dbo].[usp_Get_CodigosProdutos_DEBUG]
ALTER procedure [dbo].[usp_Get_CodigosProdutos]
	@empcod smallint,
	@pProdutos varchar(5000) = '',
	@pDescricao varchar(60) = '',
	@pMarca int = 0,
	@pMarcaNome varchar(60) = '',
	@pPontoPedido char(1) = ''
AS 
BEGIN 
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @cmdSQL nvarchar(MAX), @ParmDef nvarchar(500),
			@Produtos varchar(5000), @PRODES varchar(60), @MARCOD int, @MARNOM varchar(60), @PontoPedido char(1);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Produtos = RTRIM(LTRIM(@pProdutos));
	SET @PRODES = RTRIM(LTRIM(UPPER(@pDescricao)));
	SET @MARCOD = @pMarca;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@pMarcaNome)));
	SET @PontoPedido = @pPontoPedido;

-- Uso da funcao split, para as clausulas IN()
	--- Codigos dos vendedores recebidos via par�metro
		If object_id('TempDB.dbo.#PARPRODUTOS') is not null
			DROP TABLE #PARPRODUTOS;
		SELECT 
			elemento as valor
		INTO #PARPRODUTOS FROM fSplit(@Produtos, ',')	
		-- Se parametro vazio, apaga registro sem valor da tabela;
		IF @Produtos = ''
			DELETE #PARPRODUTOS;

-- Verificar se a tabela compartilhada ou exclusiva			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- Obtem codigos dos produtos, verificando na tabela de codigo de barras

	IF object_id('tempdb.dbo.#PROCOD') is not null
		DROP TABLE #PROCOD;

	CREATE TABLE #PROCOD (PROCOD varchar(15))

	-- dynamic queries (consultas dinamicas)
	SET @cmdSQL = N'	
		INSERT INTO #PROCOD

		SELECT 
			PROCOD 								
		FROM TBS010 (NOLOCK)
		WHERE
		PROEMPCOD = @empresaTBS010
		'		
		+
		IIF(@PRODES = '', '', ' AND PRODES LIKE @PRODES')
		+
		IIF(@Produtos = '', '', ' AND PROCOD IN (SELECT valor from #PARPRODUTOS)')
		+
		IIF(@MARCOD = 0, '', ' AND MARCOD = @MARCOD')
		+
		IIF(@MARNOM = '', '', ' AND MARNOM LIKE @MARNOM')
		+
		IIF(@PontoPedido = '', '', ' AND PROCALPOP = ''S''')
		+		
		IIF(@Produtos = '', '',' UNION SELECT DISTINCT CBPPROCOD PROCOD  FROM TBS0103 (NOLOCK) WHERE CBPEMP = @empresaTBS010 AND CBPCODBAR IN (SELECT valor from #PARPRODUTOS)')
		+
		IIF(@Produtos <> '', '',' UNION SELECT ''0''')					
			

	--SELECT @cmdSQL			
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS010 smallint, @PRODES varchar(60), @MARCOD int, @MARNOM varchar(60)'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS010, @PRODES, @MARCOD, @MARNOM

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Executa o select para o resultado da consulta ser usado por quem chamou a SP

	SELECT
		PROCOD
	FROM #PROCOD
	ORDER BY 
		PROCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END