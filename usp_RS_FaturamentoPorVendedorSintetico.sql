/*
====================================================================================================================================================================================
WREL165 - Faturamento  por vendedor sintetico
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
03/06/2025 WILLIAM
	- Calculo da margem de lucro total;
04/04/2025 WILLIAM
	- Criacao, para atender necessidade dos vendedores de Taubate, que executam a todo momento o Relatorio "Faturamento - Devolucoes...Vendedor" a todo momento e
    com a data do dia, fazendo executar a SP "AlimentaDWVendas", consequentemente leva um tempo consideravel de ate 1 minuto, teremos apenas o total faturado por vendedor;
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_FaturamentoPorVendedorSintetico_DEBUG]
--ALTER PROC [dbo].[usp_RS_FaturamentoPorVendedorSintetico] 
	@empcod smallint,
	@dataDe date, 
	@dataAte date, 
	@codigoVendedor varchar(200) = '', 
	@nomeVendedor varchar(60) = '',
	@codigoGrupoVendedores varchar(100) = '',
	@pGrupoBMPT char(1) = 'N'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De date, @data_Ate date, @VENCOD varchar(500), @VENNOM varchar(30),  @GruposVendedores varchar(100), @GrupoBMPT char(1),
			@contabiliza char(10);
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;	
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE() - 1));
	SET @VENCOD = @codigoVendedor;
	SET @VENNOM = @nomeVendedor;
	SET @GruposVendedores = @codigoGrupoVendedores;	
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	
	
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcodigoGrupoVendedor = @GruposVendedores,		
		@pcontabiliza = @contabiliza,
		@ptipoDocumento = 'N';

--	 SELECT * FROM ##DWVendas;
/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcodigoGrupoVendedor = @GruposVendedores,		
		@pcontabiliza = @contabiliza

 --SELECT * FROM ##DWDevolucaoVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para facilitar a codificacao...

	;WITH
		-- Vendas agrupadas por vendedor
		vendas_agrupadas AS(		
		SELECT		
			codigoVendedor,
			SUM(valorTotal) AS valorTotal,
			SUM(valorDescontoTotal) AS valorDescontoTotal,
			SUM(custoTotal) AS custoTotal,
			SUM(valorSemDescontoIcms) AS valorSemDescontoIcms
		FROM ##DWVendas
		
		GROUP by 
			codigoVendedor			
		),
		-- Devolucoes agrupadas por vendedor
		devolucaoes_agrupadas AS(		
		SELECT		
			codigoVendedor,
			SUM(valorTotal) AS valorTotal,
			SUM(custoTotal) AS custoTotal,
			SUM(valorSemDescontoIcms) AS valorSemDescontoIcms
		FROM ##DWDevolucaoVendas
		
		GROUP by 
			codigoVendedor
		),
		-- Junta os dados de vendas e devolucoes em uma tabela so
		vendas_devolucoes AS(			
		SELECT 
			ISNULL(V.codigoVendedor, D.codigoVendedor) AS codigoVendedor,
			ISNULL(VENNOM, '') AS nomeVendedor,
			V.valorTotal,
			V.custoTotal,
			V.valorSemDescontoIcms,
			ISNULL(valorDescontoTotal, 0) AS valorDesconto,

			ISNULL(D.valorTotal, 0) AS valorTotalDev,
			ISNULL(D.custoTotal, 0) AS custoTotalDev,
			ISNULL(D.valorSemDescontoIcms, 0) AS valorSemDescontoIcmsDev,
		
            ROUND(V.valorTotal - ISNULL(D.valorTotal, 0), 2) AS valorTotalLiquido

		FROM vendas_agrupadas V
		LEFT JOIN devolucaoes_agrupadas D ON
		    V.codigoVendedor = D.codigoVendedor
		LEFT JOIN TBS004 ON
			V.codigoVendedor = VENCOD
		),
		-- SELECT
		-- 	valorTotal AS 'Total Venda = V',			
		-- 	valorTotalDev AS 'Total Devol = D',
		-- 	valorTotalLiquido as 'Total Venda Efetiva = VE(V - D)',
		-- 	custoTotal as 'Custo Venda = CV',
		-- 	custoTotalDev as 'Custo Devol = CD',            
		-- 	round(custoTotal - custoTotalDev, 4)  as 'Total Custo Efetivo = CE(CV - CD)',
			
		-- 	ROUND((1 - (CONVERT(DECIMAL(12,4), custoTotal - custoTotalDev)) / (CONVERT(DECIMAL(12,4), valorSemDescontoIcms - valorSemDescontoIcmsDev))) * 100, 4) as 'Margem % = (1 - CE / VE) * 100'

		-- FROM  vendas_devolucoes;					
		margem_total AS (
		SELECT
			IIF(SUM(valorTotal) = SUM(valorTotalDev), 0,
			IIF(SUM(valorTotal) > 0, ROUND((1 - (CONVERT(DECIMAL(12,4), SUM(custoTotal) - SUM(custoTotalDev))) / (CONVERT(DECIMAL(12,4), SUM(valorSemDescontoIcms) - SUM(valorSemDescontoIcmsDev)))) * 100, 4) * IIF(SUM(valorTotal) < SUM(valorTotalDev), - 1, 1),
			ROUND( (1 + (CONVERT(DECIMAL(12,4), SUM(custoTotal) - SUM(custoTotalDev))) / (CONVERT(DECIMAL(12,4), SUM(valorSemDescontoIcms) - SUM(valorSemDescontoIcmsDev))) ) * - 100, 4)))
			AS margemLucroTotal
		FROM vendas_devolucoes			
		)				
		-- Tabela final
		SELECT 
			RIGHT(('0000' + CONVERT(VARCHAR(4), codigoVendedor)), 4) + ' - ' + RTRIM(nomeVendedor) AS codinomeVendedor,
			valorTotal + valorDesconto AS valorTotal,
			valorDesconto,
			valorTotalDev,
			valorTotalLiquido,
			IIF(valorTotal = valorTotalDev, 0,
			IIF(valorTotal > 0, ROUND((1 - (CONVERT(DECIMAL(12,4), custoTotal - custoTotalDev)) / (CONVERT(DECIMAL(12,4), valorSemDescontoIcms - valorSemDescontoIcmsDev))) * 100, 4) * IIF(valorTotal < valorTotalDev, - 1, 1),
			ROUND( (1 + (CONVERT(DECIMAL(12,4), custoTotal - custoTotalDev)) / (CONVERT(DECIMAL(12,4), valorSemDescontoIcms - valorSemDescontoIcmsDev)) ) * - 100, 4)))
			AS margemLucro,

			margemLucroTotal,

            RANK() OVER (ORDER BY valorTotalLiquido DESC) AS rank
		FROM vendas_devolucoes, margem_total

		ORDER BY
            valorTotalLiquido DESC

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END