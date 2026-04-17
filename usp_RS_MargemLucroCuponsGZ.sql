/*
====================================================================================================================================================================================
WREL133 - Margem de Lucro dos Cupons GZ 
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
08/04/2025 WILLIAM
	- Troca do parametro "@pSomenteCupom = 'S'" pelo "ptipoDocumento = 'C'" na chamada da SP "usp_Get_DWVendas"; 
12/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
13/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Uso da SP "sp_movcaixa" pela "usp_movcaixa";
	- Uso da SP "sp_movcaixagz" pela "usp_movcaixagz";
	- Retirada da varificacao se empresa tem frente de loja, ja que o rel. vai ser implantado em empresas com frente de loja;
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_MargemLucroCuponsGZ_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_MargemLucroCuponsGZ]
	@empcod smallint,
	@dataDe date,
	@dataAte date
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De date, @data_Ate date;			

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	-- somente os cupons cancelados
	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,		
		@pSomenteCancelados = 'S',
		@ptipoDocumento = 'C'	-- Somente vendas feitas com cupom fiscal		

	If OBJECT_ID('tempdb.dbo.#CANCELADOS') IS NOT NULL
		DROP TABLE #CANCELADOS;

	SELECT
		data,
		caixa,
		numeroDocumento AS cupom,
		codigoProduto
	 INTO #CANCELADOS FROM ##DWVendas

	-- Obtem os cupons considerando os que foram cancelados, para serem marcados e contabilizados na tabela final
	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,		
		@pDesconsiderarCancelados = 'N',
		@ptipoDocumento = 'C'	-- Somente vendas feitas com cupom fiscal				
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas dos cupons

	;WITH
		-- as vendas, verificando se item esta cancelado
		vendas AS (
			SELECT
				data,
				IIF(EXISTS(SELECT '' FROM #CANCELADOS C WHERE C.data = V.data AND C.cupom = V.numeroDocumento AND C.caixa = V.caixa AND C.codigoProduto = V.codigoProduto), 
					'S', ''
				) AS cancelado,
				caixa,
				numeroDocumento AS cupom,
				codigoProduto,
				descricaoProduto AS descricao,
				unidade1 AS menorUnidade,
				quantidade,
				precoUnitario AS preco,
				valorProdutos AS valorBruto,
				valorDescontoTotal AS desconto,
				0 AS acrescimo,
				custoUnitario AS custo,		
				'Cupom' AS tipoCusto,
				IIF(EXISTS(SELECT '' FROM #CANCELADOS C WHERE C.data = V.data AND C.cupom = V.numeroDocumento AND C.caixa = V.caixa AND C.codigoProduto = V.codigoProduto), 
					0, custoTotal
				) AS custoTotal,
				IIF(EXISTS(SELECT '' FROM #CANCELADOS C WHERE C.data = V.data AND C.cupom = V.numeroDocumento AND C.caixa = V.caixa AND C.codigoProduto = V.codigoProduto), 
					0, valorTotal
				) AS liquido,
				IIF(EXISTS(SELECT '' FROM #CANCELADOS C WHERE C.data = V.data AND C.cupom = V.numeroDocumento AND C.caixa = V.caixa AND C.codigoProduto = V.codigoProduto), 
					valorTotal, 0
				) AS valorCancelado,
				IIF(EXISTS(SELECT '' FROM #CANCELADOS C WHERE C.data = V.data AND C.cupom = V.numeroDocumento AND C.caixa = V.caixa AND C.codigoProduto = V.codigoProduto), 
					0, ROUND(margemLucro, 4)
				) AS margem,
				0 AS qtdItensPolitica
			FROM ##DWVendas V
		)
		SELECT
			*
		FROM vendas

		ORDER BY
			codigoProduto
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
END