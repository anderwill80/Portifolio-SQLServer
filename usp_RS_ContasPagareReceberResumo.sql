/*
====================================================================================================================================================================================
WREL014 - Contas a pagar e a receber - Resumo
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
21/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Uso da SP "usp_ClientesGrupo" e "usp_FornecedoresGrupo";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_ContasPagareReceberResumo]
--ALTER PROCEDURE [dbo].[usp_RS_ContasPagareReceberResumo]
	@empcod smallint
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint;
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Codigos dos clientes do grupo

	IF OBJECT_ID('TEMPDB.DBO.#GRUPOCLI') IS NOT NULL
		DROP TABLE #GRUPOCLI;

	CREATE TABLE #GRUPOCLI (CLICOD INT)

	INSERT INTO #GRUPOCLI
	EXEC usp_ClientesGrupo @codigoEmpresa

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Codigos dos fornecedores do grupo 

	IF OBJECT_ID('TEMPDB.DBO.#GRUPOFOR') IS NOT NULL
		DROP TABLE #GRUPOFOR;

	CREATE TABLE #GRUPOFOR (FORCOD INT)
	
	INSERT INTO #GRUPOFOR
	EXEC usp_FornecedoresGrupo @codigoempresa

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- todos pedidos de vendas em aberto
	if object_id('tempdb.dbo.#ventt') is not null
	   begin
		  drop table #ventt
	   end


	if object_id('tempdb.dbo.#ven') is not null
	   begin
		  drop table #ven
	   end

	select distinct PRPNUM, sum(PRPQTD*PRPPRELIQ) AS VALOR , PRPCLICOD  INTO #ven from TBS058 (NOLOCK) GROUP BY PRPNUM, PRPCLICOD

	-- fora o grupo
	;WITH ven as (
	select sum(VALOR) as venval, count (*) as venqtd from #ven where PRPCLICOD not in (select CLICOD from #GRUPOCLI)),

	-- do grupo
	venBMPT as (
	select sum(VALOR) as venval, count (*) as venqtd from #ven where PRPCLICOD in (select CLICOD from #GRUPOCLI))

	select 'Outras Empresas' as grupo ,* into #ventt from ven
	union 
	select 'Empresas do Grupo' as grupo, * from venBMPT

	--------------------------------------------------------------------------------------------------------------------------------------------------

	-- pedidos de compras em aberto
	if object_id('tempdb.dbo.#pdctt') is not null
	   begin
		  drop table #pdctt
	   end

	if object_id('tempdb.dbo.#pdc') is not null
	   begin
		  drop table #pdc
	   end

	select PDCEMPCOD,PDCNUM, FORCOD
	   into #pdc
	   from TBS045 (nolock)
	 where PDCDATCAD > getdate()-180 
	ORDER BY PDCDATCAD, FORCOD 

	-- PDC do grupo em aberto
	;with pdcBMPT as (
	SELECT  SUM(ROUND(dbo.PDCTOTBRU(PDCEMPCOD,PDCNUM),2) - (ROUND(dbo.PDCTOTENT(PDCEMPCOD,PDCNUM),2) + ROUND(dbo.PDCTOTRES(PDCEMPCOD,PDCNUM),2)))  AS pdcval,
	COUNT(PDCNUM) AS pdcqtd
	FROM #pdc
	WHERE 
	ROUND(dbo.PDCTOTBRU(PDCEMPCOD,PDCNUM),2) - (ROUND(dbo.PDCTOTENT(PDCEMPCOD,PDCNUM),2) + ROUND(dbo.PDCTOTRES(PDCEMPCOD,PDCNUM),2)) > 1 AND
	FORCOD IN ( SELECT FORCOD FROM #GRUPOFOR) ),

	-- PDC do fora grupo em aberto
	pdc as (
	SELECT  SUM(ROUND(dbo.PDCTOTBRU(PDCEMPCOD,PDCNUM),2) - (ROUND(dbo.PDCTOTENT(PDCEMPCOD,PDCNUM),2) + ROUND(dbo.PDCTOTRES(PDCEMPCOD,PDCNUM),2)))  AS pdcval,
	COUNT(PDCNUM) AS pdcqtd
	FROM #pdc
	WHERE 
	ROUND(dbo.PDCTOTBRU(PDCEMPCOD,PDCNUM),2) - (ROUND(dbo.PDCTOTENT(PDCEMPCOD,PDCNUM),2) + ROUND(dbo.PDCTOTRES(PDCEMPCOD,PDCNUM),2)) > 1 AND
	FORCOD not in (SELECT FORCOD FROM #GRUPOFOR))
 
	select 'Outras Empresas' as grupo ,* into #pdctt from pdc
	union 
	select 'Empresas do Grupo' as grupo, * from pdcBMPT


	-------------------------------------------------------------------------------------------------------------------------------------------------------

	-- contas a pagar e a receber 

	if object_id('tempdb.dbo.#APAGAR') is not null
	   begin
		  drop table #APAGAR
	   end 
   
	if object_id('tempdb.dbo.#ARECEBER') is not null
	   begin
		  drop table #ARECEBER
	   end 

	-- a pagar 
	-- valor títulos contas a pagar com vencimento neste dia

	-- fora grupo
	;with vencehj as (
	select isnull(sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1,0) as apghoj,
		   count(*) as titapghoj
	  from TBS057 (nolock) where CPADATVENREA=convert(date,getdate()) and FORCOD not in(select FORCOD from #GRUPOFOR)),

	-- do grupo
	vencehjBMPT as ( 
	select isnull(sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1,0) as apghoj,
		   count(*) as titapghoj
	  from TBS057 (nolock) where CPADATVENREA=convert(date,getdate()) and FORCOD in(select FORCOD from #GRUPOFOR)),

	-- valor títulos contas a pagar que foram pagos neste dia

	-- fora grupo

	pagohj as (
	select isnull(sum(CPAVALPAG)*-1,0) as pgohoj,
		   count(*) as titpgohoj
	  from TBS057 (nolock) where CPADATBAI=convert(date,getdate()) and CPAVALPAG > 0 and FORCOD not in(select FORCOD from #GRUPOFOR)),

	-- do grupo
	pagohjBMPT As (
	select isnull(sum(CPAVALPAG)*-1,0) as pgohoj,
		   count(*) as titpgohoj
	  from TBS057 (nolock) where CPADATBAI=convert(date,getdate()) and CPAVALPAG > 0 and FORCOD in(select FORCOD from #GRUPOFOR)),

	-- atrasadas

	-- fora grupo
	atrassa as (
	select isnull(sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1,0) as apgven,
		   count(*) as titapgven
	  from TBS057 (nolock)
	 where CPADATBAI='17530101' and dbo.CPADIAATR(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD) > 0 and FORCOD not in(select FORCOD from #GRUPOFOR)),

	-- do grupo

	atrassaBMPT as (
	select isnull(sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1,0) as apgven,
		   count(*) as titapgven
	  from TBS057 (nolock)
	 where CPADATBAI='17530101' and dbo.CPADIAATR(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD) > 0 and FORCOD in(select FORCOD from #GRUPOFOR)), 
 
	-- geral a pagar

	-- fora grupo
	apagargeral as (
	select isnull(sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1,0) as apgsom,
		   count(*) as titapgsom
	  from TBS057 (nolock)
	 where CPADATBAI='17530101'  and FORCOD not in(select FORCOD from #GRUPOFOR)),

	-- do grupo

	apagargeralBMPT as (
	select isnull(sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1,0) as apgsom,
		   count(*) as titapgsom
	  from TBS057 (nolock)
	 where CPADATBAI='17530101' and FORCOD in(select FORCOD from #GRUPOFOR)) 
 
	SELECT 'Outras Empresas' as grupo,* into #APAGAR FROM vencehj,pagohj,atrassa,apagargeral
	union
	select 'Empresas do Grupo' as grupo,* from vencehjBMPT,pagohjBMPT,atrassaBMPT,apagargeralBMPT


  
	----------------------------------------------------------------------------------------------------------------------------------------------------------------

 
	-- contas a receber

	-- valor títulos contas a receber com vencimento neste dia

	-- fora grupo
   
	;with rechj as (
	select isnull(sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)),0) as archoj,
		   count(*) as titarchoj
	  from TBS056 (nolock) where CREDATVENREA=convert(date,getdate()) and CLICOD not in(select CLICOD from #GRUPOCLI)),

	-- do grupo
	rechjBMPT as (
	select isnull(sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)),0) as archoj,
		   count(*) as titarchoj
	  from TBS056 (nolock) where CREDATVENREA=convert(date,getdate()) and CLICOD in(select CLICOD from #GRUPOCLI)),

	-- valor títulos contas a receber que foram recebidos neste dia

	-- fora grupo
	recebihj as (
	select isnull(sum(CREVALREC),0) as rcbhoj,
		   count(*) as titrcbhoj
	  from TBS056 (nolock) where CREDATBAI=convert(date,getdate()) and CREVALREC > 0 and CLICOD not in(select CLICOD from #GRUPOCLI)),

	-- do grupo
	recebihjBMPT as (
	select isnull(sum(CREVALREC),0) as rcbhoj,
		   count(*) as titrcbhoj
	  from TBS056 (nolock) where CREDATBAI=convert(date,getdate()) and CREVALREC > 0 and CLICOD in(select CLICOD from #GRUPOCLI)),

	-- atrasadas

	-- fora grupo
	areceber as (
	select isnull(sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)),0) as arcven,
		   count(*) as titarcven
	  from TBS056 (nolock)
	 where CREDATBAI='17530101' and dbo.CREDIAATR(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD) > 0 and CLICOD not in(select CLICOD from #GRUPOCLI)),

	-- do grupo
	areceberBMPT as (
	select isnull(sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)),0) as arcven,
		   count(*) as titarcven
	  from TBS056 (nolock)
	 where CREDATBAI='17530101' and dbo.CREDIAATR(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD) > 0 and CLICOD in(select CLICOD from #GRUPOCLI)),
 
 
	 --- geral a receber
	 -- fora do grupo
	 geralareceber as (
	select isnull(sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)),0) as arcsom,
		   count(*) as titarcsom
	  from TBS056 (nolock)
	 where CREDATBAI='17530101' and CLICOD not in(select CLICOD from #GRUPOCLI)),

	-- do grupo
	geralareceberBMPT as (
	select isnull(sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)),0) as arcsom,
		   count(*) as titarcsom
	  from TBS056 (nolock)
	 where CREDATBAI='17530101' and CLICOD in(select CLICOD from #GRUPOCLI))
 
 
	 SELECT 'Outras Empresas' as grupo,* into #ARECEBER FROM rechj,recebihj,areceber,geralareceber
	union
	select 'Empresas do Grupo' as grupo,* from rechjBMPT,recebihjBMPT,areceberBMPT,geralareceberBMPT
 
 
	;with areceber as ( 
	select 
	grupo, 
	archoj,
	SUM(archoj) OVER (PARTITION BY 1) as ttarchoj,
	case when sum(archoj) over (partition by 1) = 0 
		then 0
		else round(archoj / sum(archoj) over (partition by 1)*100,3)
	end as 'porttarchoj',
	titarchoj, 
	rcbhoj,
	sum(rcbhoj) over (partition by 1) as ttrcbhoj,
	case when sum(rcbhoj) over (partition by 1) = 0
		then 0
		else round(rcbhoj / sum(rcbhoj) over (partition by 1)*100,3)
	end as 'porttrcbhoj',
	titrcbhoj, 
	arcven, 
	sum(arcven) over (partition by 1) as ttarcven,
	case when sum(arcven) over (partition by 1) = 0 
		then 0
		else round(arcven / sum(arcven) over (partition by 1) *100,3) 
	end as 'porttarcven',
	titarcven, 
	arcsom , 
	sum(arcsom) over (partition by 1 ) as 'ttarcsom',
	case when sum(arcsom) over (partition by 1 ) = 0 
		then 0
		else round(arcsom / sum(arcsom) over (partition by 1 )*100,3) 
	end as 'porttarcsom',
	titarcsom 
	from #ARECEBER),


	apagar as ( 
	select 
	grupo, 
	apghoj,
	SUM(apghoj) OVER (PARTITION BY 1) as ttapghoj,
	case when sum(apghoj) over (partition by 1) = 0 
		then 0
		else round(apghoj / sum(apghoj) over (partition by 1)*100,3)
	end as 'porttapghoj',
	titapghoj, 
	pgohoj,
	sum(pgohoj) over (partition by 1) as ttpgohoj,
	case when sum(pgohoj) over (partition by 1) = 0
		then 0
		else round(pgohoj / sum(pgohoj) over (partition by 1)*100,3)
	end as 'porttpgohoj',
	titpgohoj, 
	apgven, 
	sum(apgven) over (partition by 1) as ttapgven,
	case when sum(apgven) over (partition by 1) = 0 
		then 0
		else round(apgven / sum(apgven) over (partition by 1) *100,3) 
	end as 'porttapgven',
	titapgven, 
	apgsom , 
	sum(apgsom) over (partition by 1 ) as 'ttapgsom',
	case when sum(apgsom) over (partition by 1 ) = 0 
		then 0
		else round(apgsom / sum(apgsom) over (partition by 1 )*100,3) 
	end as 'porttapgsom',
	titapgsom 
	from #APAGAR),

	pdc as (
	select grupo, 
	pdcval ,
	sum(pdcval) over (partition by 1) as pdcsom ,
	case when sum(pdcval) over (partition by 1 ) = 0 
		then 0
		else round(pdcval / sum(pdcval) over (partition by 1 )*100,3) 
	end as 'porttpdcval',
	pdcqtd 
	from #pdctt ),

	ven as ( 
	select grupo, 
	venval ,
	sum(venval) over (partition by 1) as vensom ,
	case when sum(venval) over (partition by 1 ) = 0 
		then 0
		else round(venval / sum(venval) over (partition by 1 )*100,3) 
	end as 'porttvenval',
	venqtd 
	from #ventt)

	select 
	p.grupo as grupo,
	archoj,
	porttarchoj,
	titarchoj,
	rcbhoj,	
	porttrcbhoj,
	titrcbhoj,
	arcven,
	porttarcven,
	titarcven,
	arcsom,
	porttarcsom,
	titarcsom,
	apghoj,
	porttapghoj,
	titapghoj,
	pgohoj,
	porttpgohoj,
	titpgohoj,
	apgven,
	porttapgven,
	titapgven,
	apgsom,
	porttapgsom,
	titapgsom,
	pdcval,
	porttpdcval,
	pdcqtd,
	venval,
	porttvenval,
	venqtd

	from areceber r 
	left join apagar p on p.grupo = r.grupo
	left join pdc c on p.grupo = c.grupo
	left join ven v on p.grupo = v.grupo
END