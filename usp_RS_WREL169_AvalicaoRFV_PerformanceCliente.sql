/*
====================================================================================================================================================================================
WREL169 - Avaliacao RFV(Recencia, frequencia e valor) - Performance do cliente no periodo
====================================================================================================================================================================================
	Permite classificar os clientes que compraram no periodo informado, atraves de 1...5 estrelas
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
09/03/2026 WILLIAM
	- Agrupamento pelo codigo de vendedor ao obter as vendas da ##DWVendas, e obter o nome do vendedor apenas na tabela final;
06/03/2026 WILLIAM
	- Revisao ao classificar cliente pela frequencia, dando estrela 1 para quando comprou 1 vez no mesmo dia, funcao NTILE() estava dando estrela 5, devido valor zero
05/03/2026 WILLIAM
	- Criacao
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_RS_WREL169_AvalicaoRFV_Por_Cliente_DEBUG]
ALTER PROC [dbo].[usp_RS_WREL169_AvalicaoRFV_Por_Cliente] 
	@pEmpCod smallint,
	@pDataDe date, 
	@pDataAte date, 
	@pCodigoVendedor varchar(200) = '', 
	@pCodigoGrupoVendedores varchar(100) = '',
	@pGrupoBMPT char(1) = 'N'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De date, @data_Ate date, @VENCOD varchar(500), @GruposVendedores varchar(100), @GrupoBMPT char(1),
			@contabiliza char(10);
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod	
	SET @data_De = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @VENCOD = @pCodigoVendedor;
	SET @GruposVendedores = @pCodigoGrupoVendedores;	
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
		@pcodigoGrupoVendedor = @GruposVendedores,		
		@pcontabiliza = @contabiliza,
		--@ptipoDocumento = 'N',
		@pSomenteComClientes = 'S';

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	-- EXEC usp_Get_DWDevolucaoVendas
	-- 	@empcod = @codigoEmpresa,
	-- 	@pdataDe = @data_De,
	-- 	@pdataAte = @data_Ate,
	-- 	@pcodigoVendedor = @VENCOD,
	-- 	@pcodigoGrupoVendedor = @GruposVendedores,		
	-- 	@pcontabiliza = @contabiliza		

--	 SELECT * FROM ##DWVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para facilitar a codificacao...
	;WITH
		-- Elimina as vendas com emissao de nota de cupom, para nao duppicar vendas, ja que teve a vendo no cupom
		compras_unicas_sem_nf_cupom AS (
		SELECT
			codigoCliente, 
			codigoVendedor,
			numeroDocumento, 
			data,    
			valorTotal			
		FROM ##DWVendas
		WHERE 
			documentoReferenciado = ''
		),
		-- Vendas agrupadas por ano, mes e vendedor
		compras_unicas_por_clientes AS(
		SELECT
			codigoCliente, 
			codigoVendedor,
			numeroDocumento, 
			data,    
			sum(valorTotal) AS valorTotal			
		FROM compras_unicas_sem_nf_cupom

		GROUP BY 
			codigoCliente, codigoVendedor, numeroDocumento, data
		),

		-- Obtem valor total por cliente e seus indices(frequencia, atividade e dias de relacionamento)
		compras_por_clientes_total AS(
		SELECT 
			codigoCliente,
			codigoVendedor,
			COUNT(numeroDocumento) AS qtdCompras,
			sum(valorTotal) AS valorCompras,
			DATEDIFF(DAY, MIN(data), MAX(data)) AS diasRelacionamento,
			
			-- Frequência: Total de Dias / Total de Compras (evitando divisão por zero)    
			ISNULL(DATEDIFF(DAY, MIN(data), MAX(data)) / (NULLIF(COUNT(numeroDocumento) - 1, 0)), 0) AS diasFrequencia,
			DATEDIFF(day, MAX(data), GETDATE()) AS atividade
			--MAX(data) ultima_compra
		FROM compras_unicas_por_clientes

		GROUP BY codigoCliente, codigoVendedor
		HAVING COUNT(numeroDocumento) > 1 -- apenas clientes recorrentes
		),
		--select * from compras_por_clientes_total;

		-- Calcula o ticket medido por cliente
		compras_por_cliente_ticketmedio AS(
		SELECT			
    		*,    
    		CAST(ISNULL(valorCompras / NULLIF(qtdCompras, 0), 0) AS DECIMAL(19, 4)) AS ticketMedio    		
		FROM compras_por_clientes_total		
		),

		-- Classifica por estrelas, utilizando "WF" NTILE()
		classificao_estrelas AS(
		SELECT 
			*,    
			NTILE(5) OVER (ORDER BY diasFrequencia DESC) AS frequenciaEstrelas,
			NTILE(5) OVER (ORDER BY ticketMedio ASC) AS ticketMedioEstrelas,
			NTILE(5) OVER (ORDER BY atividade DESC) AS atividadeEstrelas
		FROM compras_por_cliente_ticketmedio
		),

		classificao_estrelas_refinada AS(
		SELECT
			codigoCliente,
			codigoVendedor,
			qtdCompras,
			valorCompras,
			diasFrequencia,
			diasRelacionamento,
			atividade,
			ticketMedio,
			IIF(diasFrequencia = 0, 1, frequenciaEstrelas) AS frequenciaEstrelas,	-- Faz uma verificação se cliente comprou em um unico dia, recebe 1 de estrela
			ticketMedioEstrelas,
			atividadeEstrelas
		FROM classificao_estrelas
		)

		-- Tabela final, buscando nome do vendedor que atende o cliente		
		SELECT 
			codigoCliente,
			ISNULL(CLINOM, '') AS nomeCliente,
			codigoVendedor,
			ISNULL(VENNOM, '') AS nomeVendedor,
			qtdCompras,
			valorCompras,
			diasFrequencia,
			diasRelacionamento,
			atividade,
			ticketMedio,
			frequenciaEstrelas,
			ticketMedioEstrelas,
			atividadeEstrelas,
			ROUND((frequenciaEstrelas + ticketMedioEstrelas + atividadeEstrelas), 2) / 3 AS avaliacaoGeral			
		FROM classificao_estrelas_refinada
		LEFT JOIN TBS002 (NOLOCK) ON CLICOD = codigoCliente
		LEFT JOIN TBS004 (NOLOCK) v ON v.VENCOD = codigoVendedor
		ORDER BY
			avaliacaoGeral DESC;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END