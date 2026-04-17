/*
====================================================================================================================================================================================
WREL038 - Orcamento
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
21/01/2026 WILLIAM
	- Inclusao do prefixo "Orcamento", apos obter o caminho base das imagens dos relatorios via parametro 1315;
16/04/2025 WILLIAM
	- Inclusao de verificacao do CRT da empresa emitente, para alimentar coluna "imprimeICMS", isso ira definir impressao do ICMS apenas para empresas do regime normal(CRT= );
	- Leitura do parametro 1315, para obter o caminho padrao das imagens no servidor de relatorios, deixando o relatorio mais universal possivel, sem a necessidade de alterar o 
	caminho manualmente no design do ReportServer;
28/01/2025 WILLIAM
	- Refinamento do codigo;
	- Retirada da verificacao do parametro 1516, que verificava os ramos de atividade do cliente para imprimir ou nao o logo de 50 anos do grupo,
	dessa forma o atributo {imprimelogo50anos} foi forcado para = 'N';
17/04/2024 WILLIAM			
	- Verificacao se parametro 1516 esta vazio, para apagar a tabela #RAMOS e orcamento imprimir a imagem correta;
16/04/2024 WILLIAM			
	- Leitura do parametro 1517, para obter os codigos de clientes para saber se imprime PIS e COFINS, solicitacao de Taubate, dessa forma conseguimos unificar o script da SP;
02/04/2024 WILLIAM			
	- Desativando a detecao de parametros, atribuindo os parametros a variaveis locais;
	- Identificando se sera impresso ou nao, o logo de 50 anos do grupo, atraves do parametro 1516, que contera o codigo do ramos de atividade dos clientes que sere impresso o logo normal de cada empresa;
02/02/2024 WILLIAM
	- Inclusao de filtros nas tabelas pela empresa, utilizando o parametro recebido via menu do Integros(@empcod), para atender clientes que tem multi-empresas e tabelas exclusivas;
01/02/2024 WILLIAM			
	- Criacao da consulta para o ReportServer via stored procedure, para facilitar a manutencao e implantacao nos BD das empresas;
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_Orcamento_DEBUG]
ALTER proc [dbo].[usp_RS_Orcamento]
	@empcod int,
	@ORCNUM int	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@empresaTBS002 smallint, @empresaTBS004 smallint, @empresaTBS008 smallint, @empresaTBS010 smallint, @empresaTBS043 smallint, @empresaTBS097 smallint,
			@codigoEmpresa smallint, @orcamento int, @imprimeICMS char(1), @CRT_Emitente smallint, @Path_Image_Logo varchar(500),
			@PARVAL varchar(254);

-- Atribuicoes para desabilitar o "Parameter Sniffing" do SQL
	SET @codigoEmpresa = @empcod;
	SET @orcamento = @ORCNUM;

-- Atribuicoes locais		
	SET @imprimeICMS = IIF((SELECT TOP 1 EMPCRT FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa) = 3, 'S', 'N');
	SET @Path_Image_Logo = RTRIM(dbo.ufn_Get_Parametro(1315)) + 'Orcamento\Orcamento.JPG';
	
-- Verificar se a tabela � compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS008', @empresaTBS008 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS043', @empresaTBS043 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS097', @empresaTBS097 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela do PIS e COFINS
	
	IF object_id('tempdb.dbo.#PISCOFINS') IS NOT NULL	
		DROP TABLE #PISCOFINS;
   
	CREATE TABLE #PISCOFINS (CFOP CHAR(3))

	INSERT INTO #PISCOFINS
	SELECT '102'
	UNION
	SELECT '108'
	UNION
	SELECT '114'
	UNION
	SELECT '202'
	UNION
	SELECT '405'
	UNION
	SELECT '411'

	-- 	select * from #PisCofins
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem os ramos de atividades do cliente, que nao podere imprimir o logo de 50 anos do grupo BMPT
	-- Usa a funcao "fsplit", para obter os c�digos do ramo de atividade e incluir na tabela #RAMOS

	-- Obter os clientes que ter�o o PIS e COFINS impressos no or�amento, no momento somente Taubate tem cliente configurado
	If object_id('TempDB.dbo.#CLIENTESPISCOFINS') is not null
		DROP TABLE #CLIENTESPISCOFINS

	SET @PARVAL = (SELECT RTRIM(PARVAL) FROM TBS025 (NOLOCK) WHERE PARCHV = 1517)
    SELECT
		elemento as valor
	INTO #CLIENTESPISCOFINS FROM fSplit(@PARVAL, ',')  

	IF @PARVAL = ''
		DELETE #CLIENTESPISCOFINS;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Or�amento

	IF object_id('tempdb.dbo.#ORCAMENTO') IS NOT NULL
		DROP TABLE #ORCAMENTO;

	SELECT 
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
			when 0 then '0 - Contratacao do frete por conta do remetente (CIF)'
			when 1 then '1 - Contratacao do frete por conta do destinatario (FOB)'
			when 2 then '2 - Contratacao do frete por conta de terceiros'
			when 3 then '3 - Transporte proprio por conta do remetente'
			when 4 then '4 - Transporte proprio por conta do destinatario'
			when 9 then '9 - Sem ocorrencia de transporte'
			else '' 
		end as ORCTIPFRE,

		ORCCFOP,

		case when ORCCLI in (select valor from #CLIENTESPISCOFINS) 
			then 'S'
			else 'N' 
		end as imprimePisCofins,

		ROUND(dbo.ORCVALFCP(B.ORCEMPCOD, B.ORCNUM, B.ORCITEM),2) AS ORCVALFCP
	INTO #ORCAMENTO	FROM TBS043 A (NOLOCK)	
		INNER JOIN TBS0431 B (NOLOCK) ON A.ORCEMPCOD = B.ORCEMPCOD AND A.ORCNUM = B.ORCNUM

	WHERE 
		A.ORCEMPCOD = @empresaTBS043 AND
		A.ORCNUM = @orcamento

	 --select * from #Orcamento
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Endere�o de entrega e cobran�a

	IF object_id('tempdb.dbo.#ENDERECOS') IS NOT NULL
		DROP TABLE #ENDERECOS;

	SELECT 
		A.CLICOD, 
		A.CLIENDCOD,
		RTRIM(CLILOG) + CASE WHEN CHARINDEX(RTRIM(LTRIM(CLIENDNUM)),RTRIM(CLILOG)) > 0 THEN '' ELSE ' , N� ' + RTRIM(LTRIM(CLIENDNUM)) END +
		case when rtrim(ltrim(CLIENDCPL)) <> '' then ' - ' + rtrim(ltrim(CLIENDCPL)) else '' end +
		' , ' + RTRIM(LTRIM(CLIENDBAI)) + ' , ' + RTRIM(LTRIM((SELECT MUNNOM FROM TBS003 C (NOLOCK) WHERE A.CLIENDMUNCOD = C.MUNCOD))) + ' - ' + CLIENDUFE AS CLIEND
	INTO #ENDERECOS FROM TBS0021 A (NOLOCK) 

	WHERE 
		A.CLIEMPCOD	= @empresaTBS002 AND
		A.CLICOD = (SELECT TOP 1 CLICOD FROM #ORCAMENTO WHERE ORCPARA = 'C')
	 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- ENDERE�O DE ENTREGA

	IF object_id('tempdb.dbo.#ENDENT') IS NOT NULL
		DROP TABLE #ENDENT;

	SELECT TOP 1
		A.CLICOD, 
		CLIEND as CLIENDENT
	INTO #ENDENT FROM #ORCAMENTO B (NOLOCK)
		INNER JOIN #ENDERECOS A (NOLOCK) ON A.CLICOD = B.CLICOD AND A.CLIENDCOD = B.ORCENDENTCOD

-- select * from #ENDENT
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- ENDERE�O DE COBRAN�A 

	IF object_id('tempdb.dbo.#ENDCOB') IS NOT NULL	
		DROP TABLE #ENDCOB;

	SELECT TOP 1
		A.CLICOD, 
		CLIEND as CLIENDCOB
	INTO #ENDCOB FROM #ORCAMENTO B (NOLOCK) 
		INNER JOIN #ENDERECOS A (NOLOCK) ON A.CLICOD = B.CLICOD AND A.CLIENDCOD = B.ORCENDCOBCOD

-- select * from #ENDCOB
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Unidades de medida 

	IF object_id('tempdb.dbo.#UNIDADEMEDIDA') IS NOT NULL
		DROP TABLE #UNIDADEMEDIDA;

	SELECT 
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
	INTO #UNIDADEMEDIDA FROM TBS010 A (NOLOCK)

	WHERE 
		A.PROEMPCOD	= @empresaTBS010 AND
		PROCOD IN (SELECT DISTINCT PROCOD FROM #ORCAMENTO)

--select * from #UnidadeMedida
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

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
		RTRIM(CLIEND) + CASE WHEN CHARINDEX(RTRIM(LTRIM(CLINUM)),RTRIM(CLIEND)) > 0 THEN '' ELSE ' - N� ' + RTRIM(LTRIM(CLINUM)) END + case when rtrim(ltrim(CLICPLEND)) <> '' then ' - ' + rtrim(ltrim(CLICPLEND)) else '' end +
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

		case when isnull(contablizaPisConfins,'') = 'S' and substring(ORCCFOP,3,3) collate database_default in (select cfop from #PisCofins)
			then 
				Case when PROPIS > 0 
					then Round( ( (ORCTOTPRO - ORCVDDITE + ORCFREITEVAL + ORCSEGITEVAL + ORCDESITEVAL ) * PROPIS / 100 ) / ORCQTD, 2) -- COFINS do produto, sen�o do par�metro
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
					then Round( ( (ORCTOTPRO - ORCVDDITE + ORCFREITEVAL + ORCSEGITEVAL + ORCDESITEVAL ) * PROCOFINS /100 ) / ORCQTD, 2) -- COFINS do produto, sen�o do par�metro
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

		ORCVALFCP, 
		VENFAX,

		@imprimeICMS AS imprimeICMS,
		imprimePisCofins,
		@Path_Image_Logo AS PathImageLogo

	FROM #ORCAMENTO A (NOLOCK)
		LEFT JOIN #UNIDADEMEDIDA I  on A.PROCOD = I.PROCOD 
		LEFT JOIN TBS004 D  (NOLOCK) ON A.VENCOD = D.VENCOD AND D.VENEMPCOD = @empresaTBS004
		LEFT JOIN TBS002 E  (NOLOCK) ON A.CLICOD = E.CLICOD AND E.CLIEMPCOD = @empresaTBS002
		LEFT JOIN #ENDENT F (NOLOCK) ON A.CLICOD = F.CLICOD 
		LEFT JOIN #ENDCOB H (NOLOCK) ON A.CLICOD = H.CLICOD

End