/*
====================================================================================================================================================================================
WREL167_SUB - Cobertura de clientes - Clientes que compraram o produto recebido por parametro pelo relatorio principal
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
23/02/26 WILLIAM
	- Criacao;	
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_WREL167_SUB_CoberturadeClientes_Compraram]
ALTER PROCEDURE [dbo].[usp_RS_WREL167_SUB_CoberturadeClientes_Compraram]
	@pEmpcod smallint,
	@pDataDe datetime,
	@pDataAte datetime,
	@pCodigoVendedor varchar(10),
	@pCodigoProduto varchar(20),
	@pGrupoBMPT char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint,
			@Data_De datetime, @Data_Ate datetime, @VENCOD varchar(10), @PROCOD varchar(20), @GrupoBMPT char(1), 
			@contabiliza char(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpcod;
	SET @Data_De = @pDataDe;
	SET @Data_Ate = @pDataAte;
	SET @VENCOD = @pCodigoVendedor;
	SET @PROCOD = @pCodigoProduto;
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	

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
		@pcodigoProduto = @PROCOD,
		@pcontabiliza = @contabiliza,
		@pSomenteComClientes = 'S'

--	SELECT * FROM ##DWVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
	
	-- Obtem a quantidade de clientes distintos, para calculo da porcentagem dos que compraram
	
	;with
		-- Agrupa por produto e cliente
		produtos as(
			SELECT
				codigoProduto,
				descricaoProduto,				
				codigoCliente,
				nomeCliente,
				SUM(quantidade) AS quantidade,
				SUM(valorTotal) AS valorTotal
			FROM ##DWVendas
			GROUP BY codigoProduto, descricaoProduto, codigoCliente, nomeCliente

		)

		-- Tabela final
		SELECT 
			* 
		FROM produtos
		ORDER BY quantidade DESC;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
END
