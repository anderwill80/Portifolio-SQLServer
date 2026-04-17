/*
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
12/03/2025	WILLIAM
	- Alteracao do nome para "usp_Get_CodigosClientesGrupo";
	- Uso da funcao "ufn_Get_Parametro" para obter o valor do parametro 1453, que contem os CNPJS das empresas que fazem parte do grupo;
13/04/2024	WILLIAM
	- Inclusao do parametro de entrada @empcod, em vez de obter da tabela TBS023;
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela";
21/02/2024	WILLIAM
	- Alteracao do prefixo do nome de "sp_" para "usp_"
====================================================================================================================================================================================
*/
CREATE PROC [dbo].[usp_Get_CodigosClientesGrupo]
--ALTER PROC [dbo].[usp_Get_CodigosClientesGrupo]
	@empcod smallint
AS BEGIN 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SET NOCOUNT ON;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS002 smallint,
			@CNPJS varchar(254);

-- Variaveis dos parametros
	SET @codigoEmpresa = @empcod;
		
-- Obtem parametros		
	SET @CNPJS = LTRIM(RTRIM(dbo.ufn_Get_Parametro(1453)));

-- Uso da funcao fSplit() para "quebrar" os CNPJS e armazenar na tabela temporaria
	IF OBJECT_ID('tempdb..#MV_GRUPOBMPT') IS NOT NULL
		DROP TABLE #MV_GRUPOBMPT;

	SELECT 
		elemento as valor
	INTO #MV_GRUPOBMPT FROM fSplit(@CNPJS, ';');

	DELETE #MV_GRUPOBMPT
	WHERE valor = '';	-- Garante que nao contenha registros com valor = ''

-- Verificar se tabela compartilhada ou exclusiva	
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final, com os codigos dos clientes que sao empresas do grupo
		
	SELECT
		CLICOD 	
	FROM TBS002 (NOLOCK) 
	
	WHERE
		CLIEMPCOD = @empresaTBS002 AND
		CLICGC IN(SELECT valor FROM #MV_GRUPOBMPT)
	
	ORDER BY
		CLIEMPCOD,
		CLICGC
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
END



