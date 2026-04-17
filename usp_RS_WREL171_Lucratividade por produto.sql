/*
====================================================================================================================================================================================
WREL171 - Lucratividade por produto: Listagem de produtos com a margem de lucro;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
16/04/2026 WILLIAM
	- Inclusao do preco medio de venda do produto, na table afinal;
24/03/2026 WILLIAM
	- Inclusao de agrupamento por marca, e unidade1 do produto, para nao precisar realizar um join na TBS010;
23/03/2026 WILLIAM
	- Inclusao do filtro por subgrupo de produtos;
20/03/2026 WILLIAM
	- Criacao;	
====================================================================================================================================================================================
*/
ALTER PROCEDURE [dbo].[usp_RS_WREL171_LucratividadePorProduto]
--CREATE PROCEDURE [dbo].[usp_RS_WREL171_LucratividadePorProduto_DEBUG]
	@pEmpCod smallint,
	@pDataDe date = NULL, 
	@pDataAte date = NULL,
	@pCodigoProduto varchar(15) = '',
	@pDescricaoProduto varchar(60) = '',
	@pCodigoMarca int = 0,
	@pNomeMarca varchar(30) = '',	
	@pCodigoGrupoProdutos varchar(500) = '',		
	@pCodigoSubGrupoProdutos VARCHAR(MAX) = '',
	@pContabiliza VARCHAR(10) = 'C,L,G'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @DataAte date, @PROCOD varchar(15), @PRODES varchar(60),
			@codigoMarca int, @nomeMarca varchar(30), @codigoGrupoProdutos varchar(500), @codigoSubGrupoProdutos varchar(MAX),
			@contabiliza VARCHAR(10);
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;	
	SET @dataDe = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @PROCOD = @pCodigoProduto;
	SET @PRODES = @pDescricaoProduto;
	SET @codigoGrupoProdutos = @pCodigoGrupoProdutos;	
	SET @codigoSubGrupoProdutos = @pCodigoSubGrupoProdutos;
	SET @codigoMarca = @pCodigoMarca;
	SET @nomeMarca = @pNomeMarca;
	SET @contabiliza = UPPER(@pContabiliza);

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoGrupoProduto = @codigoGrupoProdutos,
		@pcodigoSubGrupoProduto = @codigoSubGrupoProdutos,
		@pcodigoMarca = @codigoMarca,
		@pnomeMarca  = @nomeMarca,
		@pcontabiliza = @contabiliza;
		--@ptipoDocumento = 'N';

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,		
		@pcodigoGrupoProduto = @codigoGrupoProdutos,
		@pcodigoSubGrupoProduto = @codigoSubGrupoProdutos,
		@pcodigoMarca = @codigoMarca,
		@pnomeMarca  = @nomeMarca,
		@pcontabiliza = @contabiliza;

 --SELECT * FROM ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizacao de "CTE", para deixar melhor organizado o codigo

	;WITH
		-- Vendas
		vendas_agrupadas AS(
		SELECT		
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1,
			SUM(valorTotal) AS valorTotal,
			SUM(custoTotal) AS custoTotal,
			SUM(quantidade) AS quantidade
		FROM ##DWVendas
		WHERE documentoReferenciado = ''	-- Filtro necessário para não duplicar as vendas, que foram emitidas notas referenciando cupom fiscal
		
		GROUP BY 
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1
		),
		--SELECT * from vendas_agrupadas;
		
		-- Devolucoes agrupadas por vendedor e seus produtos
		devolucoes_agrupadas AS(		
		SELECT					
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,		
			unidade1,	
			SUM(valorTotal) AS valorTotalDev,
			SUM(custoTotal) AS custoTotalDev,
			SUM(quantidade) AS quantidadeDev
		FROM ##DWDevolucaoVendas
		
		GROUP BY
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1		
		),	
		
		-- Junta os dados de vendas e devolucoes em uma tabela so, para facilitar a contabilizacao
		vendas_devolucoes AS(			
		SELECT 
			v.codigoProduto, 
			v.descricaoProduto, 
			v.codigoGrupo, 
			v.nomeGrupo, 
			v.codigoSubgrupo, 
			v.nomeSubgrupo,
			v.codigoMarca,
			v.nomeMarca,
			v.unidade1 AS unidade,
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
		LEFT JOIN devolucoes_agrupadas d ON
			v.codigoProduto = d.codigoProduto		
		)		
--		select * from vendas_devolucoes;
			
		-- Tabela final com margem de lucro em % = (vendido - devolvido ) / vendido * 100
		SELECT 
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			unidade,
			codigoMarca,
			nomeMarca,
			CAST(valorTotal / NULLIF(quantidade, 0)  AS DECIMAL(19, 4)) AS precoMedio,
			quantidade,			
			valorTotal,
			quantidadeDev,
			valorTotalDev,
			quantidadeLiq,
			valorTotalLiq,	
			custoTotalLiq,
			CAST(ISNULL((valorTotalLiq - custoTotalLiq) / NULLIF(valorTotalLiq, 0) * 100, 0) * IIF(valorTotal < valorTotalDev, -1, 1) AS DECIMAL(7, 2)) 
			AS margemLucro			
		FROM vendas_devolucoes 	
		ORDER BY margemLucro DESC;
				
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END