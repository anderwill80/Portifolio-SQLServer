/*
====================================================================================================================================================================================
														Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
29/04/2024	ANDERSON WILLIAM			- Criação da consulta para o ReportServer via stored procedure, para facilitar a manutenção e implantação nos BD das empresas
							
************************************************************************************************************************************************************************************
*/
CREATE PROC [dbo].[usp_RS_PedidoCompras](
--ALTER PROC [dbo].[usp_RS_PedidoCompras](
	@empcod int,
	@PDCNUM int
	)
as

begin

	SET NOCOUNT ON;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Declarações das variaveis locais

	declare	@empresaTBS045 smallint, @empresaTBS010 smallint,
			@empresa smallint, @pedido int, 
			@PARVAL varchar(254), @imprimeProdFor char(1), @Aviso1 varchar(254), @Aviso2 varchar(254)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL

	SET @empresa = @empcod
	SET @pedido = @PDCNUM
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS045', @empresaTBS045 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem códigos dos fornecedores, para imprimir pedido/item de vendas abaixo da descrição produto	
	If object_id('TempDB.dbo.#FORPDV') is not null
		DROP TABLE #FORPDV

	SET @PARVAL = (SELECT RTRIM(PARVAL) FROM TBS025 (NOLOCK) WHERE PARCHV = 1515)

    select elemento as [forpdv]
	Into #FORPDV

    From fSplit(@PARVAL, ';')    

	if @PARVAL = ''
		delete #FORPDV

	-- Verifica se é para imprimir o código e a descrição do fornecedor, abaixo da nossa descrição
	SET @imprimeProdFor = (SELECT RTRIM(PARVAL) FROM TBS025 (NOLOCK) WHERE PARCHV = 1216)

	-- Mensagens de aviso para o fornecedor
	SET @Aviso1 = (SELECT RTRIM(PARVAL) FROM TBS025 (NOLOCK) WHERE PARCHV = 1122)
	SET @Aviso2 = (SELECT RTRIM(PARVAL) FROM TBS025 (NOLOCK) WHERE PARCHV = 1123)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Endereço principal da empresa emitente, que será usada caso não tenha sido informado o endereço de entrega para o faturamento

	If object_id('tempdb.dbo.#EndEmpresa') is not null
		drop table #EndEmpresa

	select
	dbo.FormatarCnpj(EMPCGC) AS EMPCGCFAT,
	EMPIES AS EMPIESFAT,
	RTRIM(EMPEND) + ' , N° ' + RTRIM(LTRIM(EMPNUM)) +	
	' , ' + RTRIM(LTRIM(EMPBAI)) + ' , ' + RTRIM(LTRIM(EMPMUNNOM)) + ' - ' + EMPUFESIG AS EMPENDFAT

	into #EndEmpresa

	from TBS023 A (NOLOCK) 

	Where 
	EMPCOD	= @empresa
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Endereço de entrega da empresa emitente

	If object_id('tempdb.dbo.#EndEntregaEmpresa') is not null
		drop table #EndEntregaEmpresa

	select 
	EMPCOD,
	EMPENDCOD,
	EMPENDCGC AS EMPENDCGCENT,
	EMPENDIES AS EMPENDIESENT,
	RTRIM(EMPENDLOG) + ' , N° ' + RTRIM(LTRIM(EMPENDNUM)) +
	case when RTRIM(LTRIM(EMPENDCPL)) <> '' then ' - ' + rtrim(ltrim(EMPENDCPL)) else '' end +
	' , ' + RTRIM(LTRIM(EMPENDBAI)) + ' , ' + RTRIM(LTRIM((SELECT MUNNOM FROM TBS003 C (NOLOCK) WHERE A.EMPENDMUNCOD = C.MUNCOD))) + ' - ' + EMPENDUFE AS EMPENDENT

	INTO #EndEntregaEmpresa

	from TBS0231 A (NOLOCK) 

	where 
	EMPCOD	= @empresa AND
	EMPENDTIP = 'E'

	--SELECT * FROM EndEntregaEmpresa
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Orçamento

	if object_id('tempdb.dbo.#Pedido') is not null
	begin
		drop table #Pedido
	end

	select 
	A.PDCNUM,
	PDCDATCAD, 
	FOREMPCOD,
	PDCENDENT,
	FORCOD,
	PDCOBS,
	PDCCPGEMP,
	PDCCPGCOD,
	COMEMPCOD,
	COMCOD,
	PDCTRNEMP,
	PDCTRNCOD,
	PDCITE,
	PROEMPCOD,
	RTRIM(B.PROCOD) AS PROCOD,
	RTRIM(PDCDES) AS PDCDES,
	PDCUNI,
	PDCQTD,
	PDCPRE,
	PDCIPI,
	PDCPORST,
	PDCPDDITE,

	dbo.PDCPRELIQ(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCPRELIQ,	
	PDCQTDENT AS 'ENTREGUE',
	ROUND(PDCQTD - (PDCQTDENT + PDCQTDRES), 4) AS 'PENDENTE',
	PDCDATFAT,
	PDCPDVNUM,
	PDCPDVITE,

	-- Valores do item
	dbo.PDCVALFRE(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCVALFRE,		-- Frete
	dbo.PDCVALIPI(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCVALIPI,		-- IPI
	dbo.PDCVALOUT(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCVALOUT,		-- Outras despesas
	dbo.PDCVALSEG(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCVALSEG,		-- Seguro
	dbo.PDCVALST(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCVALST,		-- ST
	dbo.PDCVDDITE(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCVDDITE,		-- Desconto item
	dbo.PDCTOTPRO(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCTOTPRO,		-- total produtos
	dbo.PDCTOTITE(A.PDCEMPCOD, A.PDCNUM, PDCITE) AS PDCTOTITE		-- total do item

	into #Pedido

	from TBS045 A (NOLOCK)
	INNER JOIN TBS0451 B (NOLOCK) ON A.PDCEMPCOD = B.PDCEMPCOD AND A.PDCNUM = B.PDCNUM

	Where 
	A.PDCEMPCOD = @empresaTBS045 AND
	A.PDCNUM = @pedido

	--select * from #Pedido
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	select 
	A.*,
	FORNOM,
	ISNULL((SELECT EMPCGCFAT FROM #EndEmpresa), '') AS EMPCGCFAT,
	ISNULL((SELECT EMPIESFAT FROM #EndEmpresa), '') AS EMPIESFAT,
	ISNULL((SELECT EMPENDFAT FROM #EndEmpresa), '') AS EMPENDFAT,
	
	ISNULL(dbo.FormatarCnpj(EMPENDCGCENT), '') AS EMPENDCGCENT,
	ISNULL(EMPENDIESENT, '') AS EMPENDIESENT,
	ISNULL(EMPENDENT, '') AS EMPENDENT,

	dbo.FormatarCnpj(G.FORCGC) AS FORCNPJ,

	dbo.FormatarCpf(G.FORCPF) AS FORCPF,

	RTRIM(FORIES) AS FORIES,
	RTRIM(FORCONTAT) AS FORCONTAT,
	RTRIM(FOREMAIL) AS FOREMAIL,
	RTRIM(FORTEL) AS FORTEL,
	RTRIM(FORFAX) AS FORFAX,
	RTRIM(FOREND) AS  FOREND,
	RTRIM(FORNUM) AS FORNUM,
	RTRIM(FORBAI) AS FORBAI,
	RTRIM(FORCEP) AS FORCEP,
	RTRIM(MUNNOM) AS FORMUNNOM,
	RTRIM(G.UFESIG) AS FORUFESIG,

	ISNULL(CPGDES, '') AS PDCCPGDES,
	ISNULL(TRNNOM, '') AS PDCTRNNOM,
	ISNULL(COMNOM, '') AS COMNOM,

	case when A.FORCOD IN (SELECT forpdv FROM #FORPDV) 
		then 'S'
		else 'N' 
	end imprimePDV,

	@imprimeProdFor AS 'imprimeProdFor',

	ISNULL((SELECT TOP 1 PROFORPRO FROM TBS0101 B (NOLOCK) WHERE PROEMPCOD = @empresaTBS010 AND B.PROCOD = A.PROCOD AND PROFORCOD = A.FORCOD ORDER BY PROFORUSUCAD DESC), '') AS PROFORPRO,
	ISNULL((SELECT TOP 1 PROFORDES FROM TBS0101 B (NOLOCK) WHERE PROEMPCOD = @empresaTBS010 AND B.PROCOD = A.PROCOD AND PROFORCOD = A.FORCOD ORDER BY PROFORUSUCAD DESC), '') AS PROFORDES,

	@Aviso1 AS 'AVISO1',
	@Aviso2 AS 'AVISO2'
	

	from #Pedido A (NOLOCK)	
	LEFT JOIN #EndEntregaEmpresa (NOLOCK) ON  EMPENDCOD = PDCENDENT
	LEFT JOIN TBS005 C (NOLOCK) ON TRNEMPCOD = PDCTRNEMP AND TRNCOD = PDCTRNCOD	
	LEFT JOIN TBS008 D (NOLOCK) ON CPGEMPCOD = PDCCPGEMP AND CPGCOD = PDCCPGCOD
	LEFT JOIN TBS046 F (NOLOCK) ON F.COMEMPCOD = A.COMEMPCOD AND F.COMCOD = A.COMCOD
	LEFT JOIN TBS006 G (NOLOCK) ON G.FOREMPCOD = A.FOREMPCOD AND G.FORCOD = A.FORCOD
	LEFT JOIN TBS003 H (NOLOCK) ON H.MUNCOD = G.MUNCOD

	Order by PDCITE
	

End