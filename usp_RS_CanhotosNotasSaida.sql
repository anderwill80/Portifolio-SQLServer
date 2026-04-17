/*
======================================================================================================================================================
Script do Report Server					Canhotos de notas de saída
======================================================================================================================================================
										Histórico de alterações
======================================================================================================================================================
Data		Por							Descrição
**********	********************		**************************************************************************************************************
02/07/2024	ANDERSON WILLIAM			- Listagem de notas de saída de vendas, que foram marcadas ou não com canhoto pelo financeiro;

******************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_CanhotosNotasSaida(
--create proc [dbo].usp_RS_CanhotosNotasSaida(
	@empcod smallint,
	@tipo varchar(50),
	@finalidade varchar(50),
	@cancelada varchar(10),
	@comcanhoto char(10),
	@numeronfde int = 0,
	@numeronfate int = 0,
	@serie smallint = 0,
	@emissaonfde datetime = null,
	@emissaonfate datetime = null
	)
as
begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais

	DECLARE	@empresaTBS067 smallint, @Query nvarchar (MAX), @ParmDef nvarchar (500),
			@empresa smallint, @NFSTIP varchar(50), @NFSFINNFE varchar(50), @NFSCAN varchar(10), @NFSCANASS varchar(10), 
			@NFSNUM_DE int, @NFSNUM_ATE int, @SNESER smallint, @NFSDATEMI_DE datetime, @NFSDATEMI_ATE datetime
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @NFSTIP = @tipo
	SET @NFSFINNFE = @finalidade
	SET @NFSCAN = @cancelada
	SET @NFSCANASS = @comcanhoto
	SET @NFSNUM_DE = @numeronfde
	SET @NFSNUM_ATE = IIf(@numeronfate = 0, 999999, @numeronfate)
	SET @SNESER = @serie
	SET @NFSDATEMI_DE = (SELECT ISNULL(@emissaonfde, '17530101'))
	SET @NFSDATEMI_ATE = (SELECT ISNULL(@emissaonfate, GetDate()))

	-- Quebra os filtros Multi-valores em tabelas via função "Split", para facilitar a cláusula "IN()"

	-- Tipos:N,L,C,T
	If object_id('TempDB.dbo.#TIPOS') is not null
		DROP TABLE #TIPOS
    select elemento as [tipo]
	Into #TIPOS
    From fSplit(@NFSTIP, ',')

	-- Finalidades; 1;2;3;4
	If object_id('TempDB.dbo.#FINALIDADES') is not null
		DROP TABLE #FINALIDADES
    select elemento as [finali]
	Into #FINALIDADES
    From fSplit(@NFSFINNFE, ',')

	-- CANCELADO: SIM/NAO
	If object_id('TempDB.dbo.#CANCEL') is not null
		DROP TABLE #CANCEL
    select elemento as [cancel]
	Into #CANCEL
    From fSplit(@NFSCAN, ',')

	-- CANHOTO: SIM/NAO
	If object_id('TempDB.dbo.#CANHOTO') is not null
		DROP TABLE #CANHOTO
    select elemento as [canhoto]
	Into #CANHOTO
    From fSplit(@NFSCANASS, ',')

	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS067', @empresaTBS067 output;
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela de SITUAÇÕES da NF-e

	If object_id('TempDB.dbo.#SITUACOES') is not null
		DROP TABLE #SITUACOES
	
	CREATE TABLE #SITUACOES(SIT smallint, SITDES varchar(20))

	INSERT INTO #SITUACOES VALUES
		(1, 'EM DIGITACAO'),
		(2, 'DADOS VALIDOS'),
		(3, 'DADOS INVALIDOS'),
		(4, 'XML GERADO'),
		(5, 'XML ASSINADO'),
		(6, 'AUTORIZADA'),
		(7, 'CANCELADA'),
		(8, 'DENEGADA'),
		(9, 'PROCESSAMENTO SEFAZ'),
		(10, 'REJEITADA'),
		(11, 'INUTILIZADA'),
		(12, 'SERVICO PARALISADO'),
		(13, 'AUTORIZADA-EPEC'),
		(20, 'OUTRAS')

	-- select * from #SITUACOES
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela de SITUAÇÕES da NF-e

	If object_id('TempDB.dbo.#FINAL') is not null
		DROP TABLE #FINAL
	
	CREATE TABLE #FINAL(FIN smallint, FINDES varchar(20))

	INSERT INTO #FINAL VALUES
		(1, 'NORMAL'),
		(2, 'COMPLEMENTAR'),
		(3, 'AJUSTE'),
		(4, 'DEVOLUCAO')
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela de notas fiscais de saida

	If object_id('TempDB.dbo.#TBS067') is not null
		DROP TABLE #TBS067

	-- SELECT TOP 0 para criar estrutura
	SELECT TOP 0
	NFSDEV,
	ENFSIT,
	NFSTIP,
	NFSCANASS,
	NFSFINNFE,
	NFSCAN,
	NFSNUM,
	A.SNESER AS SNESER,
	NFSDATEMI,
	NFSCLICOD,
	NFSCLINOM,
	A.VENCOD,
	ISNULL(VENNOM, 'SEM VENDEDOR') AS [VENNOM],
	ENFVALTOT AS [TOTALNF],
	UFESIG

	INTO #TBS067

	FROM TBS067 AS A (NOLOCK)
	JOIN TBS080 AS B (NOLOCK) ON ENFEMPCOD = NFSEMPCOD AND ENFNUM = NFSNUM AND B.SNESER = A.SNESER
	LEFT JOIN TBS004 C (NOLOCK) ON C.VENEMPCOD = C.VENEMPCOD AND A.VENCOD = C.VENCOD

	WHERE 
	NFSEMPCOD = @empresaTBS067
	-------------------------------------------------

	Set @Query = N'
	INSERT INTO #TBS067

	SELECT
	NFSDEV,
	ENFSIT,
	NFSTIP,
	NFSCANASS,
	NFSFINNFE,
	NFSCAN,
	NFSNUM,
	A.SNESER AS SNESER,
	NFSDATEMI,
	NFSCLICOD,
	RTRIM(NFSCLINOM) AS NFSCLINOM,
	A.VENCOD,
	RTRIM(ISNULL(VENNOM, ''SEM VENDEDOR'')) AS VENNOM,
	ENFVALTOT AS TOTALNF,
	UFESIG

	FROM TBS067 AS A (NOLOCK)
	JOIN TBS080 AS B (NOLOCK) ON ENFEMPCOD = NFSEMPCOD AND ENFNUM = NFSNUM AND B.SNESER = A.SNESER
	LEFT JOIN TBS004 C (NOLOCK) ON C.VENEMPCOD = C.VENEMPCOD AND A.VENCOD = C.VENCOD

	WHERE 
	NFSEMPCOD = @empresaTBS067 AND
	NFSTIP IN(SELECT tipo FROM #TIPOS) AND
	NFSFINNFE IN(SELECT finali FROM #FINALIDADES) AND
	NFSCAN IN(SELECT cancel FROM #CANCEL) AND
	NFSCANASS IN(SELECT canhoto FROM #CANHOTO) AND
	NFSDATEMI BETWEEN @NFSDATEMI_DE AND @NFSDATEMI_ATE AND
	NFSNUM BETWEEN @NFSNUM_DE AND @NFSNUM_ATE
	'
	+
	IIF(@SNESER <= 0, '', ' AND A.SNESER = @SNESER')
	+
	' ORDER BY NFSEMPCOD, A.SNEEMPCOD, NFSNUM'

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS067 smallint, @NFSDATEMI_DE datetime, @NFSDATEMI_ATE datetime, @NFSNUM_DE int, @NFSNUM_ATE int, @SNESER smallint'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS067, @NFSDATEMI_DE, @NFSDATEMI_ATE, @NFSNUM_DE, @NFSNUM_ATE, @SNESER

--	SELECT * FROM #TBS067
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final usando "CTE" With...AS

	;WITH NotasCanhoto
	AS
	(
		SELECT
		(SELECT SITDES FROM #SITUACOES WHERE SIT = ENFSIT) AS [SITUACAO],
		(SELECT FINDES FROM #FINAL WHERE FIN = NFSFINNFE) AS [FINALIDADE],
		*		
		FROM #TBS067
	)

	SELECT * FROM NotasCanhoto	
End