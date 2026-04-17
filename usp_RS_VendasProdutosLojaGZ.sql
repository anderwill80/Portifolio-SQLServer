/*
====================================================================================================================================================================================
WREL073	- Vendas de produtos da Loja GZ
	OBS.: Contabiliza o que vendeu pela loja, independente de ter sido o corporativo ou a loja que vendeu, passou no gz contabiliza;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
08/04/2025 WILLIAM
	- Troca do parametro "@pSomenteCupom = 'S'" pelo "ptipoDocumento = 'C'" na chamada da SP "usp_Get_DWVendas";
17/02/2025 WILLIAM
	- Uso da SP "usp_Get_DWVendas", para obter dados das vendas de loja;
	- Refinamento do codigo, para adaptar aos dados da DWVendas;
	- Definir valores padrao para os parametros de entrada, com excecao do @empcod, isso simplifica a chamada da SP, preenchendo somente os parametros que precisamos;
22/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;		
	- Uso da SP "usp_GetCodigosClientes";
	- Verificacao do parametro 1134, para obter o local de estoque da loja, isso ira atender a BestArts, que trabalha com estoque 1 na loja;
	- Alteracao da leitura dos cupons, via tabela do Integros movcaixagz, em vez de acessar o banco da GZ, deixando a consulta mais rapida;
====================================================================================================================================================================================
*/ 
--ALTER PROCEDURE [dbo].[usp_RS_VendasProdutosLojaGZ_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_VendasProdutosLojaGZ]
	@empcod smallint,
	@dataDe datetime = null,
	@dataAte datetime = null,
	@codigoproduto varchar(15) = '',
	@descricaoproduto varchar(60) = '',
	@codigomarca int = 0,
	@nomemarca varchar(60) = ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @Data_De datetime, @Data_Ate datetime, @PROCOD varchar(15), @PRODES varchar(60), @MARCOD int, @MARNOM varchar(60),
			@LocalLoja smallint;

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'))
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()))
	SET @PROCOD = RTRIM(LTRIM(UPPER(@codigoproduto)));
	SET @PRODES = RTRIM(LTRIM(UPPER(@descricaoproduto)));
	SET @MARCOD = @codigomarca;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@nomemarca)));

	-- Obtem local de estoque da loja, via parametro
	SET @LocalLoja = CONVERT(int, dbo.ufn_Get_Parametro(1134));
	-- Caso parametro nao definido, seta por padrao o local 2
	If @LocalLoja = 0
		set @LocalLoja = 2;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem as vendas de loja via SP que retorna dados da DWVendas, gerando a tabela global ##DWVendas
	
	EXEC usp_Get_DWVendas 
		@empcod = @codigoEmpresa, 
		@pdataDe = @Data_De, 
		@pdataAte = @Data_Ate,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca = @MARNOM,
		@pcontabiliza = 'C,L',	-- Desconsiderar vendas para empresas do grupo 'G'
		@ptipoDocumento = 'C'	-- Somente vendas feitas com cupom fiscal

--	SELECT * FROM ##DWVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Acumula quantidade, valores e medias dos produtos vendidos

	IF OBJECT_ID('tempdb.dbo.#TOTALPORPRODUTO') IS NOT NULL
		DROP TABLE #TOTALPORPRODUTO;

	SELECT 
		codigoProduto AS PROCOD,
		ROUND(SUM(quantidade), 2) AS VENQTD,
		ROUND(SUM(valorTotal), 2) AS VENVAL,
		ROUND(AVG(precoUnitario), 2) AS VALMED,
		ROUND(AVG(custoUnitario), 2) AS CUSTO,
		ROUND(SUM(custoTotal), 2) AS CUSVAL

	INTO #TOTALPORPRODUTO FROM ##DWVendas	

	GROUP BY 
		codigoProduto

--	SELECT * FROM #TOTALPORPRODUTO	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem saldo dos produtos vendidos, do local: LOJA

	IF OBJECT_ID('tempdb.dbo.#SALDO') IS NOT NULL
		DROP TABLE #SALDO;

	SELECT 
		PROCOD,
		ESTQTDATU - ESTQTDRES AS EST2

	INTO #SALDO FROM TBS032 A (NOLOCK)

	WHERE 
		PROCOD COLLATE DATABASE_DEFAULT IN(SELECT PROCOD FROM #TOTALPORPRODUTO) AND
		ESTLOC = @LocalLoja
		--(ESTQTDATU <> 0 OR ESTQTDPEN <> 0 OR ESTQTDCMP <> 0 )

--	SELECT * FROM #SALDO
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Refinamento dos dados do produto

	IF OBJECT_ID('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;

	SELECT 
		CASE
			WHEN LEN(MARCOD) = 4 
				THEN 
					RTRIM(MARCOD) + ' - ' + RTRIM(MARNOM) 
				ELSE 
					RIGHT(('0000' + CONVERT(VARCHAR(4), MARCOD)), 4) + ' - ' + RTRIM(MARNOM) 
		END AS 'MARCA',
		PROCOD,
		PRODES,
		PROUM1

	INTO #TBS010 FROM TBS010 (NOLOCK)

	WHERE
		PROCOD COLLATE DATABASE_DEFAULT IN(SELECT PROCOD FROM #TOTALPORPRODUTO)

--	SELECT * FROM #TBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL 

	SELECT 
		MARCA,
		RTRIM(LTRIM(A.PROCOD)) AS PROCOD,
		PRODES,
		PROUM1,
		VENQTD,
		VALMED,
		VENVAL,
		CUSTO,
		CUSVAL,
		ROUND(VENVAL - CUSVAL, 2) AS LUCVAL,
		EST2

	FROM #TBS010 A (NOLOCK)
		LEFT JOIN #SALDO B ON A.PROCOD = B.PROCOD 
		LEFT JOIN #TOTALPORPRODUTO C ON A.PROCOD COLLATE DATABASE_DEFAULT = C.PROCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END