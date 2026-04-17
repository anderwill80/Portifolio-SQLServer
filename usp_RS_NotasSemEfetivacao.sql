/*
====================================================================================================================================================================================
WREL037 - Notas sem efetivacao
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
13/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";	
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_NotasSemEfetivacao]
--ALTER PROCEDURE [dbo].[usp_RS_NotasSemEfetivacao]
	@empcod smallint
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS059 smallint,
			@ParmDef nvarchar(500), @cmdSQL nvarchar(MAX);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;

-- Verificar se a tabela compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	select 
		'COM ITENS' AS TEM,
		B.NFENUM, 
		CASE WHEN B.NFETIP = 'N' 
			THEN 'NORMAL'
			ELSE 
				CASE WHEN B.NFETIP = 'T'
					THEN 'TRANSFERENCIA'
					ELSE 'DEVOLUCAO'
				END 
		END AS TIPO, 
		NFEDATEMI AS EMISSÃO,
		NFEDATENT AS ENTRADA, 
		'' AS EFETIVAÇÃO,
		COUNT(A.NFEITE) AS ITENS ,
		ISNULL(NFENFRTIP,'') AS NFENFRTIP

	FROM TBS0591 A (NOLOCK)
	LEFT JOIN TBS059 B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND 
	A.SERCOD = B.SERCOD AND  A.SEREMPCOD = B.SEREMPCOD 
	LEFT JOIN TBS0596 C (NOLOCK) ON A.NFEEMPCOD = C.NFEEMPCOD AND A.NFECOD = C.NFECOD AND A.NFENUM = C.NFENUM AND A.NFETIP = C.NFETIP AND
	A.SERCOD = C.SERCOD AND A.SEREMPCOD = C.SEREMPCOD

	WHERE
	A.NFEEMPCOD = @empresaTBS059 AND
	NFEDATEFE = '17530101' AND NFECAN = 'N' 

	GROUP BY 
	B.NFENUM, 
	B.NFETIP, 
	NFEDATEMI, 
	NFEDATENT, 
	NFEDATEFE,
	NFENFRTIP

	HAVING 
	COUNT(A.NFEITE) > 0

	UNION

	--- SEM ITENS NOTAS SEM EFETIVÇÃO
	select
		'SEM ITENS' AS TEM,
		B.NFENUM, 
		CASE WHEN B.NFETIP = 'N' 
			THEN 'NORMAL'
			ELSE 
				CASE WHEN B.NFETIP = 'T'
					THEN 'TRANSFERENCIA'
					ELSE 'DEVOLUCAO'
				END 
		END AS TIPO, 
		NFEDATEMI AS EMISSÃO,
		NFEDATENT AS ENTRADA, 
		'' AS EFETIVAÇÃO,
		COUNT(A.NFEITE) AS ITENS ,
		ISNULL(NFENFRTIP,'') AS NFENFRTIP

	FROM TBS059 B (NOLOCK)
	LEFT JOIN TBS0591 A  (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND 
	A.SERCOD = B.SERCOD AND  A.SEREMPCOD = B.SEREMPCOD 
	LEFT JOIN TBS0596 C (NOLOCK) ON B.NFEEMPCOD = C.NFEEMPCOD AND B.NFECOD = C.NFECOD AND B.NFENUM = C.NFENUM AND B.NFETIP = C.NFETIP AND
	B.SERCOD = C.SERCOD AND B.SEREMPCOD = C.SEREMPCOD

	WHERE
	B.NFEEMPCOD = @empresaTBS059 AND
	A.SERCOD IS NULL AND B.NFECAN = 'N' AND NFEDATEFE = '17530101'

	GROUP BY 
	B.NFENUM, 
	B.NFETIP, 
	NFEDATEMI, 
	NFEDATENT, 
	NFEDATEFE,
	NFENFRTIP
END