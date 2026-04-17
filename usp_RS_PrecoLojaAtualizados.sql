/*
====================================================================================================================================================================================
WREL048 - Preco de loja atualizados
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
20/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;		
====================================================================================================================================================================================
*/ 
CREATE PROCEDURE [dbo].[usp_RS_PrecoLojaAtualizados]
--ALTER PROCEDURE [dbo].[usp_RS_PrecoLojaAtualizados]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
	@produtoDe varchar(15),
	@produtoAte varchar(15),
	@codigomarca int,
	@nomemarca varchar(60),
	@somenteComSaldo varchar(10)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @empresaTBS031 smallint, @empresaTBS032 smallint, @LocalLoja smallint,
			@Data_De datetime, @Data_Ate datetime, @produto_De varchar(15), @produto_Ate varchar(15), @MARCOD int, @MARNOM varchar(60), @SoComSaldo varchar(10);

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'))
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()))
	SET @produto_De = @produtoDe;
	SET @produto_Ate = IIF(@produtoAte = '', 'Z', @produtoAte);
	SET @MARCOD = @codigomarca;
	SET @MARNOM = RTRIM(LTRIM(UPPER(@nomemarca)));
	SET @SoComSaldo = @somenteComSaldo;

	-- Obtem local de estoque da loja, via parametro
	SET @LocalLoja = Convert(int, (SELECT PARVAL FROM TBS025 (NOLOCK) WHERE PARCHV = 1134));
	-- Caso parametro nao definido, seta por padrao o local 2
	If @LocalLoja = 0
		set @LocalLoja = 2;

-- Verificar se a tabela é compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS031', @empresaTBS031 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS032', @empresaTBS032 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final: Preço de loja atualizados

	SELECT 
		RTRIM(A.MARNOM) + ' (' + LTRIM(STR(A.MARCOD,4)) + ')' as 'NomeECodigoDaMarca',
		RTRIM(TDPPROCOD) as 'CodigoDoProduto',
		RTRIM(A.PRODES) as 'DescricaoDoProduto',
		A.PROUM1 as 'UnidadeDeMedida1',
		case when TDPVALPROI <= GETDATE() AND GETDATE()<=TDPVALPROF AND TDPPROLOJ = 'S' 
			then TDPPREPRO1 
			else TDPPRELOJ1 
		end as 'Preco1',
		PROUM2 as 'UnidadeDeMedida2',
		case when TDPVALPROI <= GETDATE() AND GETDATE()<=TDPVALPROF AND TDPPROLOJ = 'S' 
			then TDPPREPRO2*PROUM2QTD 
			else TDPPRELOJ2*PROUM2QTD 
		end as 'Preco2',
		case when TDPDATATU < @Data_De
			then TDPVALPROF + 1
			else TDPDATATU 
		end as 'DataDaAtualizacao',

		case when TDPVALPROI >getdate() and TDPPROLOJ='S' 
			then convert(char(8),TDPVALPROI,3) 
			else ' ' 
		end AS 'Promoçao iniciará',
		case when TDPVALPROI<=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' 
			then convert(char(8),TDPVALPROI,3) 
			else ' ' 
		end as 'Promocao iniciou',
		case when TDPVALPROI<=getdate() and getdate()<=TDPVALPROF and TDPPROLOJ='S' 
			then convert(char(8),TDPVALPROF,3) 
			else ' ' 
		end as 'PromocaoValidaAte',
		case when TDPDATATU < @Data_De
			then 'Fim da Promoção'
			else 'Atualizado' 
		end as Obs,
		C.ESTQTDATU - C.ESTQTDRES as saldoDisponivel
	FROM TBS010 A (NOLOCK)
		INNER JOIN TBS031 B (NOLOCK) ON A.PROCOD = B.TDPPROCOD
		INNER JOIN TBS032 C (NOLOCK) ON A.PROCOD = C.PROCOD AND C.ESTLOC = @LOCALLOJA
	WHERE 
		A.PROEMPCOD = @empresaTBS010 AND
		B.TDPEMPCOD = @empresaTBS031 AND
		C.PROEMPCOD = @empresaTBS032 AND
		A.PROCOD BETWEEN @produto_De AND @produto_Ate AND
		A.MARCOD = (CASE WHEN @MARCOD = 0 THEN A.MARCOD ELSE @MARCOD END) AND	
		A.MARNOM LIKE (CASE WHEN @MARNOM = '' THEN A.MARNOM ELSE @MARNOM END) AND
		(CONVERT(CHAR(10),TDPDATATU,103) BETWEEN @Data_De AND @Data_Ate OR CONVERT(CHAR(10),TDPVALPROF + 1,103) BETWEEN @Data_De AND @Data_Ate) AND	
		C.ESTQTDATU - C.ESTQTDRES > @SoComSaldo
	ORDER BY 
		A.PROEMPCOD,
		B.TDPEMPCOD,
		C.PROEMPCOD,
		A.MARNOM,
		A.PRODES
END