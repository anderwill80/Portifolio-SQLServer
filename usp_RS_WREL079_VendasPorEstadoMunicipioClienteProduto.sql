/*
====================================================================================================================================================================================
WREL079 -  Vendas por Estado - Municipio - Cliente - Nota
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
19/02/26 WILLIAM
	- Incluisao de parametro na chamada da SP "usp_Get_DWVendas", para filtrar registros com codigo de clientes preenchidos;
06/02/26 WILLIAM
	- Reativacao do relatorio;
	- Obter as vendas via SP "usp_Get_DWVendas"
24/04/25 WILLIAM
	- NAO USADO;
20/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Inclusao de filtros nas tabelas pela empresa, utilizando o parametro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_WREL079_VendasPorEstadoMunicipioClienteProduto]
ALTER PROCEDURE [dbo].[usp_RS_WREL079_VendasPorEstadoMunicipioClienteProduto]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
	@codigoVendedor varchar(10) = '',
	@codigoCliente int = 0,
	@nomeCliente varchar(60) = '',
	@codigoMarca int = 0,
	@nomeMarca varchar(60) = '',
	@codigoProduto varchar(15) = '',
	@descricaoProduto varchar(60) = '',
	@municipios varchar(MAX) = '',
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint,
			@Data_De datetime, @Data_Ate datetime, @VENCOD varchar(10), @CLICOD int, @CLINOM varchar(60), @MARCOD int, @MARNOM varchar(60),
			@PROCOD varchar(15), @PRODES varchar(60), @municipiosibge varchar(MAX), @GrupoBMPT char(1), 
			@contabiliza char(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @VENCOD = @codigoVendedor;
	SET @CLICOD = @codigoCliente;
	SET @CLINOM = @nomeCliente;
	SET @MARCOD = @codigoMarca;
	SET @MARNOM = @nomeMarca;
	SET @PROCOD = @codigoProduto;
	SET @PRODES = @descricaoProduto;
	SET @municipiosibge = @municipios;
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	

-- Uso da funcao fSplit(), para as clausulas IN(), dos parametros multi-valores

	-- Codigos IBGE dos municipios recebidos via parametro do relatorio
	IF OBJECT_ID('tempdb.dbo.#MV_MUNICIPIOS') IS NOT NULL
		DROP TABLE #MV_MUNICIPIOS;
	SELECT 
		elemento as munnom
	INTO #MV_MUNICIPIOS FROM fSplit(@municipiosibge, ',');
	IF( @municipiosibge = '' )
		DELETE #MV_MUNICIPIOS;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,	
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca = @MARNOM,
		@pcontabiliza = @contabiliza,
		@pSomenteComClientes = 'S'

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	-- EXEC usp_Get_DWDevolucaoVendas
	-- 	@empcod = @codigoEmpresa,
	-- 	@pdataDe = @data_De,
	-- 	@pdataAte = @data_Ate,
	-- 	@pcodigoVendedor = @VENCOD,		
	-- 	@pcodigoCliente  = @CLICOD,
	-- 	@pnomeCliente = @CLINOM,
	-- 	@pcodigoProduto = @PROCOD,
	-- 	@pdescricaoProduto = @PRODES,
	-- 	@pcodigoMarca = @MARCOD,
	-- 	@pnomeMarca = @MARNOM,
	-- 	@pcontabiliza = @contabiliza	
	
--	select * from ##DWVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
	
	-- Obtem vendas com codigo IBGE do municipio, somente para registros com código de cliente preenchidos
	;WITH
		vendas_agrupadas AS(
			SELECT
				uf,
				LTRIM(RTRIM(municipio)) AS municipio,
				codigoCliente,
				nomeCliente,
				codigoVendedor,
				nomeVendedor,
				codigoProduto,
				descricaoProduto,
				codigoMarca,
				nomeMarca,			
				sum(quantidade) as quantidade,
				sum(valorProdutos) as bruto,
				sum(valorTotal) as liquido,
				sum(valorDescontoTotal) as desconto
			FROM ##DWVendas

			GROUP BY
				uf,		
				LTRIM(RTRIM(municipio)),				
				codigoCliente,
				nomeCliente,
				codigoVendedor,
				nomeVendedor,
				codigoProduto,
				descricaoProduto,
				codigoMarca,
				nomeMarca

		)
		-- Tabela final
		SELECT 
			*
		FROM vendas_agrupadas
		WHERE municipio IN(SELECT munnom FROM #MV_MUNICIPIOS);

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;		

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END