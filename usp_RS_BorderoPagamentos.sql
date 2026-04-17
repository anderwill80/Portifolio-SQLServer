/*
====================================================================================================================================================================================
Script do Report Server					Contas a Pagar
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
12/06/2024	ANDERSON WILLIAM			- Inclusão do "LEFT" nos joins TBS063 e TBS007;

07/06/2024	ANDERSON WILLIAM			- Permite a impressão dos títulos a pagar vinculados ao número do borderô passado via parâmetro;

************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_BorderoPagamentos(
--create proc [dbo].usp_RS_BorderoPagamentos(
	@empcod smallint,
	@bordero int,
	@msgcomple varchar(100)= ''
	)
as
begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS057 smallint, @empresaTBS063 smallint, @empresaTBS007 smallint,
			@empresa smallint, @CPANUMBOR int, @msgcpl varchar(100)= ''
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @CPANUMBOR = @bordero
	SET @msgcpl = @msgcomple
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")

	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS057', @empresaTBS057 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS063', @empresaTBS063 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS007', @empresaTBS007 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	If object_id('TempDB.dbo.#CONTAS_PAGAR') is not null
		DROP TABLE #CONTAS_PAGAR
		
	SELECT 
	CPANUMBOR,
	PFXCOD,
	CPATIT,
	CPAPAR,	
	RTRIM(ISNULL(PORNOM, '')) AS PORNOM,
	FORCOD,
	RTRIM(A.CPAFORNOM) AS FORNECEDOR,
	CPADATEMI,
	CPADATVENREA,
	CPADATBAI,
	CPAVAL,
	CPAVALRES AS RESIDUO,
	CPAVALABT AS ABATIMENTO,
	CPAVALACR AS ACRESCIMO,
	CPAVALPAG AS VALOR_PAGO,
	dbo.CPAVALSDO(CPAEMPCOD,PFXEMPCOD,A.FOREMPCOD,PFXCOD,CPATIT,CPAPAR,A.FORCOD) as SALDO,
	RTRIM(BANNUMAGE) AS BANNUMAGE,
	RTRIM(BANNCC) AS BANNCC,
	RTRIM(BANEND) AS BANEND,
	RTRIM(BANBAI) AS BANBAI,
	RTRIM(BANCID) AS BANCID,
	RTRIM(UFESIG) AS UFESIG,

	RTRIM(@msgcpl) AS MSGCPL,
	dbo.ufn_NumeroPorExtenso(dbo.CPAVALSDO(CPAEMPCOD,PFXEMPCOD,A.FOREMPCOD,PFXCOD,CPATIT,CPAPAR,A.FORCOD), 1) AS SALDOEXTENSO
	
	INTO #CONTAS_PAGAR

	FROM TBS057 A (NOLOCK)
	LEFT JOIN TBS063 B (NOLOCK) ON B.POREMPCOD = A.POREMPCOD AND B.PORCOD = A.PORCOD
	LEFT JOIN TBS007 C (NOLOCK) ON BANEMPCOD = @empresaTBS007 AND BANPORCOD = A.PORCOD
					  	
	WHERE 
	CPAEMPCOD = @empresaTBS057 AND
	A.POREMPCOD = @empresaTBS063 AND
	CPANUMBOR = @CPANUMBOR

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT * FROM #CONTAS_PAGAR
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End
