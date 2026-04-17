/*
====================================================================================================================================================================================
Retorna itens em transito para a empresa que esta solicitando remotamente, atraves da entrada do CNPJ passado via parametro
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
09/04/2026 WILLIAM
	- Criacao	
====================================================================================================================================================================================
*/
CREATE PROC [dbo].[usp_Get_ItensEmTransito]
--ALTER PROC [dbo].[usp_Get_ItensEmTransito]
	@pCNPJ VARCHAR(30)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @CNPJ VARCHAR(30);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @CNPJ = @pCNPJ;		

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Retorna os itens em transito para a empresa que esta solicitando via CNPJ

	SELECT
		dataEmissao,
		chaveNota,
		tipoNota,
		codigoCliente,
		cnpj,
		empresa,
		codigoSerie,
		serie,
		numeroNota,
		codigoProduto,
		descricaoProduto,
		unidadeMedida,
		quantidade,
		valorTotalProduto,
		empresaEmitente,
		cnpjEmitente
	FROM SaidaItensEmTransito (NOLOCK)
	WHERE
		cnpj = @CNPJ
----------------------------------------------------------------------------------------------------------------------------------------------------------------
END