/*
====================================================================================================================================================================================
WREL167 -  Cobertura de clientes
Permite obter as vendas de produtos de clientes cadastrados no sistema, identificando quantos clientes compraram ou nao cada produto
conforme periodo informado
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
20/02/26 WILLIAM
	- Criacao;
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_WREL167_CoberturadeClientes]
ALTER PROCEDURE [dbo].[usp_RS_WREL167_CoberturadeClientes]
	@pEmpcod smallint,
	@pDataDe datetime = NULL,
	@pDataAte datetime = NULL,
	@pCodigoVendedor varchar(10) = '',
	@pGrupoBMPT char(1) = 'N'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint,
			@Data_De datetime, @Data_Ate datetime, @VENCOD varchar(10), @GrupoBMPT char(1), 
			@contabiliza char(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpcod;
	SET @Data_De = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @Data_Ate = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @VENCOD = @pCodigoVendedor;
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
		@pcontabiliza = @contabiliza,
		@pSomenteComClientes = 'S'

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
				SUM(valorTotal) AS valorTotal
			FROM ##DWVendas
			GROUP BY codigoProduto, descricaoProduto, codigoCliente

		),-- select * from produtos order by codigoCliente;

		-- Obtem clientes unicos que realizam compras
		quantclientes AS(
			SELECT COUNT(DISTINCT codigoCliente) AS totalClientes
			FROM produtos						
		),

		-- Totaliza por produtos para saber quantos clientes compraram cada produto
		total_produtos as(
			SELECT
				codigoProduto,
				descricaoProduto,				
				count(codigoProduto) AS Comprou,
				sum(valorTotal) as valorTotal
			FROM produtos
			GROUP BY 
				codigoProduto, descricaoProduto	
		) --  select * from total_produtos where codigoProduto = '1640054';
							
		-- Tabela final	
		SELECT 
			codigoProduto,
			descricaoProduto,
			CAST(ROUND(1.0 * Comprou / totalClientes * 100, 2) AS DECIMAL(5,2)) as Porcentagem,			
			Comprou,
			totalClientes - Comprou as NaoComprou,
			CAST(valorTotal AS DECIMAL(19,4)) AS valorTotal,
			totalClientes
		FROM total_produtos p, quantclientes
		ORDER BY Comprou desc;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
END