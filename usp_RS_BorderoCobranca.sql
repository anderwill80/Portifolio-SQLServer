/*
====================================================================================================================================================================================
Script do Report Server					Contas a Receber
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
10/06/2024	ANDERSON WILLIAM			- Permite a impressão dos títulos a receber vinculados ao número do borderô passado via parâmetro

************************************************************************************************************************************************************************************
*/
--alter proc [dbo].usp_RS_BorderoCobranca(
create proc [dbo].usp_RS_BorderoCobranca(
	@empcod smallint,
	@bordero int,
	@msgcomple varchar(100)= ''
	)
as
begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS056 smallint, @empresaTBS063 smallint, @empresaTBS007 smallint,
			@empresa smallint, @CRENUMBOR int, @msgcpl varchar(100)= ''
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @CRENUMBOR = @bordero
	SET @msgcpl = @msgcomple
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")

	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS056', @empresaTBS056 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS063', @empresaTBS063 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS007', @empresaTBS007 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	If object_id('TempDB.dbo.#CONTAS_RECEBER') is not null
		DROP TABLE #CONTAS_RECEBER
		
	SELECT 
	CRENUMBOR,
	PFXCOD,
	CRETIT,
	CREPAR,	
	RTRIM(ISNULL(PORNOM, '')) AS PORNOM,
	CLICOD,
	RTRIM(A.CRECLINOM) AS CLIENTE,
	CREDATEMI,
	CREDATVENREA,
	CREDATBAI,
	CREVAL,
	dbo.CREVALJUR(CREEMPCOD, PFXEMPCOD, A.CLIEMPCOD, PFXCOD, CRETIT, CREPAR, A.CLICOD) as JUROS,
	CREVALRES AS RESIDUO,
	CREVALABT AS ABATIMENTO,
	CREVALACR AS ACRESCIMO,
	CREVALREC AS VALOR_REC,
	ISNULL(dbo.CREVALSDO(CREEMPCOD, PFXEMPCOD, A.CLIEMPCOD, PFXCOD, CRETIT, CREPAR, A.CLICOD), 0) as SALDO,
	RTRIM(C.BANNUMAGE) AS BANNUMAGE,
	RTRIM(C.BANNCC) AS BANNCC,
	RTRIM(BANEND) AS BANEND,
	RTRIM(BANBAI) AS BANBAI,
	RTRIM(BANCID) AS BANCID,
	RTRIM(UFESIG) AS UFESIG,

	RTRIM(@msgcpl) AS MSGCPL	
	
	INTO #CONTAS_RECEBER

	FROM TBS056 A (NOLOCK)
	JOIN TBS063 B (NOLOCK) ON B.POREMPCOD = A.POREMPCOD AND B.PORCOD = A.PORCOD
	JOIN TBS007 C (NOLOCK) ON C.BANEMPCOD = @empresaTBS007 AND BANPORCOD = A.PORCOD
					  	
	WHERE 
	CREEMPCOD = @empresaTBS056 AND
	A.POREMPCOD = @empresaTBS063 AND
	CRENUMBOR = @CRENUMBOR

	ORDER BY CREEMPCOD, PFXEMPCOD, CLIEMPCOD, CREDATVEN

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT * FROM #CONTAS_RECEBER
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End
