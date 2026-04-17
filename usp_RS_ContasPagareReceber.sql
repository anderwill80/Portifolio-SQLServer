/*
====================================================================================================================================================================================
WREL014 - Contas a pagar e a receber
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
21/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Uso da SP "usp_ClientesGrupo" e "usp_FornecedoresGrupo";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_ContasPagareReceber]
--ALTER PROCEDURE [dbo].[usp_RS_ContasPagareReceber]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint,
			@data_De datetime, @data_Ate datetime ;
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));

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
	-- receber

	-- fora grupo

	;with 
	TAB1 as (
		SELECT 
			convert(date,CREDATVENREA) as data,
			count(*) as titrec,
			sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)) as previsto,
			sum(CREVALREC) as efetivo,
			avg(dbo.CREDIAATR(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)) as atraso
		FROM TBS056 (NOLOCK)

		WHERE 
			CREDATVENREA BETWEEN @data_De AND @data_Ate AND
			CLICOD NOT IN(SELECT CLICOD FROM #GRUPOCLI)
		 GROUP BY 
			CREDATVENREA
		 ),
	-- com grupo 
	TAB4 as (
		SELECT 
			convert(date,CREDATVENREA) as data,
			count(*) as titrecBMPT,
			sum(dbo.CREVALSDO(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)) as previsto,
			sum(CREVALREC) as efetivo,
			avg(dbo.CREDIAATR(0,0,0,PFXCOD,CRETIT,CREPAR,CLICOD)) as atraso
		FROM TBS056 (NOLOCK)
		
		WHERE 
			CREDATVENREA BETWEEN @data_De AND @data_Ate AND
			CLICOD IN (SELECT CLICOD FROM #GRUPOCLI)
		GROUP BY 
			CREDATVENREA
		),
	-- pagar
	-- fora grupo
	TAB2 as (
		SELECT 
			convert(date,CPADATVENREA) as data,
			count(*) as titpag,
			sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1 as previsto,
			sum(CPAVALPAG)*-1 as efetivo,
			avg(dbo.CPADIAATR(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD)) as atraso
		FROM TBS057 (NOLOCK)
		WHERE
			CPADATVENREA BETWEEN @data_De AND @data_Ate AND
			FORCOD NOT IN(SELECT FORCOD FROM #GRUPOFOR)
		GROUP BY
			CPADATVENREA
		),
	-- com grupo
	TAB5 as (
		SELECT 
			convert(date,CPADATVENREA) as data,
			count(*) as titpagBMPT,
			sum(dbo.CPAVALSDO(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD))*-1 as previsto,
			sum(CPAVALPAG)*-1 as efetivo,
			avg(dbo.CPADIAATR(0,0,0,PFXCOD,CPATIT,CPAPAR,FORCOD)) as atraso
		FROM TBS057 (NOLOCK)
		WHERE
			CPADATVENREA BETWEEN @data_De AND @data_Ate AND
			FORCOD IN(SELECT FORCOD FROM #GRUPOFOR)
		GROUP BY 
			CPADATVENREA
		),
	-- receber
	TAB3 as (
		SELECT 
			grupo='Outros Empresas',
			case when A.data is not null then A.data else B.data end as data,
			case when year(A.data) is not null then year(A.data) else year(B.data) end as ano,
			case when month(A.data) is not null then month(A.data) else month(B.data) end as mes,
			case when day(A.data) is not null then day(A.data) else day(B.data) end as dia,
			isnull(titpag,0) as titpag,
			isnull(titrec,0) as titrec,
			isnull(B.efetivo,0) as contasPagas,
			isnull(A.efetivo,0) as contasRecebidas,
			isnull(B.previsto,0) as contasAPagar,
			isnull(B.atraso,0) as atrasoPagar,
			isnull(A.previsto,0) as contasAReceber,
			isnull(A.atraso,0) as atrasoReceber,
			isnull(A.efetivo,0)+isnull(B.efetivo,0) as saldoEfetivo,
			isnull(A.efetivo,0)+isnull(A.previsto,0)+isnull(B.efetivo,0)+isnull(B.previsto,0) as saldoPrevisto
		FROM TAB1 AS A
			FULL JOIN TAB2 as B on B.data=A.data
		),
	-- pagar
	TAB6 as (
		SELECT
			grupo='Empresas do Grupo',
			case when A.data is not null then A.data else B.data end as data,
			case when year(A.data) is not null then year(A.data) else year(B.data) end as ano,
			case when month(A.data) is not null then month(A.data) else month(B.data) end as mes,
			case when day(A.data) is not null then day(A.data) else day(B.data) end as dia,
			isnull(titpagBMPT,0) as titpag,
			isnull(titrecBMPT,0) as titrec,
			isnull(B.efetivo,0) as contasPagas,
			isnull(A.efetivo,0) as contasRecebidas,
			isnull(B.previsto,0) as contasAPagar,
			isnull(B.atraso,0) as atrasoPagar,
			isnull(A.previsto,0) as contasAReceber,
			isnull(A.atraso,0) as atrasoReceber,
			isnull(A.efetivo,0)+isnull(B.efetivo,0) as saldoEfetivo,
			isnull(A.efetivo,0)+isnull(A.previsto,0)+isnull(B.efetivo,0)+isnull(B.previsto,0) as saldoPrevisto
		FROM TAB4 AS A
		FULL JOIN TAB5 AS B ON B.data = A.data
		)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		* 
	FROM TAB3 	

	UNION
	SELECT 
		*
	FROM TAB6
END