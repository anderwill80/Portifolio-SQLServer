/*
====================================================================================================================================================================================
Script do Report Server					Cheques
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
10/06/2024	ANDERSON WILLIAM			- Permite a impressão dos cheques a receber

************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_Cheques(
--create proc [dbo].usp_RS_Cheques(
	@empcod smallint,
	@CheqNumDe int = 0,
	@CheqNumAte int = null,
	@DataEmiDe date	= null,
	@DataEmiAte date = null,
	@DataComPDe date = null,
	@DataComPAte date = null,
	@DataComEDe date = null,
	@DataComEAte date = null,
	@DataDepDe date	= null,
	@DataDepAte date = null,
	@DataDevDe date	= null,
	@DataDevAte date = null,
	@DataReaDe date	= null,
	@DataReaAte date = null,
	@cliente int = 0,
	@opcao varchar(100) = '',
	@motbai varchar(500) = '',
	@portador varchar(500) = ''
	)
as
begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS078 smallint,
			@empresa smallint, @CHQNUM_De int, @CHQNUM_Ate int, @CHQDATEMI_De date, @CHQDATEMI_Ate date,
			@CHQDATCOMP_De date, @CHQDATCOMP_Ate date, @CHQDATCOME_De date, @CHQDATCOME_Ate date, @CHQDATDEP_De date,
			@CHQDATDEP_Ate date,	@CHQDATDEV_De date,	@CHQDATDEV_Ate date, @CHQDATREA_De date,	@CHQDATREA_Ate date,
			@CLICOD int,
			@Opcoes varchar(100), @motivos varchar(500), @portadores varchar(500),
			@Query nvarchar (MAX), @ParmDef nvarchar (500)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @CHQNUM_De = @CheqNumDe
	SET @CHQNUM_Ate = (select isnull(@CheqNumAte, 999999))
	SET @CHQDATEMI_De = (select isnull(@DataEmiDe, '17530101'))
	SET @CHQDATEMI_Ate = (select isnull(@DataEmiAte, dateadd(year, 10, getdate())))
	SET @CHQDATCOMP_De = (select isnull(@DataComPDe, '17530101'))
	SET @CHQDATCOMP_Ate = (select isnull(@DataComPAte, dateadd(year, 10, getdate())))
	SET @CHQDATCOME_De = (select isnull(@DataComEDe, '17530101'))
	SET @CHQDATCOME_Ate = (select isnull(@DataComEAte, dateadd(year, 10, getdate())))
	SET @CHQDATDEP_De = (select isnull(@DataDepDe, '17530101'))
	SET @CHQDATDEP_Ate = (select isnull(@DataDepAte, dateadd(year, 10, getdate())))
	SET @CHQDATDEV_De = (select isnull(@DataDevDe, '17530101'))
	SET @CHQDATDEV_Ate = (select isnull(@DataDevAte, dateadd(year, 10, getdate())))
	SET @CHQDATREA_De = (select isnull(@DataReaDe, '17530101'))
	SET @CHQDATREA_Ate = (select isnull(@DataReaAte, dateadd(year, 10, getdate())))
	SET @CLICOD = @cliente
	SET @Opcoes = @opcao
	SET @motivos = @motbai
	SET @portadores = @portador

	-- Quebra os filtros Multi-valores em tabelas via função "Split", para facilitar a cláusula "IN()"

	-- Opções de compensação: COMPENSADO; A COMPENSAR
	If object_id('TempDB.dbo.#OPCOES') is not null
		DROP TABLE #OPCOES
    select elemento as [opcao]
	Into #OPCOES
    From fSplit(@Opcoes, ',')

	-- Motivos de baixa
	If object_id('TempDB.dbo.#MOTIVOS') is not null
		DROP TABLE #MOTIVOS
    select elemento as [motivo]
	Into #MOTIVOS
    From fSplit(@motivos, ',')

	-- Portadores
	If object_id('TempDB.dbo.#PORTADORES') is not null
		DROP TABLE #PORTADORES
    select elemento as [portador]
	Into #PORTADORES
    From fSplit(@portadores, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")

	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS078', @empresaTBS078 output; -- Cheques
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	If object_id('TempDB.dbo.#CHEQUES') is not null
		DROP TABLE #CHEQUES
		
	-- "SELECT TOP 0" para criar estrutura da tabela
	SELECT TOP 0
	CHQNUM,
	CHQVAL,
	CHQCONCOR,
	BCOAGE,
	BCONUM,
	CHQDATEMI,
	CHQDATDEP,
	CHQDATDEV,
	CHQDATREA,		
	CHQOBS,
	CHQDATCOMP,
	CHQDATCOME,	
	CLICOD,
	RTRIM(CHQCLINOM) AS CHQCLINOM,
	A.MOBCOD AS MOBCOD,
	ISNULL(MOBDES, '') AS MOBDES,
	PORCOD,
	CASE WHEN A.MOBCOD > 0
		THEN 'COMPENSADO'
		ELSE 'A COMPENSAR'
	END AS OPCAO
	
	INTO #CHEQUES

	FROM TBS078 A (NOLOCK)	
	LEFT JOIN TBS074 C (NOLOCK) ON C.MOBEMPCOD = A.MOBEMPCOD AND C.MOBCOD = A.MOBCOD
					  	
	WHERE 
	CHQEMPCOD = @empresaTBS078

	-- Monta a query dinâmica
	SET @Query	= N'
	INSERT INTO #CHEQUES

	SELECT
	CHQNUM,
	CHQVAL,
	CHQCONCOR,
	BCOAGE,
	BCONUM,
	CHQDATEMI,
	CHQDATDEP,
	CHQDATDEV,
	CHQDATREA,		
	CHQOBS,
	CHQDATCOMP,
	CHQDATCOME,	
	CLICOD,
	RTRIM(CHQCLINOM) AS CHQCLINOM,
	A.MOBCOD AS MOBCOD,
	ISNULL(MOBDES, '''') AS MOBDES,
	PORCOD,
	CASE WHEN A.MOBCOD > 0
		THEN ''COMPENSADO''
		ELSE ''A COMPENSAR''
	END AS OPCAO
	
	FROM TBS078 A (NOLOCK)	
	LEFT JOIN TBS074 C (NOLOCK) ON C.MOBEMPCOD = A.MOBEMPCOD AND C.MOBCOD = A.MOBCOD

	WHERE 
	CHQEMPCOD = @empresaTBS078
	AND CHQNUM BETWEEN @CHQNUM_De AND @CHQNUM_Ate
	AND CHQDATEMI BETWEEN @CHQDATEMI_De AND @CHQDATEMI_Ate
	AND CHQDATCOMP BETWEEN @CHQDATCOMP_De AND @CHQDATCOMP_Ate
	AND CHQDATCOME BETWEEN @CHQDATCOME_De AND @CHQDATCOME_Ate
	AND CHQDATDEP BETWEEN @CHQDATDEP_De AND @CHQDATDEP_Ate
	AND CHQDATDEV BETWEEN @CHQDATDEV_De AND @CHQDATDEV_Ate
	AND CHQDATREA BETWEEN @CHQDATREA_De AND @CHQDATREA_Ate
	AND A.MOBCOD IN (SELECT motivo from #MOTIVOS)
	AND PORCOD IN (SELECT portador from #PORTADORES)
	'
	+
	IIf (@CLICOD <= 0, '', ' AND CLICOD = @CLICOD')

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS078 smallint, @CHQNUM_De int, @CHQNUM_Ate int, @CHQDATEMI_De date, @CHQDATEMI_Ate date, @CHQDATCOMP_De date, @CHQDATCOMP_Ate date,
	@CHQDATCOME_De date, @CHQDATCOME_Ate date, @CHQDATDEP_De date, @CHQDATDEP_Ate date, @CHQDATDEV_De date, @CHQDATDEV_Ate date,
	@CHQDATREA_De date, @CHQDATREA_Ate date, @CLICOD int'

--	select @Query

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS078, @CHQNUM_De, @CHQNUM_Ate, @CHQDATEMI_De, @CHQDATEMI_Ate, @CHQDATCOMP_De, @CHQDATCOMP_Ate,
	@CHQDATCOME_De, @CHQDATCOME_Ate, @CHQDATDEP_De, @CHQDATDEP_Ate, @CHQDATDEV_De, @CHQDATDEV_Ate, @CHQDATREA_De, @CHQDATREA_Ate, @CLICOD
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT * FROM #CHEQUES
	WHERE
	OPCAO COLLATE DATABASE_DEFAULT IN (SELECT opcao from #OPCOES) 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End
