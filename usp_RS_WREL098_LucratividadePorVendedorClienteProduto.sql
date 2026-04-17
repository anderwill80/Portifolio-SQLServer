/*
====================================================================================================================================================================================
WREL098 - Vendas por vendedor - cliente - produto
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
16/04/2026 WILLIAM
	- Inclusao do preco medio de venda do produto, na table afinal;
02/04/2026 WILLIAM
	- Alteracao do nome da SP para usp_RS_WREL098_LucratividadePorVendedorClienteProduto;
	- Inclusao da margem de lucro para cada agrupamento, grupo de vendedores, vendedor, cliente e produto, por isso a alteracao
	do nome da SP, para refletir a nova informacao incluida no resultado;
09/02/2026 WILLIAM
	- Conversao do parametro de entrada de varchar para int: @codigoCliente;
25/03/2025 WILLIAM
	- Correcao, alterando o tipo do parametro @codigoCliente de int para varchar(100), pois nao estava filtrando por cliente na SP "usp_Get_DWVendas";
21/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
07/01/2025 WILLIAM	
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Inclusao do filtro por empresa de tabela, usando a SP "usp_GetCodigoEmpresaTabela";
====================================================================================================================================================================================
*/
ALTER PROCEDURE [dbo].[usp_RS_WREL098_LucratividadePorVendedorClienteProduto]
--CREATE PROCEDURE [dbo].[usp_RS_WREL098_LucratividadePorVendedorClienteProduto_DEBUG]
	@pEmpCod smallint,
	@pDataDe date = NULL, 
	@pDataAte date = NULL,
	@pCodigoCliente int = 0,
	@pNomeCliente varchar(60) = '',
	@pCodigoProduto varchar(15) = '',
	@pDescricaoProduto varchar(60) = '',
	@pCodigoMarca int = 0,
	@pNomeMarca varchar(30) = '',
	@pCodigoVendedor varchar(500) = '',
	@pNomeVendedor varchar(30) = '',
	@pCodigoGrupoVendedores varchar(500) = '',
	@pContabiliza VARCHAR(10) = 'C,L'	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @DataAte date, @CLICOD INT, @CLINOM VARCHAR(60), @PROCOD varchar(15), @PRODES varchar(60),
			@MARCOD int, @MARNOM varchar(30), @VENCOD varchar(500), @VENNOM varchar(30), @GruposVendedor varchar(500),
			@contabiliza VARCHAR(10), @empresaTBS002 smallint, @empresaTBS004 smallint;
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;	
	SET @dataDe = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @CLICOD = @pCodigoCliente;
	SET @CLINOM = @pNomeCliente;
	SET @PROCOD = @pCodigoProduto;
	SET @PRODES = @pDescricaoProduto;
	SET @MARCOD = @pCodigoMarca;
	SET @MARNOM = @pNomeMarca;
	SET @VENCOD = @pCodigoVendedor;
	SET @VENNOM = @pNomeVendedor;
	SET @GruposVendedor = @pCodigoGrupoVendedores;
	SET @contabiliza = UPPER(@pContabiliza);

-- Uso da funcao split, para as claasulas IN()
	--- Grupo de vendedores
		IF OBJECT_ID('tempdb.dbo.#MV_GRUPOSVEN') IS NOT NULL
			DROP TABLE #MV_GRUPOSVEN;
		SELECT 
			elemento as [valor]
		INTO #MV_GRUPOSVEN FROM fSplit(@GruposVendedor, ',')

-- Verificar se tabela compartilhada ou exclusiva	
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem codigos dos vendedores via SP, incluindo codigo 0(zero)

	IF OBJECT_ID('tempdb.dbo.#CODVEN') IS NOT NULL
		DROP TABLE #CODVEN;

	CREATE TABLE #CODVEN (VENCOD INT)
	
	INSERT INTO #CODVEN
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @VENCOD, @VENNOM, 'TRUE';

	-- Refinamento dos vendedores
	IF OBJECT_ID('tempdb.dbo.#VEND') IS NOT NULL 
		DROP TABLE #VEND;

		SELECT
			VENCOD,
			RTRIM(LTRIM(STR(VENCOD))) + ' - ' + RTRIM(LTRIM(VENNOM)) AS VENNOM,
			V.GVECOD,
			ISNULL(RTRIM(LTRIM(STR(V.GVECOD))) + ' - ' + RTRIM(LTRIM(GVEDES)), 'SEM GRUPO') AS GVEDES
		INTO #VEND FROM TBS004 V (NOLOCK)
			LEFT JOIN TBS091 G (NOLOCK) ON V.GVECOD = G.GVECOD AND V.GVEEMPCOD = G.GVEEMPCOD
		WHERE 
			VENEMPCOD = @empresaTBS004 AND
			VENCOD IN(SELECT VENCOD FROM #CODVEN) AND
			V.GVECOD IN(SELECT valor FROM #MV_GRUPOSVEN) 
		UNION
		SELECT TOP 1			
			0 AS VENCOD,
			'SEM VENDEDOR' AS VENNOM,
			0 AS GVECOD,
			'SEM GRUPO' AS GVEDES
		FROM TBS004 (NOLOCK)

		WHERE
			0 IN(SELECT VENCOD FROM #CODVEN) AND
			0 IN(SELECT valor FROM #MV_GRUPOSVEN)

--	SELECT * FROM #VEND;
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,		
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca  = @MARNOM,
		@pcontabiliza = @contabiliza,
		@pSomenteComClientes = 'S' -- Somente vendas com clientes cadastrados, para evitar vendas com CPF/CNPJ sem vinculo com cliente do cadastro, e consequentemente sem informacao de vendedor, que nao tem como identificar se a venda é do grupo, loja ou corporativo

--	 SELECT * FROM ##DWVendas;

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,		
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca  = @MARNOM,
		@pcontabiliza = @contabiliza

 --SELECT * FROM ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para obter informacao da tabela de METAS, e contabilizar as vendas e devolucoes por vendedor;

	;WITH
		vendas_agrupadas AS(		
		SELECT		
			CONVERT(VARCHAR(6), data, 112) AS data,
			codigoVendedor,
			codigoCliente,
			codigoProduto,
			descricaoProduto,
			unidade1,
			SUM(valorTotal) AS valorTotal,
			SUM(custoTotal) AS custoTotal,
			SUM(quantidade) AS quantidade
		FROM ##DWVendas
		
		GROUP BY 
			CONVERT(VARCHAR(6), data, 112),
			codigoVendedor,
			codigoCliente,
			codigoProduto,
			descricaoProduto,
			unidade1
		),
		devolucoes_agrupadas AS(		
		SELECT		
			CONVERT(VARCHAR(6), data, 112) AS data,
			codigoVendedor,
			codigoCliente,
			codigoProduto,
			descricaoProduto,
			unidade1,
			SUM(valorTotal) AS valorTotalDev,
			SUM(custoTotal) AS custoTotalDev,
			SUM(quantidade) AS quantidadeDev
		FROM ##DWDevolucaoVendas
		
		GROUP BY 
			CONVERT(VARCHAR(6), data, 112),
			codigoVendedor, 
			codigoCliente,
			codigoProduto,
			descricaoProduto,
			unidade1
		),	
		-- Junta os dados de vendas e devolucoes em uma tabela so, para facilitar a contabilizacao
		vendas_devolucoes AS(			
		SELECT 
			v.data,
			GVEDES AS codNomeGrupoVendedor,
			VENNOM AS codNomeVendedor,
			v.codigoVendedor,
			v.codigoCliente,
			c.CLINOM AS nomeCliente,
			v.codigoProduto,
			v.descricaoProduto,
			v.unidade1 as unidade,

			CAST(v.valorTotal AS DECIMAL(19,4)) AS valorTotal,
			CAST(v.custoTotal AS DECIMAL(19,4)) AS custoTotal,
			CAST(v.quantidade AS DECIMAL(19,4)) AS quantidade,

			CAST(ISNULL(valorTotalDev, 0) AS DECIMAL(19,4)) AS valorTotalDev,
			CAST(ISNULL(custoTotalDev, 0) AS DECIMAL(19,4)) AS custoTotalDev,
			CAST(ISNULL(quantidadeDev, 0) AS DECIMAL(19,4)) AS quantidadeDev,

			CAST(v.valorTotal - ISNULL(valorTotalDev, 0) AS DECIMAL(19,4)) AS valorTotalLiq,
			CAST(v.custoTotal - ISNULL(custoTotalDev, 0) AS DECIMAL(19,4)) AS custoTotalLiq,
			CAST(v.quantidade - ISNULL(quantidadeDev, 0) AS DECIMAL(19,4)) AS quantidadeLiq
		FROM vendas_agrupadas v
		JOIN TBS002 c (NOLOCK) ON v.codigoCliente = c.CLICOD AND c.CLIEMPCOD = @empresaTBS002
		JOIN #VEND ON v.codigoVendedor = #VEND.VENCOD
		LEFT JOIN devolucoes_agrupadas d ON
			v.data = d.data AND
			v.codigoVendedor = d.codigoVendedor AND
			v.codigoCliente = d.codigoCliente AND
			v.codigoProduto = d.codigoProduto			
		),				
		totais AS(		
		SELECT 
			data,
			codNomeGrupoVendedor,
			codNomeVendedor,		
			codigoVendedor,
			codigoCliente,
			nomeCliente,
			RTRIM(codigoProduto) AS codigoProduto,
			descricaoProduto,
			unidade,
			quantidade,			
			valorTotal,
			quantidadeDev,
			valorTotalDev,
			quantidadeLiq,
			valorTotalLiq,	
			custoTotalLiq,
			SUM(valorTotal) OVER (PARTITION BY codigoVendedor) AS valorTotalVen,
			SUM(valorTotalDev) OVER (PARTITION BY codigoVendedor) AS valorTotalDevVen,
			SUM(valorTotal) OVER (PARTITION BY codigoCliente) AS valorTotalCli,
			SUM(valorTotalDev) OVER (PARTITION BY codigoCliente) AS valorTotalDevCli,
			SUM(valorTotal) OVER (PARTITION BY codNomeGrupoVendedor) AS valorTotalGrupoVen,
			SUM(valorTotalDev) OVER (PARTITION BY codNomeGrupoVendedor) AS valorTotalDevGrupoVen,
			-- Totais liquidos para o calculo da margem de lucro
			SUM(valorTotalLiq) OVER (PARTITION BY codigoVendedor) AS valorTotalLiqVen,
			SUM(custoTotalLiq) OVER (PARTITION BY codigoVendedor) AS custoTotalLiqVen,
			SUM(valorTotalLiq) OVER (PARTITION BY codigoCliente) AS valorTotalLiqCli,
			SUM(custoTotalLiq) OVER (PARTITION BY codigoCliente) AS custoTotalLiqCli,
			SUM(valorTotalLiq) OVER (PARTITION BY codNomeGrupoVendedor) AS valorTotalLiqGrupoVen,
			SUM(custoTotalLiq) OVER (PARTITION BY codNomeGrupoVendedor) AS custoTotalLiqGrupoVen
		FROM vendas_devolucoes 
		)	
		-- Tabela final calculando as margens de lucro por vendedor, grupo de vendedor e produto	
		SELECT 
			data,
			SUBSTRING(data, 1, 4) + '.' +
			CASE SUBSTRING(data, 5, 2) 
				WHEN '01' THEN 'Jan'
				WHEN '02' THEN 'Fev'
				WHEN '03' THEN 'Mar'
				WHEN '04' THEN 'Abr'
				WHEN '05' THEN 'Mai'
				WHEN '06' THEN 'Jun'
				WHEN '07' THEN 'Jul'
				WHEN '08' THEN 'Ago'
				WHEN '09' THEN 'Set'
				WHEN '10' THEN 'Out'
				WHEN '11' THEN 'Nov'
				WHEN '12' THEN 'Dez'
				ELSE ''
			END AS anoMes,			
			codNomeGrupoVendedor,
			codNomeVendedor,
			codigoVendedor,
			codigoCliente,
			nomeCliente,			
			codigoProduto,
			descricaoProduto,
			unidade,
			CAST(valorTotal / NULLIF(quantidade, 0)  AS DECIMAL(19, 4)) AS precoMedio,
			quantidade,			
			valorTotal,
			quantidadeDev,
			valorTotalDev,
			quantidadeLiq,
			valorTotalLiq,			
			valorTotalVen,
			valorTotalDevVen,
			valorTotalGrupoVen,
			valorTotalDevGrupoVen,
			valorTotalLiqVen,	
			valorTotalCli,
			valorTotalDevCli,
			valorTotalLiqCli,

			valorTotalLiqGrupoVen,		
			CAST(ISNULL((valorTotalLiq - custoTotalLiq) / NULLIF(valorTotalLiq, 0) * 100, 0) AS DECIMAL(7, 2)) 
			AS margemLucro,
			CAST(ISNULL((valorTotalLiqVen - custoTotalLiqVen) / NULLIF(valorTotalLiqVen, 0) * 100, 0) AS DECIMAL(7, 2)) 
			AS margemLucroVen,
			CAST(ISNULL((valorTotalLiqCli - custoTotalLiqCli) / NULLIF(valorTotalLiqCli, 0) * 100, 0) AS DECIMAL(7, 2)) 
			AS margemLucroCli,			
			CAST(ISNULL((valorTotalLiqGrupoVen - custoTotalLiqGrupoVen) / NULLIF(valorTotalLiqGrupoVen, 0) * 100, 0) AS DECIMAL(7, 2)) 
			AS margemLucroGrupoVen
		FROM totais
		ORDER BY 
			codigoVendedor, 
			margemLucro DESC;
/**/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END