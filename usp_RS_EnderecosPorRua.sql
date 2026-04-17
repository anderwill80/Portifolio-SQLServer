/*
====================================================================================================================================================================================
WREL025 - Enderecos Por Rua
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
07/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Inclusão do filtro por empresa de tabela, usando a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_EnderecosPorRua]
	@empcod smallint,
	@Loc varchar(5)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @Rua varchar(5);

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Rua = @Loc;

	-- Verificar se a tabela compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	SELECT
	A.PROSTATUS AS ST, RTRIM(LTRIM(A.PROCOD)) AS CÓD,
	RTRIM(A.PRODES) AS DESCRIÇÃO, 
	CASE WHEN len(A.MARCOD) = 4 THEN rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) 
         ELSE RIGHT(('00' + ltrim(str(A.MARCOD))), 3) + ' - ' + rtrim(A.MARNOM) 
	END AS MARCA,
	A.PROLOCFIS AS 'LOC 1', A.PROLOCFIS2 AS 'LOC 2'

	FROM
	TBS010 AS A 
	INNER JOIN TBS032 AS B ON A.PROEMPCOD = B.PROEMPCOD AND A.PROCOD = B.PROCOD

	WHERE A.PROEMPCOD = @empresaTBS010 
	AND (A.PROLOCFIS LIKE(CASE WHEN @Rua = '' THEN A.PROLOCFIS ELSE RTRIM(UPPER(@Rua)) + '%'END) ) AND (B.ESTLOC = '1') AND (A.PROLOCFIS <> '')
	ORDER BY 'LOC 1'
END