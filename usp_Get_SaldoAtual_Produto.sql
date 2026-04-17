/*
====================================================================================================================================================================================
Retorna saldo disponivel do estoque 1 e 2(corp e loja), acumulado de compras e em transito do produto;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
11/04/2026 WILLIAM
	- Criacao 
====================================================================================================================================================================================
*/
CREATE PROC [dbo].[usp_Get_SaldoAtual_Produto]
--ALTER PROC [dbo].[usp_Get_SaldoAtual_Produto]
	@pEmpCod smallint,
	@pPROCOD varchar(20),

	@pEstoque decimal(12,6) OUTPUT, 
	@pLoja decimal(12,6) OUTPUT, 
	@pCompras decimal(12,6) OUTPUT, 
	@pTransito decimal(12,6) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS032 SMALLINT;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod;		

-- Verificar se a tabela e compartilhada ou exclusiva			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS032', @empresaTBS032 output;

	-- Obtem os saldos do estoque 1, estoque 2, compras e em transito do produto
	SELECT
		@pEstoque = ISNULL((SELECT TOP 1 ESTQTDATU - ESTQTDRES FROM TBS032 WHERE PROEMPCOD = @empresaTBS032 AND ESTLOC = 1 AND PROCOD = @pPROCOD ORDER BY PROEMPCOD, PROCOD ), 0),
		@pLoja = ISNULL((SELECT TOP 1 ESTQTDATU - ESTQTDRES FROM TBS032 WHERE PROEMPCOD = @empresaTBS032 AND ESTLOC = 2 AND PROCOD = @pPROCOD ORDER BY PROEMPCOD, PROCOD ), 0),
		@pCompras = ISNULL((SELECT TOP 1 SUM(ESTQTDCMP) FROM TBS032 WHERE PROEMPCOD = @empresaTBS032 AND PROCOD = @pPROCOD GROUP BY PROEMPCOD, PROCOD ORDER BY PROEMPCOD, PROCOD ), 0),
		@pTransito = ISNULL((SELECT NFSQTD FROM ItensEmTransito WHERE PROCOD = @pPROCOD), 0)
----------------------------------------------------------------------------------------------------------------------------------------------------------------
END