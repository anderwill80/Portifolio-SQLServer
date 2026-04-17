/*
====================================================================================================================================================================================
WREL046 - Preco atual dos produtos
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
20/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;		
************************************************************************************************************************************************************************************
*/ 
CREATE PROCEDURE [dbo].[usp_RS_PrecoAtualProdutos]
--ALTER PROCEDURE [dbo].[usp_RS_PrecoAtualProdutos]
	@empcod smallint,
	@produtoDe varchar(15),
	@produtoAte varchar(15),
	@codigomarca int,
	@nomemarca varchar(60),
	@descricaoproduto varchar(60)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @empresaTBS031 smallint,
			@produto_De varchar(15), @produto_Ate varchar(15), @MARCOD int, @MARNOM varchar(60), @PRODES varchar(60);

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @produto_De = @produtoDe;
	SET @produto_Ate = IIF(@produtoAte = '', 'Z', @produtoAte);
	SET @MARCOD = @codigomarca;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@nomemarca)));
	SET @PRODES = RTRIM(LTRIM(UPPER(@descricaoproduto)));

-- Verificar se a tabela é compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS031', @empresaTBS031 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		rtrim(MARNOM)+' ('+ case when len(MARCOD) = 4 then rtrim(MARCOD) else right(('00' + ltrim(str(MARCOD))),3)  end + ')' as 'NomeECodigoDaMarca',
		TDPPROCOD as 'CodigoDoProduto',
		PRODES as 'DescricaoDoProduto',
		PROUM1 as 'UnidadeDeMedida1',
		CASE WHEN TDPVALPROI <= GETDATE() AND GETDATE() <= TDPVALPROF AND TDPPROLOJ = 'S' THEN TDPPREPRO1 ELSE TDPPRELOJ1 END AS 'PRECO1',
		PROUM2 as 'UnidadeDeMedida2',
		CASE WHEN TDPVALPROI <= GETDATE() AND GETDATE() <= TDPVALPROF AND TDPPROLOJ = 'S' THEN TDPPREPRO2*PROUM2QTD ELSE TDPPRELOJ2*PROUM2QTD END AS 'PRECO2',
		TDPDATATU as 'DataDaAtualizacao',
		CONVERT(char(8),TDPVALPROI,3) AS 'Promoçao inicia',
		CASE WHEN TDPVALPROI <= GETDATE() AND GETDATE() <= TDPVALPROF AND TDPPROLOJ = 'S' THEN CONVERT(CHAR(8),TDPVALPROF,3) ELSE ' ' END AS 'PROMOCAOVALIDAATE'
	FROM TBS031 (NOLOCK)
		RIGHT JOIN TBS010 (NOLOCK) ON PROCOD = TDPPROCOD
	WHERE
		TBS010.PROEMPCOD = @empresaTBS010 AND
		TBS031.TDPEMPCOD = @empresaTBS031 AND		
		TDPPROCOD BETWEEN @produto_De AND @produto_Ate AND
		MARCOD = (CASE WHEN @MARCOD = 0 THEN MARCOD ELSE @MARCOD END) AND
		MARNOM LIKE (CASE WHEN @MARNOM = '' THEN MARNOM ELSE @MARNOM END) AND
		PRODES LIKE (CASE WHEN @PRODES = '' THEN PRODES ELSE @PRODES END)
	ORDER BY
		TDPPROCOD,
		PRODES
 END