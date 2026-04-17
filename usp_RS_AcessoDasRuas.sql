/*
====================================================================================================================================================================================
WREL134 - /Release/TanbyMatriz/Relatorios/Acesso das ruas
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
22/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;		
************************************************************************************************************************************************************************************
*/ 
CREATE PROCEDURE [dbo].[usp_RS_AcessoDasRuas]
--ALTER PROCEDURE [dbo].[usp_RS_AcessoDasRuas]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, 
			@Data_De datetime, @Data_Ate datetime,  @estoqueOrigem int;

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'))
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()))

	SET @estoqueOrigem = 1
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Notas autorizadas

	IF object_id('tempdb.dbo.#NOTASAUTORIZADAS') IS NOT NULL
		DROP TABLE #NOTASAUTORIZADAS;

	SELECT
		A.ENFDATEMI as dataEmissao,
		SNESER as serieNota,
		ENFNUM as numeroNota
	INTO #NOTASAUTORIZADAS	FROM TBS080 A (NOLOCK)
	
	WHERE 
		A.ENFDATEMI BETWEEN @Data_De AND @Data_Ate AND
		A.ENFSIT = 6 AND 
		A.ENFFINEMI = 1

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Notas de vendas e transferencia. Pegar o numero maximo de qtd

	IF object_id('tempdb.dbo.#NOTASSAIDAVENDATRANSFERENCIA') IS NOT NULL	
		DROP TABLE #NOTASSAIDAVENDATRANSFERENCIA;

	SELECT 
		rtrim(PROCOD) as codigoProduto,
		row_number() over(partition by rtrim(PROCOD) order by dataEmissao ) as qtd
	INTO #NOTASSAIDAVENDATRANSFERENCIA	FROM TBS0671 B (NOLOCK)
		inner join #NOTASAUTORIZADAS A on B.NFSNUM = A.numeroNota AND B.SNESER = A.serieNota
	WHERE 
		B.LESCOD = @estoqueOrigem
	GROUP BY 
		A.serieNota,
		A.numeroNota,
		rtrim(PROCOD),
		dataEmissao

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Trasferencia entre estoque. Sai do 1 para qualquer outro estoque, não considerar as saidas forçadas do estoque. Pegar o numero maximo de qtd

	IF object_id('tempdb.dbo.#TRASFERENCIAESTOQUE') IS NOT NULL
		DROP TABLE #TRASFERENCIAESTOQUE;

	SELECT 
		rtrim(B.PROCOD) as codigoProduto,
		row_number() over(partition by rtrim(B.PROCOD) order by A.MVIDATEFE ) as qtd

	INTO #TRASFERENCIAESTOQUE FROM TBS037 A (NOLOCK)
		inner join TBS0371 B (nolock) on A.MVIEMPCOD = B.MVIEMPCOD AND A.MVIDOC = B.MVIDOC
	WHERE 
		A.MVIDATEFE BETWEEN @Data_De AND @Data_Ate AND
		A.MVILOCORI = @estoqueOrigem AND 
		A.MVILOCDES <> 0
	GROUP BY 
		A.MVIDOC, 
		B.PROCOD, 
		A.MVIDATEFE

	-- select * from #TrasferenciaEstoque

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		rtrim(A.PROCOD) as codigoProduto,
		rtrim(PRODES) as descricaoProduto,
		rtrim(PROLOCFIS) as localizacao,
		substring(PROLOCFIS,1,2) as rua,
		isnull(B.qtd,0) + isnull(C.qtd,0) as qtd
	FROM TBS010 A (NOLOCK) 
	LEFT JOIN (
		select 
		codigoProduto, 
		max(qtd) as qtd
	
		from #NOTASSAIDAVENDATRANSFERENCIA 
	
		group by 
		codigoProduto) as B on rtrim(A.PROCOD) = B.codigoProduto
	
	LEFT JOIN (
		select 
		codigoProduto, 
		max(qtd) as qtd
	
		from #TRASFERENCIAESTOQUE
	
		group by 
		codigoProduto) as C on rtrim(A.PROCOD) = C.codigoProduto
	
	WHERE 
		B.qtd <> 0 or C.qtd <> 0   
	ORDER BY 
		'qtd' desc
END