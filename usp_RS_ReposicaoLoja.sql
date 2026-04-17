/*
====================================================================================================================================================================================
WREL057 - Reposicao de loja
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
05/06/2025 - WILLIAM
	- Troca do parametro "@pSomenteCupom = 'S'" pelo "ptipoDocumento = 'C'" na chamada da SP "usp_Get_DWVendas";
26/02/2025 - WILLIAM
	- Atribuicao de valores default para os parametros de entrada, para facilitar a chamada, permitindo preencher somente o que for necessario para o momento;	
	- Uso da SP "usp_Get_CodigosProdutos" e "usp_Get_DiasUteis";
	- Uso da SP "usp_Get_DWVendas", para obter dados dos cupons;
28/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Utilizacao da SP "usp_GetCodigosProdutos";
	- Retirada do parametro de entrada @Loces, sem uso nas empresas;
12/04/2024 WILLIAM			
	- Udo da nova SP(usp_GetDiasUteis) que recebe o codigo IBGE do munic�pio da empresa consultando a nova tabela de feriados(dbo.FERIADOS);
10/04/2024 WILLIAM
	- Inclusao do parametro GRUCOD em listas, usando a funcao fSplit para gerar um tabela #GRUPOS;
09/04/2024 WILLIAM
	- Inclusao do hint "OPTION(MAXRECURSION 0)", apos a chamada da funcao fSplit() para lista de valores do subgrupo, pois tem mais de 100 itens;
	- Inclusao da condicao "caixa > 0" ao obter dados da tabela "DWVendas", pois duplicou registro de venda quando tira NF de cupom e retirada do da condicao "contabiliza = 'L'"
	- Verificacao se a "data ate" ano e mes corrente, para rodar as storedprocedure para "alimentar" a tabela DWVendas e DWDevolucaoVendas com os dados do dia atual;
08/04/2024 WILLIAM
	- Uso da SP "usp_DiasUteis" em vez da funcao "FCNDIASUTEIS";
05/04/2024 WILLIAM
	- Alteracao dos tipos de decimal(10, 4) para decimal(12, 6), para atributos relacionados a quantidades(TBS032);
	- Uso SP VerificaLink3 no lugar da VerificaLink2;
	- Obtem itens vendidos na loja da tabela DWVendas;
04/04/2024 WILLIAM
	- Conversao para Stored procedure
	- Uso de querys dinamicas utilizando a "sp_executesql" para executar comando sql com parametros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela";										
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_ReposicaoLoja_DEBUG]
ALTER PROC [dbo].[usp_RS_ReposicaoLoja]
	@empcod smallint,
	@PROCODDE varchar(8000) = '',
	@GRUCOD varchar(500) = '',
	@SUBGRUCOD varchar(500) = '',
	@PRODES varchar(60) = '',
	@MARCOD int = 0,
	@MARNOM varchar(30) = '',
	@anoDe char(4) = '',
	@mesDe char(2) = '',
	@anoAte char(4) = '',
	@mesAte char(2) = '',
	@PERIODO smallint = 0,
	@SITUACAO varchar(8000) = ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE  @codigoEmpresa smallint, @empresaTBS010 int, @empresaTBS012 int, @empresaTBS037 int, @empresaTBS059 int,
	@PROCOD varchar (8000), @ListGrupo varchar (500), @ListSubGrupo varchar (500),
	@DescricaoPro varchar(60), @CodMarca int, @MarcaNome varchar(30), @cAnoDe char(4),	@cMesDe char(2), @cAnoAte char(4),	@cMesAte char(2),
	@nPERIODO smallint, @ListSITUACAO varchar(8000),			
	@Query nvarchar (MAX), @ParmDef nvarchar (500),
	@cnpjEmpresaLocal varchar(14), @ufEmpresaLocal char(2), @munEmpresaLocal int,
	@dataSource varchar(35), @verificaLinkCD int, @retornoCD varchar(20), @verificaLinkTT int, @retornoTaubate varchar(20),
	@dataDe datetime, @dataAte datetime, @qtdFeriados int, @qtdDiasUteis int

-- Variaveis internas do reporting service, as atribuicoes desativam o "Parameter Sniffing"
	SET @codigoEmpresa = @empcod
	SET @PROCOD = @PROCODDE
	SET @ListGrupo = @GRUCOD
	SET @ListSubGrupo = @SUBGRUCOD
	SET @DescricaoPro = RTRIM(LTRIM(UPPER(@PRODES)));
	SET @CodMarca = @MARCOD
	SET	@MarcaNome = RTRIM(LTRIM(UPPER(@MARNOM)));
	SET @cAnoDe = @anoDe
	SET @cMesDe = @mesDe
	SET @cAnoAte = @anoAte
	SET @cMesAte = @mesAte
	SET @nPERIODO = @PERIODO

	SET @ListSITUACAO = @SITUACAO

	-- Demais variaveis
	select @cnpjEmpresaLocal = EMPCGC, @ufEmpresaLocal = EMPUFESIG, @munEmpresaLocal = EMPMUNCOD FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa

	SET @dataDe = (select convert(datetime, @cAnoDe + @cMesDe + '01')) 
	SET @dataAte = (select dateadd(day, -1, dateadd(month, 1, convert(datetime, @cAnoAte + @cMesAte + '01'))))

-- Quebra os filtros Multi-valores em tabelas via funcao "Split", para facilitar a cl�usula "IN()"	
	If object_id('TempDB.dbo.#SITUACOES') IS NOT NULL
		DROP TABLE #SITUACOES;
    SELECT 
		elemento as valor
	INTO #SITUACOES FROM fSplit(@ListSITUACAO, ',')
	-- Grupos de produtos
	If object_id('TempDB.dbo.#GRUPOS') IS NOT NULL
		DROP TABLE #GRUPOS;
    SELECT 
		elemento as valor
	INTO #GRUPOS FROM fSplit(@ListGrupo, ',')	
	-- Sub Grupos de produtos
	If object_id('TempDB.dbo.#SUBGRUPOS') IS NOT NULL
		DROP TABLE #SUBGRUPOS;
    SELECT 
		elemento as valor
	INTO #SUBGRUPOS FROM fSplit(@ListSubGrupo, ',') OPTION(MAXRECURSION 0)

-- Verificar se tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS012', @empresaTBS012 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS037', @empresaTBS037 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo codigo ou codigo de barras, se vazio filtra todos os codigo da TBS010, via SP

	If OBJECT_ID ('tempdb.dbo.#T') IS NOT NULL
		DROP TABLE #T;

	CREATE TABLE #T (PROCOD VARCHAR(15))

	INSERT INTO #T
	EXEC usp_Get_CodigosProdutos @codigoEmpresa, @PROCOD, @DescricaoPro, @CodMarca, @MarcaNome
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos produtos obtidos acima na T#

	If object_id('tempdb.dbo.#TBS010AUX') IS NOT NULL
	   DROP TABLE #TBS010AUX;

	-- Uso do "SELECT TOP 0" para criar apenas a estrutura da tabela #TBS010AUX igual a TBS010
	SELECT
		RTRIM(LTRIM(PROSETLOJ1 + CASE WHEN PROSETLOJ2 <> '' THEN ', ' + RTRIM(LTRIM(PROSETLOJ2)) ELSE '' END)) AS PROSETLOJ,
		PROSTATUS,
		case when len(MARCOD) = 4 
			then rtrim(MARCOD) + ' - ' + rtrim(MARNOM) 
			else right(('00' + ltrim(str(MARCOD))),3) + ' - ' + rtrim(MARNOM)
		end collate database_default as MARCOD ,
		PROCOD,
		PRODES,
		CASE WHEN PROUM1QTD > 1 
			THEN RTRIM(LTRIM(PROUM1)) + ' ' + RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '' + 
				CASE WHEN PROUMV = '' 
					THEN PROUM1 
					ELSE PROUMV 
				END 
			ELSE RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '' + 
				CASE WHEN PROUMV = '' 
					THEN PROUM1 
					ELSE PROUMV 
				END 
		END AS PROUM1,
		GRUCOD, 
		SUBGRUCOD	
	INTO #TBS010AUX FROM TBS010 A (NOLOCK)	

	WHERE
		PROEMPCOD = @empresaTBS010 AND
		PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Pegar a tabela de grupo 

	IF object_id('tempdb.dbo.#GRUPO') IS NOT NULL
		DROP TABLE #GRUPO;

	SELECT 
		GRUCOD as codigoGrupo,
		rtrim(GRUDES) + ' (' + ltrim(str(GRUCOD,3)) + ')' as nomeGrupo

	INTO #GRUPO FROM TBS012 (NOLOCK) 

	Where 
		GRUEMPCOD = @empresaTBS012
	ORDER BY 
		GRUEMPCOD,
		GRUCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Pegar a tabela de subgrupo 

	IF object_id('tempdb.dbo.#SUBGRUPO') IS NOT NULL
		DROP TABLE #SUBGRUPO;

	SELECT 
		GRUCOD as codigoGrupo,
		SUBGRUCOD as codigoSubgrupo,
		rtrim(SUBGRUDES) + ' (' + ltrim(str(SUBGRUCOD,3)) + ')' as nomeSubgrupo
	INTO #SUBGRUPO FROM TBS0121 (NOLOCK) 

	WHERE 
		GRUEMPCOD = @empresaTBS012
	ORDER BY 
		GRUEMPCOD,
		GRUCOD,
		SUBGRUCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final de produtos, para gravar nome do grupo e subgrupo

	IF object_id('tempdb.dbo.#TBS010') IS NOT NULL	
	   DROP TABLE #TBS010;

	SELECT 
		A.*,
		isnull(B.nomeGrupo, '(0)') as nomeGrupo,
		isnull(C.nomeSubgrupo, '(0)') as nomeSubgrupo
	INTO #TBS010 FROM #TBS010AUX A (NOLOCK) 
		LEFT JOIN #GRUPO B (nolock) on A.GRUCOD = B.codigoGrupo
		LEFT JOIN #SUBGRUPO C (nolock) on A.GRUCOD = C.codigoGrupo and A.SUBGRUCOD = C.codigoSubgrupo
	WHERE
		A.GRUCOD IN (select valor from #GRUPOS) AND
		LTRIM(RTRIM(STR(A.GRUCOD)))+ LTRIM(RTRIM(STR(A.SUBGRUCOD))) IN (select valor from #SUBGRUPOS)
	ORDER BY 
		A.PROCOD,
		A.GRUCOD,
		A.SUBGRUCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as tabelas sem uso a partir desse ponto

	DROP TABLE #T
	DROP TABLE #TBS010AUX
	DROP TABLE #GRUPO
	DROP TABLE #SUBGRUPO

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os saldos AGRUPADOS dos produtos, da empresa local

	IF object_id('tempdb.dbo.#TBS032') IS NOT NULL	
		DROP TABLE #TBS032;

	SELECT 
		PROCOD,
		SUM(ESTQTDCMP) AS ESTQTDCMP,
		ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM TBS032 B (nolock) WHERE PROEMPCOD = @empresaTBS010 AND ESTLOC = 1 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS EST,
		ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM TBS032 B (nolock) WHERE PROEMPCOD = @empresaTBS010 AND ESTLOC = 2 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS LOJA
	INTO #TBS032 FROM TBS032 A (NOLOCK) 
	WHERE 
		PROEMPCOD = @empresaTBS010 AND
		PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010) AND 
		ESTLOC IN (1,2) AND		
		(ESTQTDATU <> 0 OR  ESTQTDCMP <> 0)	
	GROUP BY 
		PROCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os saldos AGRUPADOS dos produtos da TANBY CD

	SET @dataSource = (select top 1 data_source from sys.servers where name = 'cd' order by name)

	EXEC VerificaLink3 @dataSource, @verificaLinkCD output	

	SET @retornoCD = IIf(@verificaLinkCD = 1, 'CD - Ok', 'CD - Falhou')
	
	-- Cria tabela de saldo do CD
	If OBJECT_ID ('tempdb.dbo.#TBS032CD') IS NOT NULL	
		DROP TABLE #TBS032CD;		
	
	CREATE TABLE #TBS032CD(
		PROCOD VARCHAR(15),
		EST DECIMAL(12,6),
		ESTQTDRES DECIMAL(12,6)
	)

	-- Verifica se o CD est� ok , se sim, adiciona os itens na tabela #TBS032CD, se n�o, a tabela ficar� vazia
	If @verificaLinkCD = 1	
	Begin
		set @Query = '

		SELECT Scr.* 

		FROM OPENROWSET(''SQLNCLI'',''192.168.10.7'';''integros'';''int3gro5@15387'',''
		SELECT 
		A.PROCOD ,
		ESTQTDATU-ESTQTDRES AS EST,
		isnull((SELECT SUM(PRPQTD*PRPQTDEMB) FROM SIBD.dbo.TBS058 B (NOLOCK) WHERE A.PROCOD = B.PROCOD AND PRPSIT = ''''R'''' AND PRPCLICOD IN(590, 6709)), 0)  AS ESTQTDRES

		FROM 
		SIBD.dbo.TBS032 A (nolock) 

		WHERE 
		ESTLOC = 1 AND 
		ESTQTDATU <> 0'') AS Scr

		WHERE 
		Scr.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010) '

		insert into #TBS032CD
		exec(@Query)
	End
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os saldos AGRUPADOS dos produtos da TANBY TAUBAT�

	SET @dataSource = (select top 1 data_source from sys.servers where name = 'tt' order by name)

	EXEC VerificaLink3 @dataSource, @verificaLinkTT output	

	SET @retornoTaubate = IIf(@verificaLinkTT = 1, 'Taubate - Ok', 'Taubate - Falhou')
	
	-- Cria tabela de saldo de Taubat�
	IF object_id ('tempdb.dbo.#TBS032TT') IS NOT NULL
		DROP TABLE #TBS032TT;
	
	CREATE TABLE #TBS032TT(
		PROCOD VARCHAR(15),
		EST DECIMAL(12, 6),
		LOJA DECIMAL (12, 6),
		ESTQTDRES DECIMAL(12, 6)
	)

	-- Verifica se o Taubat� est� ok , se sim, adiciona os itens na tabela #TBS032TT, se n�o, a tabela ficar� vazia
	If @verificaLinkTT = 1	
	Begin
		set @Query = '

		SELECT Scr.* 

		FROM OPENROWSET(''SQLNCLI'',''192.168.3.205'';''integros'';''int3gro5@15387'',''
		SELECT 
		A.PROCOD ,
		ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM SIBD.dbo.TBS032 B (nolock) WHERE ESTLOC = 1 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS EST,
		ISNULL((SELECT SUM(ESTQTDATU-ESTQTDRES) FROM SIBD.dbo.TBS032 B (nolock) WHERE ESTLOC = 2 AND A.PROCOD = B.PROCOD GROUP BY PROCOD),0) AS LOJA,
		isnull((SELECT SUM(PRPQTD*PRPQTDEMB) FROM SIBD.dbo.TBS058 B (NOLOCK) WHERE A.PROCOD = B.PROCOD AND PRPSIT = ''''R'''' AND PRPCLICOD = 386),0)  AS ESTQTDRES

		FROM 
		SIBD.dbo.TBS032 A (nolock) 

		WHERE 
		ESTLOC IN (1,2) and ( 
		ESTQTDATU <> 0 )

		GROUP BY PROCOD
		'') AS Scr

		WHERE 
		Scr.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010) '

		insert into #TBS032TT
		exec(@Query)
	End
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE MOVIMENTOS INTERNOS ITENS QUE EST�O RESERVADOS PARA LOJA, PESQUISAR SOMENTE DO 1 PARA O ESTOQUE 2 

	IF object_id('tempdb.dbo.#TBS037') IS NOT NULL 
		DROP TABLE #TBS037;

	SELECT 
		B.PROCOD AS PROCOD,
		SUM(B.MVIQTDPED*B.MVIQTDEMB) AS QTDRES

	INTO #TBS037 FROM TBS037 A (NOLOCK)
		LEFT JOIN TBS0371 B (NOLOCK) ON A.MVIEMPCOD = B.MVIEMPCOD AND A.MVIDOC = B.MVIDOC
	WHERE 
		A.MVIEMPCOD = @empresaTBS037 AND
		A.TMVCOD = 507 AND 
		CONVERT(DATE, MVIDATLAN) BETWEEN GETDATE() - CONVERT(DATETIME, 30) AND GETDATE() AND 	
		CONVERT(DATE,A.MVIDATEFE) = '17530101' AND 
		B.PROCOD IS NOT NULL AND
		A.MVILOCORI = 1 AND 
		A.MVILOCDES = 2 AND 
		PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010)
	GROUP BY 
		B.PROCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Notas de saida do CD para Tanby ultimos 30 dias

	IF object_id ('tempdb.dbo.#NFSCD') IS NOT NULL
		DROP TABLE #NFSCD	

	CREATE TABLE #NFSCD(
		EMPCOD int,
		PROCOD VARCHAR(15),
		NFSNUM INT,
		QTD DECIMAL(12, 6),
		CNPJ VARCHAR(14)
	)
	
	If @verificaLinkCD = 1 
	Begin 		
		SET @Query = '
		SELECT 
		1 AS EMPCOD, 
		NF.PROCOD AS PROCOD,
		NF.NFSNUM AS NFSNUM,
		NF.QTD AS QTD,
		NF.CNPJ
	
		FROM OPENROWSET(''SQLNCLI'',''192.168.10.7'';''integros'';''int3gro5@15387'',''
		SELECT
		PROCOD COLLATE DATABASE_DEFAULT AS PROCOD,
		NFSNUM, 
		SUM(C.NFSQTD * C.NFSQTDEMB) AS QTD,
		substring(ENFCHAACE,7,14) as CNPJ
		
		FROM SIBD.dbo.TBS0671 C (nolock)
		LEFT JOIN SIBD.dbo.TBS080 D (NOLOCK) ON C.SNEEMPCOD = D.SNEEMPCOD AND C.SNESER = D.SNESER AND C.NFSNUM = D.ENFNUM
		
		WHERE
		D.ENFTIPDOC = 1 AND 
		D.ENFCNPJCPF = ''''' + @cnpjEmpresaLocal + ''''' AND 
		D.ENFSIT = 6 AND
		D.ENFDATEMI BETWEEN GETDATE() - CONVERT(DATETIME, 30) AND GETDATE()
		
		GROUP BY 
		PROCOD,NFSNUM,substring(ENFCHAACE,7,14)'') AS NF

		WHERE 
		NF.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010) '

		insert into #NFSCD 
		exec(@Query)
	End
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Notas de saida do TAUBATE para Tanby ultimos 30 dias

	IF object_id ('tempdb.dbo.#NFSTT') IS NOT NULL
		DROP TABLE #NFSTT;

	CREATE TABLE #NFSTT(
		EMPCOD int,
		PROCOD VARCHAR(15),
		NFSNUM INT,
		QTD DECIMAL(12, 6),
		CNPJ VARCHAR(14)
	)
	
	If @verificaLinkTT = 1 
	Begin 		
		SET @Query = '
		SELECT 
		2 AS EMPCOD, 
		NF.PROCOD AS PROCOD,
		NF.NFSNUM AS NFSNUM,
		NF.QTD AS QTD,
		NF.CNPJ
	
		FROM OPENROWSET(''SQLNCLI'',''192.168.3.205'';''integros'';''int3gro5@15387'',''
		SELECT
		PROCOD COLLATE DATABASE_DEFAULT AS PROCOD,
		NFSNUM, 
		SUM(C.NFSQTD * C.NFSQTDEMB) AS QTD,
		substring(ENFCHAACE,7,14) as CNPJ
		
		FROM SIBD.dbo.TBS0671 C (nolock)
		LEFT JOIN SIBD.dbo.TBS080 D (NOLOCK) ON C.SNEEMPCOD = D.SNEEMPCOD AND C.SNESER = D.SNESER AND C.NFSNUM = D.ENFNUM
		
		WHERE
		D.ENFTIPDOC = 1 AND 
		D.ENFCNPJCPF = ''''' + @cnpjEmpresaLocal + ''''' AND 
		D.ENFSIT = 6 AND
		D.ENFDATEMI BETWEEN GETDATE() - CONVERT(DATETIME, 30) AND GETDATE()
		
		GROUP BY 
		PROCOD,NFSNUM,substring(ENFCHAACE,7,14)'') AS NF

		WHERE 
		NF.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010) '

		insert into #NFSTT
		exec(@Query)
	End
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Faz a uni�o das tabelas de sa�da de Taubat� e CD, permanecendo apenas a #NFS
	
	IF object_id ('tempdb.dbo.#NFS') IS NOT NULL
		DROP TABLE #NFS;

	SELECT 
		* 
	INTO #NFS FROM #NFSCD
	
	UNION
	SELECT 
		* 
	FROM #NFSTT

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as tabelas sem uso a partir desse ponto

	DROP TABLE #NFSCD
	DROP TABLE #NFSTT

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- NOTAS DE ENTRADA NA TANBY, PERIODO DE 30 DIAS AT� HOJE
	
	IF object_id ('tempdb.dbo.#NFE') IS NOT NULL
		DROP TABLE #NFE;

	SELECT 
		CASE WHEN substring(NFECHAACE, 7, 14) collate database_default = (select CNPJ FROM #NFS WHERE EMPCOD = 1 GROUP BY CNPJ)
			THEN 1 
			ELSE 2
		END AS EMPCOD,
		A.NFENUM AS NFENUM, 
		PROCOD AS PROCOD
	INTO #NFE FROM TBS0591 A (NOLOCK)
		LEFT JOIN TBS059 B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND A.SERCOD = B.SERCOD AND  A.SEREMPCOD = B.SEREMPCOD
		LEFT JOIN TBS080 D (NOLOCK) ON A.NFENUM = D.ENFNUM AND A.NFECOD = D.ENFCODDES	
	WHERE 
		A.NFEEMPCOD = @empresaTBS059 AND
		A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS010) AND
		((D.ENFSIT = 6 AND D.ENFFINEMI = 4 AND D.ENFTIPDOC = 0 ) OR (NFENOSFOR <> 'S' AND B.NFECAN <> 'S' AND NFEDATEFE <> '' )) AND
		B.NFEDATEFE BETWEEN GETDATE() - CONVERT(DATETIME, 30) AND GETDATE() AND 
		substring(NFECHAACE, 7, 14) COLLATE DATABASE_DEFAULT IN (select CNPJ FROM #NFS GROUP BY CNPJ)
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE PRODUTOS EM TRANSITO PARA TANBY LOJA, DA PAPELYNA OU DA MISASPEL

	IF object_id ('tempdb.dbo.#TRA') IS NOT NULL
		DROP TABLE #TRA;
	
	SELECT 
		A.PROCOD ,
		SUM(QTD) AS QTD
	INTO #TRA FROM #NFS A 
		LEFT JOIN #NFE B ON A.PROCOD COLLATE DATABASE_DEFAULT = B.PROCOD AND A.NFSNUM = B.NFENUM AND A.EMPCOD = B.EMPCOD
	WHERE 
		B.NFENUM IS NULL
	GROUP BY 
		A.PROCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem itens vendidos na loja, com dados da tabela DWVendas no periodo selecionado, via SP

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @DescricaoPro,
		@pcodigoGrupoProduto = @ListGrupo,
		@pcodigoMarca = @CodMarca,
		@pnomeMarca =  @MarcaNome,
		@ptipoDocumento = 'C'	-- Somente vendas feitas com cupom fiscal
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Agrupa dados dos produtos vendidos na loja

	IF object_id('tempdb.dbo.#ITENSCUPOM') IS NOT NULL	
		DROP TABLE #ITENSCUPOM;
   
	CREATE TABLE #ITENSCUPOM(
		codigoProduto varchar(15),
		quant decimal(12, 6),
		datini date,
		datfim date
	)

	INSERT INTO #ITENSCUPOM
	SELECT 
		codigoProduto, 
		sum(quantidade) as quant,
		MIN(data) as datini,
		max(data) as datfim 

	FROM ##DWVendas

	GROUP BY 
		codigoProduto

--	select * from #ITENSCUPOM
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Criar uma logica para pegar os dias uteis corretamente

	-- se a menor data de vendas for maior que o primeiro dia do mes, tenho que pegar o 1 dia do mes 
	SET @dataDe = (select case when min(datini) > @dataDe then @dataDe else min(datini) end from #ITENSCUPOM) 

	SET @dataAte = (select 														
				    case when max(datfim) < convert(date, getdate()) -- se a maior data de venda for menor que hoje 
					then 
						case when convert(date, getdate()) <= @dataAte -- se a data de hoje for menor igual ao ultimo dia do mes filtrado 
							 then convert(date, getdate()) 		-- tenho que pegar o dia de hoje, pode haver dias que n�o houve vendas mas � um dia utel (devido a paralis��es) 
							else @dataAte						-- se hoje for maior que o ultimo dia do mes filtrado, pego o ultimo dia do mes
					end
						else max(datfim)		-- se a maior data de venda for igual a hoje pego a maior data de venda
					end				
				   from #ITENSCUPOM)
	
	EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @dataDe, @dataAte, '1', 'S', @qtdDiasUteis output, @qtdFeriados output

--select @dataDe, @dataAte, @qtdDiasUteis, @qtdFeriados;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamentos dos dados para obter a tabela final de #reposi��o

	If object_id('tempdb.dbo.#REPORAUX') IS NOT NULL
		DROP TABLE #REPORAUX;

	SELECT 
		A.PROCOD,
		PROSETLOJ,
		PROSTATUS,
		MARCOD ,
		GRUCOD, 
		nomeGrupo,
		SUBGRUCOD,
		nomeSubgrupo,
		PRODES,
		PROUM1,
		ISNULL(quant,0) AS TOTVEN,
		ISNULL(ROUND(quant / @qtdDiasUteis,2),0) as media,
		ISNULL(CEILING((quant / @qtdDiasUteis) * @nPERIODO),0)  AS SEG_LOJA,
		ISNULL(C.ESTQTDCMP,0) AS CMPND, 	-- COMPRAS ND
		ISNULL(C.EST,0) AS ESTND, 		-- Disponivel EST ND
		ISNULL(C.LOJA,0) AS LOJA, 		-- Disponivel Loja ND
		ISNULL(QTDRES,0) AS QTDRES, 	-- RESERVADO NO ESTOQUE PARA LOJA
		ISNULL(D.ESTQTDRES,0) AS RESCD, -- Reservado CD
		ISNULL(D.EST,0) AS ESTCD,		-- Disponivel CD
		ISNULL(F.ESTQTDRES,0) AS RESTT, -- Reservado TAUBAT�
		ISNULL(F.EST,0) AS ESTTT,		-- Disponivel EST TAUBAT�
		ISNULL(F.LOJA,0) AS LOJATT, 	-- Disponivel Loja ND
		ISNULL(QTD,0) AS QTD_TRA,		-- Em transito

		CASE WHEN ISNULL(C.LOJA,0) >=0 
			THEN 
				CASE WHEN ISNULL(CEILING((quant / @qtdDiasUteis) * @nPERIODO),0) - ISNULL(C.LOJA,0) - ISNULL(QTDRES,0) > 0 
						THEN ISNULL(CEILING((quant / @qtdDiasUteis) * @nPERIODO),0) - ISNULL(C.LOJA,0) - ISNULL(QTDRES,0)
						ELSE 0
				END
			ELSE 
				CASE WHEN ISNULL(CEILING((quant / @qtdDiasUteis) * @nPERIODO),0) - ISNULL(QTDRES,0) > 0 
					THEN ISNULL(CEILING((quant / @qtdDiasUteis) * @nPERIODO),0) - ISNULL(QTDRES,0)
					ELSE 0
				END 
		END as qtdrepor,

		@dataDe AS  dataini,
		@dataAte AS datafim,
		@qtdDiasUteis AS diasuteis

	INTO #REPORAUX FROM #TBS010 A
		LEFT JOIN #ITENSCUPOM B ON A.PROCOD COLLATE DATABASE_DEFAULT = B.codigoProduto	-- TABELA DE QUANTIDADE VENDIDA NA LOJA
		LEFT JOIN #TBS032 C 	ON A.PROCOD COLLATE DATABASE_DEFAULT = C.PROCOD			-- TABELA DE SALDO DA ND
		LEFT JOIN #TBS032CD D 	ON A.PROCOD COLLATE DATABASE_DEFAULT = D.PROCOD			-- TABELA DE SALDO DO CD
		LEFT JOIN #TBS032TT F 	ON A.PROCOD COLLATE DATABASE_DEFAULT = F.PROCOD			-- TABELA DE SALDO DE TAUBAT�
		LEFT JOIN #TRA E 		ON A.PROCOD COLLATE DATABASE_DEFAULT = E.PROCOD			-- TABELA DE PRODUTOS EM TRANSITO
		LEFT JOIN #TBS037 G		ON A.PROCOD COLLATE DATABASE_DEFAULT = G.PROCOD			-- TABELA DE PRODUTOS EM RESERVA NO ESTOQUE PARA LOJA (MOVIMENTO INTERNOS)

	WHERE 
		ISNULL(quant,0) <> 0 OR
		ISNULL(C.LOJA,0) <> 0 OR 
		ISNULL(C.EST,0) <> 0 OR 
		ISNULL(C.ESTQTDCMP,0) <> 0 OR 
		ISNULL(D.EST,0) <> 0 OR 
		ISNULL(D.ESTQTDRES,0) <> 0 OR
		ISNULL(F.EST,0) <> 0 OR 
		ISNULL(F.ESTQTDRES,0) <> 0 OR
		ISNULL(QTD,0) <> 0 OR 
		ISNULL(QTDRES,0) <> 0

--	SELECT * FROM #REPORAUX
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Refinamento para preencher o campo "SITUACAO"

	IF OBJECT_ID('tempdb.dbo.#REPORAUX2') IS NOT NULL
		DROP TABLE #REPORAUX2	;

	SELECT 
		CASE WHEN ESTND > 0 and (qtdrepor > 0 or ( LOJA <=0 and QTDRES = 0 ) )    -- ESTND + QTDRES > 0 and (qtdrepor > 0 or LOJA <= 0)         --  ) or (ESTND + QTDRES > 0 and qtdrepor = 0 and LOJA = 0)
			THEN '1.Pedir no Estoque'
			ELSE 
				CASE WHEN ESTCD > 0 and (qtdrepor > 0 or LOJA <= 0) and ESTND + QTDRES <=0          -- ) or (ESTCD > 0 and qtdrepor = 0 and LOJA = 0)
					THEN '2.Pedir no CD'
					ELSE
						CASE WHEN ESTTT > 0 and (qtdrepor > 0 or LOJA <= 0) and ESTND + QTDRES <=0 and ESTCD <=0
							THEN '3.Pedir no Estoque de Taubate'
							ELSE
								CASE WHEN LOJATT > 0 and (qtdrepor > 0 or LOJA <= 0) and ESTND + QTDRES <=0 and ESTCD <=0 and ESTTT<=0 
									THEN '4.Pedir na loja de Taubate'
									ELSE 
										CASE WHEN CMPND > 0 and (qtdrepor > 0 or LOJA <= 0) and ESTND + QTDRES <=0 and ESTCD <=0 and ESTTT<=0 AND LOJATT <=0 
											THEN '5.Esta em Compras'
											ELSE
												CASE WHEN qtdrepor > 0 and ESTND + QTDRES <=0 and ESTCD <=0 and ESTTT<=0 AND LOJATT <=0 AND CMPND <=0 
													THEN '6.Sem quantidade para repor'
													ELSE 
														CASE WHEN TOTVEN = 0 AND LOJA > 0 
															THEN '7.Produtos sem venda e com saldo'
															ELSE 
																CASE WHEN LOJA < 0 and TOTVEN = 0
																	THEN '8.Produtos Negativos sem vendas'
																	ELSE '9.OK'
																END
														END
												END
										END
								END
						END
				END
		END AS SITUACAO,
		*
	INTO #REPORAUX2 FROM #REPORAUX

--	select * from #REPORAUX2

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento para preencher o campo "qtdrepor1"

	IF OBJECT_ID('tempdb.dbo.#REPOSICAOLOJA') IS NOT NULL
		DROP TABLE #REPOSICAOLOJA;

	SELECT 
		*,
		case when substring(SITUACAO,1,1) = 1 and qtdrepor > ESTND
			then ESTND
			else 
				case when substring(SITUACAO,1,1) = 2 and qtdrepor > ESTCD
					then ESTCD
					else 
						case when substring(SITUACAO,1,1) = 3 and qtdrepor > ESTTT
							then ESTTT
							else
								case when substring(SITUACAO,1,1) = 4 and qtdrepor > LOJATT
									then LOJATT
									else qtdrepor
								end
						end
				end
		end as qtdrepor1
	INTO #REPOSICAOLOJA	FROM #REPORAUX2 

	WHERE 
		SITUACAO IN(SELECT valor FROM #SITUACOES)

--	select * from #REPOSICAOLOJA;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final #ReposicaoLoja
	SELECT 
		*,
		case when substring(SITUACAO,1,1) = 1 and qtdrepor1 = 0
			then case when ESTND > 10 then 10 else ESTND end 
			else 
				case when substring(SITUACAO,1,1) = 2 and qtdrepor1 = 0
					then case when ESTCD > 10 then 10 else ESTCD end 
					else 
						case when substring(SITUACAO,1,1) = 3 and qtdrepor1 = 0 
							then case when ESTTT > 10 then 10 else ESTTT end 
							else 
								case when substring(SITUACAO,1,1) = 4 and qtdrepor1 = 0
									then case when LOJATT > 10 then 10 else LOJATT end
									else qtdrepor1
								end
						end
				end 
		end as qtdrepor2,
		@retornoCD as retornoCD,
		@retornoTaubate as retornoTaubate
	FROM #REPOSICAOLOJA
/**/	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End