/*
====================================================================================================================================================================================
														Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
02/02/2024	ANDERSON WILLIAM			- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod),
											para atender clientes que tem multi-empresas e tabelas exclusivas

01/02/2024	ANDERSON WILLIAM			- Criação da consulta para o ReportServer via stored procedure, para facilitar a manutenção e implantação nos BD das empresas
							
************************************************************************************************************************************************************************************
*/
--create proc [dbo].[usp_RS_Orcamento](
alter proc [dbo].[usp_RS_Orcamento](
	@empcod int,
	@ORCNUM int
	)
as

begin

	SET NOCOUNT ON;

------------------------------------------------------------------------------------------------------------------------------------------------------------	
-- Declarações das variaveis locais
	declare	@empresaTBS002 int, @empresaTBS004 int, @empresaTBS008 int, @empresaTBS010 int, @empresaTBS043 int, @empresaTBS097 int
------------------------------------------------------------------------------------------------------------------------------------------------------------	
		
-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS004', @empresaTBS004 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS008', @empresaTBS008 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS043', @empresaTBS043 output;
	exec dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS097', @empresaTBS097 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Clientes que pediram para aparecer o pis e cofins no orçamento 
-- Foi solicitado somente em Taubaté

	if object_id('tempdb.dbo.#Clientes') is not null
	begin
		drop table #Clientes
	end

	create table #Clientes (codigo int)

	insert into #Clientes
	select 1351 -- Cliente da Tanby Taubaté (criar parâmetro e unificar o script)
------------------------------------------------------------------------------------------------------------------------------------------------------------
	if object_id('tempdb.dbo.#PisCofins') is not null
	begin
		drop table #PisCofins
	end
   
	create table #PisCofins (cfop char(3))

	insert into #PisCofins

	select '102'
	union
	select '108'
	union
	select '114'
	union
	select '202'
	union
	select '405'
	union
	select '411'

	-- 	select * from #PisCofins
----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Orçamento

	if object_id('tempdb.dbo.#Orcamento') is not null
	begin
		drop table #Orcamento
	end

	select 
	ORCPARA,
	A.ORCDATCAD, 
	B.ORCITEM AS ORCITEM ,
	RTRIM(B.PROCOD) AS PROCOD,
	rtrim(rtrim(B.ORCDES)) as ORCDES,
	rtrim(B.ORCINFADIPRO) AS ORCINFADIPRO,
	RTRIM(B.ORCUNI) AS ORCUNI, 
	B.ORCQTD  AS ORCQTD,
	ORCPRE,
	ROUND(dbo.ORCTOTITEST(B.ORCEMPCOD,B.ORCNUM,B.ORCITEM),2) AS ORCTOTITEST,
	RTRIM(A.ORCCLI) AS CLICOD,
	RTRIM(A.ORCNOM) AS CLINOM,
	RTRIM(A.ORCREQNOM) AS ORCREQNOM,
	A.CPGCOD,
	A.ORCVALPRO, 
	A.ORCPRAENT,
	A.ORCNUM ,
	A.VENCOD , 
	ROUND(dbo.ORCVDDITE(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2)    AS ORCVDDITE,
	ROUND(dbo.ORCFREITEVAL(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCFREITEVAL,
	ROUND(dbo.ORCSEGITEVAL(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCSEGITEVAL,
	ROUND(dbo.ORCDESITEVAL(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCDESITEVAL ,
	ROUND(dbo.ORCVALICMSST(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCVALICMSST,
	ROUND(dbo.ORCTOTPRO(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCTOTPRO,
	ORCPERICMS,
	ROUND(dbo.ORCVALICMS(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM) / ORCQTD, 2) AS ORCVALICMS,
	A.ORCOBS,
	A.ORCREQCDC,
	ORCENDENTCOD,
	ORCENDCOBCOD,
	case ORCTIPENT
		when 'N' then 'Nosso Carro'
		when 'R' then 'Retira'
		when 'T' then 'Transportadora'
		when 'O' then 'Outros'
		else ''
	end ORCTIPENT,
	case ORCTIPFRE
		when 0 then '0 - Contratação do frete por conta do remetente (CIF)'
		when 1 then '1 - Contratação do frete por conta do destinatário (FOB)'
		when 2 then '2 - Contratação do frete por conta de terceiros'
		when 3 then '3 - Transporte próprio por conta do remetente'
		when 4 then '4 - Transporte próprio por conta do destinatário'
		when 9 then '9 - Sem ocorrência de transporte'
		else '' 
	end as ORCTIPFRE,

	ORCCFOP,

	case when ORCCLI in (select codigo from #Clientes) 
		then 'S'
		else 'N' 
	end as imprimiPisCofins,

	ROUND(dbo.ORCVALFCP(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCVALFCP

	into #Orcamento
	from TBS043 A (nolock)	
	inner join TBS0431 B (nolock) on A.ORCEMPCOD = B.ORCEMPCOD and A.ORCNUM = B.ORCNUM

	Where 
	A.ORCEMPCOD	= @empresaTBS043 AND
	A.ORCNUM	= @ORCNUM

	-- select * from #Orcamento
------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Endereço de entrega e cobrança

	if object_id('tempdb.dbo.#Enderecos') is not null
	begin
		drop table #Enderecos
	end

	select 
	A.CLICOD, 
	A.CLIENDCOD,
	RTRIM(CLILOG) + CASE WHEN CHARINDEX(RTRIM(LTRIM(CLIENDNUM)),RTRIM(CLILOG)) > 0 THEN '' ELSE ' , N° ' + RTRIM(LTRIM(CLIENDNUM)) END +
	case when rtrim(ltrim(CLIENDCPL)) <> '' then ' - ' + rtrim(ltrim(CLIENDCPL)) else '' end +
	' , ' + RTRIM(LTRIM(CLIENDBAI)) + ' , ' + RTRIM(LTRIM((SELECT MUNNOM FROM TBS003 C (NOLOCK) WHERE A.CLIENDMUNCOD = C.MUNCOD))) + ' - ' + CLIENDUFE AS CLIEND

	into #Enderecos
	from TBS0021 A (nolock) 

	where 
	A.CLIEMPCOD	= @empresaTBS002 AND
	A.CLICOD	= (select top 1 CLICOD from #Orcamento where ORCPARA = 'C')

------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ENDEREÇO DE ENTREGA

	if object_id('tempdb.dbo.#ENDENT') is not null
	begin
		drop table #ENDENT
	end

	SELECT 
	top 1
	A.CLICOD, 
	CLIEND as CLIENDENT

	INTO #ENDENT
	FROM #Orcamento B (NOLOCK)
	INNER JOIN #Enderecos A (NOLOCK) ON A.CLICOD = B.CLICOD AND A.CLIENDCOD = B.ORCENDENTCOD

-- select * from #ENDENT

------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ENDEREÇO DE COBRANÇA 

	if object_id('tempdb.dbo.#ENDCOB') is not null
	begin
		drop table #ENDCOB
	end

	SELECT 
	top 1
	A.CLICOD, 
	CLIEND as CLIENDCOB

	INTO #ENDCOB
	FROM #Orcamento B (NOLOCK) 
	INNER JOIN #Enderecos A (NOLOCK) ON A.CLICOD = B.CLICOD AND A.CLIENDCOD = B.ORCENDCOBCOD

-- select * from #ENDCOB

------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Unidades de medida 

	if object_id('tempdb.dbo.#UnidadeMedida') is not null
	begin
		drop table #UnidadeMedida
	end

	select 
	A.PROCOD,
	A.PROUM1,
	A.PROUM2,
	A.PROUM3,
	A.PROUM4,
	--A.PROUM1QTD,
	--A.PROUM2QTD,
	--A.PROUM3QTD,
	--A.PROUM4QTD,

	CASE WHEN PROUM1QTD = 1
		THEN ''
		ELSE
			CASE WHEN PROUM1QTD > 1 
			THEN '(' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) + ')' 
			ELSE '' 
		END 
	END  as UN1,

	CASE WHEN PROUM2QTD > 0 
		THEN '(' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) + 
			case when PROUM1QTD > 1  
				then ' '+ rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) + ')'
				else ')'
			end
		ELSE '' 
	END  as UN2,

	CASE WHEN PROUM3QTD > 0 
		THEN '(' + rtrim(CAST(PROUM3QTD / PROUM2QTD  AS DECIMAL(10,0)))+''+ rtrim(PROUM2) + ' ' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) + 
			case when PROUM1QTD > 1  
				then ' '+ rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) + ')'
				else ')'
			end
		ELSE '' 
	END  as UN3, 

	CASE WHEN PROUM4QTD > 0 
		THEN '(' + rtrim(CAST(PROUM4QTD / PROUM3QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM3) + ' ' + rtrim(CAST(PROUM3QTD / PROUM2QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM2) + ' ' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) + 
			case when PROUM1QTD > 1  
				then ' '+ rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) + ')'
				else ')'
			end
		ELSE '' 
	END  as UN4,

	RTRIM(MARNOM) AS MARNOM,
	RTRIM(PROCLAFIS) AS PROCLAFIS,

	case when PROSTBPIS not in ('06','07','08','09','49','70','71','72','73','74','98','99') 
		then 'S'
		else 'N' 
	end contablizaPisConfins,

	case when PROSTBPIS not in ('06','07','08','09','49','70','71','72','73','74','98','99') 
		then PROPIS
		else 0
	end PROPIS,
	case when PROSTBPIS not in ('06','07','08','09','49','70','71','72','73','74','98','99') 
		then PROCOFINS
		else 0
	end PROCOFINS,

	-- PIS COFINS do parametro
	(SELECT CAST(RTRIM(PARVAL) as money) FROM TBS025 (NOLOCK) WHERE PARCHV = 1116) AS parPIS,
	(SELECT CAST(RTRIM(PARVAL) as money) FROM TBS025 (NOLOCK) WHERE PARCHV = 1117) AS parCOFINS

	into #UnidadeMedida
	FROM TBS010 A (NOLOCK)

	WHERE 
	A.PROEMPCOD	= @empresaTBS010 AND
	PROCOD IN (SELECT distinct PROCOD FROM #Orcamento)

--select * from #UnidadeMedida

------------------------------------------------------------------------------------------------------------------------------------------------------------

	SELECT  
	A.ORCDATCAD, 
	A.ORCITEM AS ORCITEM ,
	A.PROCOD  AS PROCOD,
	rtrim(A.ORCDES + ' ' + 
	isnull(
	case when A.ORCUNI = I.PROUM1
		then UN1
		else 
			case when A.ORCUNI = I.PROUM2
				then UN2
				else 
					case when A.ORCUNI = I.PROUM3
						then UN3
						else
							case when A.ORCUNI = I.PROUM4
								then UN4
								else ''
							end 
					end 
			end
	end, A.ORCUNI) )  AS ORCDES,
	A.ORCINFADIPRO AS ORCINFADIPRO,
	I.MARNOM,
	RTRIM(I.PROCLAFIS) AS PROCLAFIS,
	RTRIM(A.ORCUNI)  AS ORCUNI, 
	A.ORCQTD  AS ORCQTD,
	ORCPRE,
	ORCTOTITEST,
	A.CLICOD AS CLICOD,
	A.CLINOM,
	A.ORCREQNOM AS ORCREQNOM,
	RTRIM(E.CLITEL) AS CLITEL,
	RTRIM(E.CLIRAM1) AS CLIRAMAL,
	(SELECT CPGDES FROM TBS008 I (NOLOCK) WHERE I.CPGEMPCOD = @empresaTBS008 AND A.CPGCOD = I.CPGCOD) AS CPGDES,
	A.ORCVALPRO, 
	A.ORCPRAENT,
	A.ORCNUM ,
	A.VENCOD , 
	RTRIM(VENNOM) AS VENNOM ,
	RTRIM(D.VENEMAIL) AS VENEMAIL ,
	RTRIM(D.VENRAM) AS VENRAM,
	RTRIM(D.VENTEL) AS VENTEL,
	RTRIM(D.VENTEL2) AS VENTEL2,
	RTRIM(D.VENRAM2) AS VENRAM2,
	RTRIM(CLIEND) + CASE WHEN CHARINDEX(RTRIM(LTRIM(CLINUM)),RTRIM(CLIEND)) > 0 THEN '' ELSE ' - N° ' + RTRIM(LTRIM(CLINUM)) END + case when rtrim(ltrim(CLICPLEND)) <> '' then ' - ' + rtrim(ltrim(CLICPLEND)) else '' end +
	' , ' + RTRIM(LTRIM(CLIBAI)) + ' , ' + RTRIM(LTRIM((SELECT MUNNOM FROM TBS003 G (NOLOCK) WHERE E.MUNCOD = G.MUNCOD))) + ' - ' + UFESIG AS CLIENDFAT,
	ISNULL(F.CLIENDENT,'') AS CLIENDENT,
	ISNULL(H.CLIENDCOB,'') AS CLIENDCOB, 
	ORCVDDITE,
	ORCFREITEVAL,
	ORCSEGITEVAL,
	ORCDESITEVAL ,
	ORCVALICMSST,
	ORCTOTPRO,
	ORCPERICMS,
	ORCVALICMS,
	A.ORCOBS,
	A.ORCREQCDC,
	ISNULL((SELECT RDVDES FROM TBS097 J (NOLOCK) WHERE J.RDVEMPCOD = @empresaTBS097 AND E.RDVCOD = J.RDVCOD),'') AS RDVDES,
	case when RTRIM(LTRIM(E.CLICGC)) <> ''
		then 
			case when len(E.CLICGC ) > 14
				then SUBSTRING(E.CLICGC,1,3) + '.' + SUBSTRING(E.CLICGC,4,3) + '.' + SUBSTRING(E.CLICGC,7,3) + '/' + SUBSTRING(E.CLICGC,10,4) + '-' + SUBSTRING(E.CLICGC,14,2)
				else SUBSTRING(E.CLICGC,1,2) + '.' + SUBSTRING(E.CLICGC,3,3) + '.' + SUBSTRING(E.CLICGC,6,3) + '/' + SUBSTRING(E.CLICGC,9,4) + '-' + SUBSTRING(E.CLICGC,13,2)
			end
		else ''
	end as CNPJ,
	case when RTRIM(LTRIM(E.CLICPF)) <> ''
		then SUBSTRING(E.CLICPF,1,3) + '.' + SUBSTRING(E.CLICPF,4,3) + '.' + SUBSTRING(E.CLICPF,7,3) + '-' + SUBSTRING(E.CLICPF,10,2)
		else ''
	end as CPF,
	ORCTIPENT,
	ORCTIPFRE,

	imprimiPisCofins,

	case when isnull(contablizaPisConfins,'') = 'S' and substring(ORCCFOP,3,3) collate database_default in (select cfop from #PisCofins)
		then 
			Case when PROPIS > 0 
				then Round( ( (ORCTOTPRO - ORCVDDITE + ORCFREITEVAL + ORCSEGITEVAL + ORCDESITEVAL ) * PROPIS / 100 ) / ORCQTD, 2) -- COFINS do produto, senão do parâmetro
				else Round( ( (ORCTOTPRO - ORCVDDITE + ORCFREITEVAL + ORCSEGITEVAL + ORCDESITEVAL ) * parPIS / 100 ) / ORCQTD, 2) -- (7,6%)
			End
		else 0
	end as pis, 

	case when isnull(contablizaPisConfins,'') = 'S' and substring(ORCCFOP,3,3) collate database_default in (select cfop from #PisCofins)
		then
			Case when PROPIS > 0 
				then PROPIS
				else parPIS
			End
		else ''
	end as apis, 

	case when isnull(contablizaPisConfins,'') = 'S' and substring(ORCCFOP,3,3) collate database_default in (select cfop from #PisCofins)
		then 
			Case when PROCOFINS > 0 
				then Round( ( (ORCTOTPRO - ORCVDDITE + ORCFREITEVAL + ORCSEGITEVAL + ORCDESITEVAL ) * PROCOFINS /100 ) / ORCQTD, 2) -- COFINS do produto, senão do parâmetro
				else Round( ( (ORCTOTPRO - ORCVDDITE + ORCFREITEVAL + ORCSEGITEVAL + ORCDESITEVAL ) * parCOFINS /100 ) / ORCQTD, 2) -- (7,6%)
			End
		else 0
	end as cofins,

	case when isnull(contablizaPisConfins,'') = 'S' and substring(ORCCFOP,3,3) collate database_default in (select cfop from #PisCofins)
		then 
			Case when PROCOFINS > 0 
				then PROCOFINS
				else parCOFINS
			End
		else ''
	end as acofins, 

	ORCVALFCP, VENFAX

	FROM #Orcamento A (NOLOCK)
	left join #UnidadeMedida I  on A.PROCOD = I.PROCOD 
	LEFT JOIN TBS004 D  (NOLOCK) ON A.VENCOD = D.VENCOD AND D.VENEMPCOD = @empresaTBS004
	LEFT JOIN TBS002 E  (NOLOCK) ON A.CLICOD = E.CLICOD AND E.CLIEMPCOD = @empresaTBS002
	LEFT JOIN #ENDENT F (NOLOCK) ON A.CLICOD = F.CLICOD 
	LEFT JOIN #ENDCOB H (NOLOCK) ON A.CLICOD = H.CLICOD

End