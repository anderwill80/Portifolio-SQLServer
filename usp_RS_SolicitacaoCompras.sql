/*
====================================================================================================================================================================================
Faturamento NFS X CUPOM
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
19/12/2024 - WILLIAM
- Inclusão do @empcod nos parâmetros de entrada da SP;
************************************************************************************************************************************************************************************
*/
create procedure [dbo].[usp_RS_SolicitacaoCompras] 
	@empcod smallint,
	@COD CHAR(15),
	@DESCRI CHAR(60),
	@Opcao int,
	@dataDe datetime,
	@dataAte datetime,
	@atendido CHAR(6),
	@solicitante char(50),
	@numsoli int
as
begin
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	if object_id('TempDB.dbo.#TBS010') is not null 
		drop table #TBS010;

	SELECT 
	PROCOD,
	PRODES,
	PROUM1

	INTO #TBS010
	FROM TBS010 A (NOLOCK)

	WHERE 
	PROCOD LIKE(CASE WHEN @COD = '' THEN PROCOD ELSE RTRIM(UPPER(@COD)) + '%' END) AND
	PRODES LIKE(CASE WHEN @DESCRI = '' THEN '% %' ELSE RTRIM(UPPER(@DESCRI)) + '%' END)

	ORDER BY 
	PROCOD

-------------------------------------------------------------------------------------------------------------------------------------------------------------

	if object_id('TempDB.dbo.#cdsaldo') is not null
	   drop table #cdsaldo;
   
	SELECT 
	PROCOD AS COD,
	SUM(ESTQTDATU-ESTQTDRES) AS EST

	INTO #cdsaldo
	FROM 
	cd.SIBD.dbo.TBS032 A (nolock) 

	WHERE 
	ESTLOC =1 AND 
	ESTQTDATU <> 0 AND 
	A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010)

	GROUP BY 
	PROCOD

---------------------------------------------------------------------------------------------------------------------------------------------------------------

	if object_id('TempDB.dbo.#ndsaldo') is not null
	   drop table #ndsaldo;

	SELECT 
	PROCOD AS COD,
	ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM TBS032 B (nolock) WHERE ESTLOC =1 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS EST,
	ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM TBS032 B (nolock) WHERE ESTLOC =2 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS LOJA	

	into #ndsaldo
	FROM 
	TBS032 A (nolock) 

	WHERE 
	ESTLOC IN (1,2) AND
	PROCOD IN (SELECT PROCOD FROM #TBS010)

	GROUP BY 
	PROCOD

---------------------------------------------------------------------------------------------------------------------------------------------------------------

	if object_id('TempDB.dbo.#SDC') is not null
	   drop table #SDC ;

	select 
	CASE WHEN SDCPEN = 'S' THEN 'NÃO' ELSE 'SIM' END AS ATENDIDO,
	CASE WHEN SDCPEN = 'N' THEN 0 ELSE DATEDIFF(DAY,SDCDATCAD,GETDATE()) END AS DIAS,
	E.CCSNOM AS SOLIC,
	A.SDCNUM AS NUMSOL,
	CONVERT(CHAR(10),SDCDATCAD,103) AS DATCAD,
	B.PROCOD AS COD,
	D.PRODES AS DESCRI,
	PROUM1 AS UN1,
	ISNULL(SALDO.EST,0) AS DISEST,
	ISNULL(F.EST,0) AS SALDOCD,
	ISNULL(SALDO.LOJA,0) AS DISLOJ,
	(SDCQTDPED-SDCQTDATD-SDCQTDRES)*SDCQTDEMB AS QTDRESTAN,
	SDCQTDATD*SDCQTDEMB AS QTDATD,
	SDCQTDPED*SDCQTDEMB AS QTDPED,
	SDCQTDRES*SDCQTDEMB AS RESI,
	SDCQTDBAI*SDCQTDEMB AS BAIXA,
	SDCOBS AS OBS

	INTO #SDC
	FROM TBS0761 B (NOLOCK) 
	LEFT JOIN TBS076 A (NOLOCK) ON A.SDCEMPCOD = B.SDCEMPCOD AND A.SDCNUM = B.SDCNUM
	LEFT JOIN #ndsaldo AS SALDO ON SALDO.COD = B.PROCOD
	LEFT JOIN #TBS010 D (NOLOCK) ON B.PROCOD = D.PROCOD
	LEFT JOIN TBS036 E (NOLOCK) ON A.CCSCOD = E.CCSCOD
	LEFT JOIN #cdsaldo F ON B.PROCOD COLLATE Latin1_General_CI_AS = F.COD
					    
	WHERE  --SDCPEN = 'S' -- ((SDCQTDPED-SDCQTDATD)*SDCQTDEMB)
	B.PROCOD IN (SELECT PROCOD FROM #TBS010) AND 
	SDCDATCAD BETWEEN @dataDe AND @dataAte AND
	SDCPEN = (CASE WHEN @atendido = 'TODOS' THEN SDCPEN ELSE @atendido END)	AND 
	E.CCSNOM LIKE(RTRIM(UPPER(@solicitante))+'%') AND 
	A.SDCNUM =(CASE WHEN @numsoli = 0 THEN A.SDCNUM ELSE @numsoli END)
	
	ORDER BY SDCDATCAD

	IF @Opcao = 1 -- TODOS 
	SELECT *
	FROM #SDC

	IF @Opcao = 2 -- PENDENTE MAS ESTÁ DISPONIVEL
	SELECT *
	FROM #SDC
	WHERE DISEST > 0 AND ATENDIDO = 'NÃO'

	IF @Opcao = 3 -- PENDENTE MAS A QUANTIDADE DSIPONIVEL É SUPERIOR
	SELECT *
	FROM #SDC
	WHERE DISEST > QTDRESTAN AND ATENDIDO = 'NÃO'

	IF @Opcao = 4 -- PENDENTE MAS TEM NO CD 
	SELECT *
	FROM #SDC
	WHERE SALDOCD > 0  AND ATENDIDO = 'NÃO'

	IF @Opcao = 5 -- PENDENTE MAS A QTD NO CD É SUPERIOR
	SELECT *
	FROM #SDC
	WHERE SALDOCD > QTDRESTAN AND ATENDIDO = 'NÃO'

	IF @Opcao = 6 -- PEDIDOS RESERVADOS, AINDA SEM BAIXA

	SELECT * 
	FROM #SDC
	WHERE ATENDIDO = 'SIM' AND BAIXA = 0 AND RESI = 0 	

	SELECT 
	ATENDIDO,
	DIAS,
	SOLIC,
	NUMSOL,
	DATCAD,
	COD,
	DESCRI,
	UN1,
	DISEST,
	SALDOCD,
	DISLOJ,
	QTDRESTAN,
	QTDATD,
	QTDPED,
	BAIXA,
	RESI,
	OBS
	FROM #SDC

END
GO


