/*
====================================================================================================================================================================================
														Hist�rico de altera��es
====================================================================================================================================================================================
Data		Por							Descri��o
**********	********************		********************************************************************************************************************************************
04/11/2024	ANDERSON WILLIAM			- Inclusão do nome da marca do produto;

05/06/2024	ANDERSON WILLIAM			- Cria��o da consulta para o ReportServer via stored procedure, para facilitar a manuten��o e implanta��o nos BD das empresas
							
************************************************************************************************************************************************************************************
*/
--CREATE PROC [dbo].[usp_RS_ListaEscolar](
ALTER PROC [dbo].[usp_RS_ListaEscolar](
	@empcod int,
	@lista int
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Declara��es das variaveis locais

	declare	@empresaTBS151 smallint, @empresaTBS002 smallint, @empresaTBS150 smallint, @empresaTBS010 smallint,
			@empresa smallint, @LIENUM int, 
			@PARVAL varchar(254), @MsgRodape varchar(254), @DiasValidade smallint, @Validade date, @EMPWHATSAPP varchar(15)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Atribui��es para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @LIENUM = @lista
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Verificar se a tabela � compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")

	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS010', @empresaTBS010 output;	
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS150', @empresaTBS150 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS151', @empresaTBS151 output;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Par�metros:

	-- Obt�m mensagem para mostrar no rodap� da p�gina
	SET @MsgRodape = (SELECT RTRIM(ISNULL(PARVAL, '')) FROM TBS025 (NOLOCK) WHERE PARCHV = 1483)

	-- Dias para a data de validade da lista
	SET @DiasValidade = convert(int, (SELECT RTRIM(ISNULL(PARVAL, '')) FROM TBS025 (NOLOCK) WHERE PARCHV = 1485))
	SET @Validade = DateADD(DD, @DiasValidade, CONVERT(date, GETDATE()))

	-- WhatsAPP do par�metro ou cadastrado na empresa
	SET @EMPWHATSAPP = (SELECT RTRIM(ISNULL(PARVAL, '')) FROM TBS025 (NOLOCK) WHERE PARCHV = 1493)
	If @EMPWHATSAPP = ''
		SET @EMPWHATSAPP = (SELECT RTRIM(ISNULL(EMPWHATSAPP, '')) FROM TBS023 (NOLOCK) WHERE EMPCOD = @empresa);	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Lista escolar

	if object_id('tempdb.dbo.#Lista') is not null
		drop table #Lista	

	select 
	A.LIENUM,
	LIEANOLET,
	RTRIM(CLINOM) AS CLINOM,
	RTRIM(SEENOM) AS SEENOM,
	@Validade AS DataValidade,
	LIEOBS,
	LIEITE,
	RTRIM(B.PROCOD) AS PROCOD,
	RTRIM(MARNOM) AS MARNOM,
	RTRIM(LIEPRODES) AS LIEPRODES,
	LIEUNI,
	LIEQTD,
	LIEPRE,
	round(LIEQTD * LIEPRE, 2) AS TotalItem,
	RTRIM(LIEINFADIPRO) AS LIEINFADIPRO,
	@MsgRodape AS MsgRodape,
	@EMPWHATSAPP AS EMPWHATSAPP
	
	into #Lista

	from TBS151 A (NOLOCK)
	INNER JOIN TBS1511 B (NOLOCK) ON B.LIEEMPCOD = A.LIEEMPCOD AND B.LIENUM = A.LIENUM
	INNER JOIN TBS002 C (NOLOCK) ON C.CLIEMPCOD = A.CLIEMPCOD AND C.CLICOD = A.CLICOD
	INNER JOIN TBS150 D (NOLOCK) ON D.SEEEMPCOD = A.SEEEMPCOD AND D.SEECOD = A.SEECOD
	INNER JOIN TBS010 E (NOLOCK) ON E.PROEMPCOD = B.PROEMPCOD AND E.PROCOD = B.PROCOD	

	Where 
	A.LIEEMPCOD = @empresaTBS151 AND
	A.CLIEMPCOD = @empresaTBS002 AND
	A.SEEEMPCOD = @empresaTBS150 AND
	A.LIENUM = @LIENUM

	-- Tabela final
	SELECT * FROM #Lista
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End