/*
====================================================================================================================================================================================
Coleta as informacoes de vendas via notas fiscais para "alimentar" a tabela ##Vendas_Notas, para ser usada em relatorios em que o usuario queria dados do dia.
Nao ira mais gravar os dados do dia na DWVendas, para evitar as duplicaoes verificadas principalmente em Taubate, devido a execucao de relatorios com a data do dia.
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
25/03/2026 WILLIAM
	- Inclusao do novo atributo "codigoGrupoSubGrupo";
02/06/2025 WILLIAM
	- Correcao nos filtros ao verificar se a nota foi autorizada posteriormente a data de emissão, estava duplicando vendas em relatorios que buscam informacoes do dia,
	devido ao processo de reimpressao via "cartolinha", que executa a consulta novamente da NF-e e registra novamente o codigo 100 na TBS0803;
22/04/2025 WILLIAM
	- Criacao, para permitir obter as vendas do dia, feitas via notas fiscais, similiar ao "AlimentaDWVendas", obtendo dados da TBS067, isso ira atender relatorios onde
	usuario escolhe a data do dia, onde anteriormente era feita a gravacao das vendas na DWVendas, porem ainda sim estava tendo duplicidade;	
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_Get_Vendas_Notas]
	@empcod int,
	@pdataDe date = null,
	@pdataAte date = null
AS 
BEGIN 
	SET NOCOUNT ON;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date,
			@empresaTBS010 smallint, @empresaTBS004 smallint, @empresaTBS091 smallint, @empresaTBS002 smallint, @empresaTBS067 smallint, @empresaTBS080 smallint,
			@codigoDevolucao int, @GRUPOSVENDLOJA varchar(50);

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod	
	SET @dataDe = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pdataAte, GETDATE()));
		
-- Variaveis locais
	SET @codigoDevolucao = CONVERT(INT, dbo.ufn_Get_Parametro(1330));
	SET @GRUPOSVENDLOJA = RTRIM(LTRIM(dbo.ufn_Get_Parametro(1531)))

	-- Verificar se a tabela e compartilhada ou exclusiva					
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS091', @empresaTBS091 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS067', @empresaTBS067 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @empresaTBS080 output;

-- Uso da funcao fSplit(), para gerar tabelas multivalores
	IF OBJECT_ID('tempdb.dbo.#MV_GVL') IS NOT NULL
		DROP TABLE #MV_GVL;
	SELECT 
		CONVERT(smallint, elemento) as valor
	INTO #MV_GVL FROM fSplit(@GRUPOSVENDLOJA, ',');
	IF( @GRUPOSVENDLOJA = '' )
		DELETE #MV_GVL;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrar os produtos na TBS010, se nao existe produto na TBS010 nao tem porque existir nas outras
		
	IF OBJECT_ID('tempdB.dbo.#PRODUTOS') IS NOT NULL 
		DROP TABLE #PRODUTOS;
	
	SELECT 
		A.PROEMPCOD as codigoEmpresa,
		RTRIM(A.PROCOD) as codigo,
		RTRIM(A.PRODES) as descricaoProduto,
		A.MAREMPCOD as codigoEmpresaMarca,
		A.MARCOD as codigoMarca,	
		RTRIM(A.MARNOM) as nomeMarca,
		A.PROUM1 as unidade1,
		A.PROUM1QTD as embalagem1,
		A.PROUMV as menorUnidadeVenda,
		A.PROUM2 as unidade2,
		A.PROUM2QTD as embalagem2,
		A.GRUEMPCOD as codigoEmpresaGrupoProduto,
		A.GRUCOD as codigoGrupo,
		ISNULL(RTRIM(B.GRUDES),'') as nomeGrupo,
		A.SUBGRUCOD as codigoSubgrupo,
		ISNULL(RTRIM(C.SUBGRUDES),'') as nomeSubgrupo,
		RIGHT(('000' + LTRIM(STR(A.GRUCOD))), 3) + RIGHT(('000' + LTRIM(STR(A.SUBGRUCOD))), 3) AS codigoGrupoSubGrupo
	INTO #PRODUTOS FROM  TBS010 A (NOLOCK)
		LEFT JOIN TBS012 B (NOLOCK) ON 
			A.GRUEMPCOD	= B.GRUEMPCOD AND A.GRUCOD = B.GRUCOD			
		LEFT JOIN TBS0121 C (NOLOCK) ON 
			A.GRUEMPCOD = C.GRUEMPCOD AND A.GRUCOD = C.GRUCOD AND A.SUBGRUCOD = C.SUBGRUCOD
	WHERE 
		A.PROEMPCOD = @empresaTBS010			

	ORDER BY 
		A.PROEMPCOD,
		A.PROCOD
	
	-- select * from #Produtos	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CFOP que contabiliza as vENDas e as devoluções de vENDas

	IF OBJECT_ID('tempdB.dbo.#CFOP_VENDAS') IS NOT NULL
		DROP TABLE #CFOP_VENDAS;
	   
	CREATE TABLE #CFOP_VENDAS (CFOP CHAR(3), TIPO CHAR(1))
	
	-- VENDas 	
	INSERT INTO #CFOP_VENDAS VALUES ('101', 'S') -- INDUSTRIALIZADO OU PRODUZIDO PELO ESTABELECIMENTO (N�O DEVERIA USAR)
	INSERT INTO #CFOP_VENDAS VALUES ('102', 'S') -- VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIROS
	INSERT INTO #CFOP_VENDAS VALUES ('108', 'S') -- VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIROS, DESTINADA A NãO CONTRIBUINTE
	INSERT INTO #CFOP_VENDAS VALUES ('114', 'S') -- VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIROS **REMETIDA** ANTERIORMENTE EM CONSIGNAçãO MERCANTIL
	-- INSERT INTO #CFOP_VENDAS VALUES ('116', 'S') -- VENDA DE PRODU��O DO ESTABELECIMENTO ORIGINADA DE ENCOMENDA PARA ENTREGA FUTURA (NãO DEVERIA USAR) 
	-- INSERT INTO #CFOP_VENDAS VALUES ('117', 'S') -- VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIROS, ORIGINADA DE ENCOMENDA PARA ENTREGA FUTURA -- TIREI DIA 06/02/2019
	INSERT INTO #CFOP_VENDAS VALUES ('118', 'S') -- VENDA DE PRODU��O DO ESTABELECIMENTO ENTREGUE AO DESTINATáRIO POR CONTA E ORDEM DO ADQUIRENTE ORIGINáRIO (NãO DEVERIA USAR)
	INSERT INTO #CFOP_VENDAS VALUES ('119', 'S') -- VENDA DE PRODU��O DO ESTABELECIMENTO ENTREGUE AO DESTINATáRIO POR CONTA E ORDEM DO ADQUIRENTE ORIGINáRIO (NãO DEVERIA USAR)	
	INSERT INTO #CFOP_VENDAS VALUES ('123', 'S') -- VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIROS REMETIDA PARA INDUSTRIALIZAçãO, POR CONTA E ORDEM DO ADQUIRENTE
	INSERT INTO #CFOP_VENDAS VALUES ('403', 'S') -- VENDA DE MERCADORIA, ADQUIRIDA OU RECEBIDA DE TERCEIROS, SUJEITA AO REGIME DE SUBSTITUIçãO TRIBUTáRIA, NA CONDIçãO DE **CONTRIBUINTE-SUBSTITUTO**
	INSERT INTO #CFOP_VENDAS VALUES ('404', 'S') -- VENDA DE MERCADORIA SUJEITA AO REGIME DE SUBSTITUIçãO TRIBUTáRIA, CUJO IMPOSTO Já TENHA SIDO RETIDO ANTERIORMENTE
	INSERT INTO #CFOP_VENDAS VALUES ('405', 'S') -- VENDA DE MERCADORIA, ADQUIRIDA OU RECEBIDA DE TERCEIROS, SUJEITA AO REGIME DE SUBSTITUIçãO TRIBUTáRIA, NA CONDIçãO DE *CONTRIBUINTE-SUBSTITUíDO*
	INSERT INTO #CFOP_VENDAS VALUES ('922', 'S') -- LANçAMENTO EFETUADO A TíTULO DE SIMPLES FATURAMENTO DECORRENTE DE VENDA PARA ENTREGA FUTURA -- ACRESENTADO DIA 06/02/2019
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Tabela dos vendedores

	IF OBJECT_ID('tempdB.dbo.#VENDEDORES') IS NOT NULL
		DROP TABLE #VENDEDORES;
	
	CREATE TABLE #VENDEDORES(
		codigoEmpresa int, 
		codigoVendedor int,
		nomeVendedor varchar(50),
		codigoEmpresaGrupoVendedor int,
		codigoGrupoVendedor int,
		nomeGrupoVendedor varchar(20)
		)
	
	INSERT #VENDEDORES	
	SELECT 
		VENEMPCOD,
		VENCOD,
		RTRIM(VENNOM) as nomeVendedor,
		ISNULL(B.GVEEMPCOD,0) as codigoEmpresaGrupoVendedor,
		A.GVECOD,
		RTRIM(ISNULL(B.GVEDES,'')) as nomeGrupoVendedor	
	FROM TBS004 A (NOLOCK)
		LEFT JOIN TBS091 B (nolock) on B.GVEEMPCOD = ISNULL(@empresaTBS091, 0) AND A.GVECOD = B.GVECOD AND A.GVEEMPCOD = B.GVEEMPCOD
	
	WHERE
		VENEMPCOD = @empresaTBS004 	

	ORDER BY 
		A.VENEMPCOD, 
		A.VENCOD
	
	-- select * from #VENDEDORES	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- inserir vendedor com o codigo 0, para as notas sem vendedor
	
	INSERT #VENDEDORES VALUES(@empresaTBS004, 0, '', ISNULL(@empresaTBS091, 0), 0, '')
	
	-- select * from #VENDEDORES	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra codigos de vendedores que fazer parte do grupo de LOJA

	IF object_id('tempdb.dbo.#VENDEDORESLOJA') IS NOT NULL
		DROP TABLE #VENDEDORESLOJA;

	SELECT 
		VENCOD AS CODIGO
	INTO #VENDEDORESLOJA FROM TBS004 B (NOLOCK)

	WHERE
		VENEMPCOD = @empresaTBS004 AND
		GVECOD IN (SELECT valor FROM #MV_GVL)
	ORDER BY 
		VENEMPCOD,
		GVECOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Clientes do grupo 
	
	IF OBJECT_ID('tempdB.dbo.#CLIENTESGRUPO') IS NOT NULL
		DROP TABLE #CLIENTESGRUPO;
	
	CREATE TABLE #CLIENTESGRUPO (CODIGO int)
	
	INSERT INTO #CLIENTESGRUPO	
	EXEC usp_Get_CodigosClientesGrupo @codigoempresa

	-- select * from #CLIENTESGRUPO
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem os dados dos clientes

	IF OBJECT_ID('tempdb.dbo.#CLIENTES') IS NOT NULL
		DROP TABLE #CLIENTES;
	
	SELECT
		CLIEMPCOD as codigoEmpresa,
		CLICOD as codigo,
		case WHEN CLITIPPES = 'J'
			THEN RTRIM(CLICGC) 
			ELSE RTRIM(CLICPF)
		END as cgc,
		CLITIPPES as tipoPessoa,
		RTRIM(CLINOM) as nomeCliente, 
		case WHEN CLIINDIE = 1 THEN 'S' ELSE 'N' END as contribuinteIcms	
	INTO #CLIENTES FROM TBS002 (NOLOCK)
	
	WHERE 
		CLIEMPCOD = @empresaTBS002
	
	ORDER BY
		CLIEMPCOD, 
		CLICOD
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Pegar os cabecalhos das notas de saida, tanto normal, quanto de cupom
--	SET STATISTICS TIME ON;

	IF OBJECT_ID('tempdb.dbo.#CABECALHONOTASVENDA') IS NOT NULL
		DROP TABLE #CABECALHONOTASVENDA;
	
	SELECT 
		A.NFSEMPCOD as codigoEmpresa,
		A.NFSNUM as numeroDocumento,
		A.SNEEMPCOD as codigoEmpresaNumeroSerie,
		A.SNESER as numeroSerieDocumento,
		A.SEREMPCOD as codigoEmpresaSerie,
		A.SERCOD as codigoSerieDocumento,
		0 as caixa,		
		
		-- 'V' as tipoDocumento,
		A.NFSCLIEMP as codigoEmpresaCliente, 
		A.NFSCLICOD as codigoCliente,
		D.cgc as cgc,
		D.tipoPessoa,
		D.nomeCliente COLLATE DATABASE_DEFAULT as nomeCliente,

		case WHEN A.NFSCLICOD IN (SELECT CODIGO FROM #CLIENTESGRUPO WHERE codigo <> @codigoDevolucao) -- cliente do grupo, indepENDente do vendedor, sempre vai contabilizar para o grupo
			THEN 'G'
			ELSE 
				case WHEN A.VENCOD IN(SELECT CODIGO FROM #VENDEDORESLOJA) -- vendedores do grupo de loja, contabiliza para a loja
					THEN 'L'
					ELSE 'C' -- vendedores diferente do grupo 2 ou 6, mesmo que esteja sem vendedor, contabiliza para o corporativo.
				END 
		END as contabiliza,		
		'N' as cancelado, -- A.NFSCAN as cancelado, -- As notas que est�o canceladas, no dia da emiss�o estavam autorizadas.
		(SELECT TOP 1 ENFCHAACE FROM TBS080 C (NOLOCK) WHERE C.ENFEMPCOD = @empresaTBS080 AND C.ENFNUM = A.NFSNUM AND C.SNEEMPCOD = A.SNEEMPCOD AND C.SNESER = A.SNESER) as chave,
		A.NFSDATEMI as dataEmissao,
		A.NFSHOREMI as hora,
		A.UFESIG as uf,
		A.NFSMUNNOM as municipio,
		C.codigoEmpresaGrupoVendedor as codigoEmpresaGrupoVendedor,
		C.codigoGrupoVendedor as codigoGrupoVendedor,
		C.nomeGrupoVendedor COLLATE DATABASE_DEFAULT as nomeGrupoVendedor,
		C.codigoEmpresa as codigoEmpresaVendedor,
		A.VENCOD as codigoVendedor,
		C.nomeVendedor COLLATE DATABASE_DEFAULT as nomeVendedor,		
		ISNULL(A.NFSREQCOD, 0) as codigoRequisitante,
		ISNULL(A.NFSREQNOM, '') as nomeRequisitante,
		A.NFSDESICMS as descontoIcms,
		ISNULL(B.NFSNFRCHA, '') as documentoReferenciado,
		
		ISNULL(NFSCONICMS, D.contribuinteIcms) as contribuinteIcms,
		ISNULL(NFSUFECALDIF, 0) as calculoDifal,
		0 AS codigoOperador

	INTO #CABECALHONOTASVENDA FROM TBS067 A (NOLOCK) 
		LEFT JOIN TBS0674 B (NOLOCK) ON
			A.NFSEMPCOD = B.NFSEMPCOD AND
			A.SNEEMPCOD = B.SNEEMPCOD AND
			A.SNESER = B.SNESER AND
			A.NFSNUM = B.NFSNUM AND
			B.NFSNFRTIP = 'CFE'
		INNER JOIN #VENDEDORES C (NOLOCK) ON
			A.VENEMPCOD = C.codigoEmpresa AND
			A.VENCOD = C.codigoVendedor
		INNER JOIN #CLIENTES D (NOLOCK) ON
			A.NFSCLIEMP = D.codigoEmpresa AND
			A.NFSCLICOD = D.codigo	
	WHERE 
		A.NFSEMPCOD = @empresaTBS067 AND 
		--A.NFSDATEMI BETWEEN @dataDe AND @dataAte AND
		(A.NFSDATEMI BETWEEN @dataDe AND @dataAte OR
		(@dataAte = (SELECT TOP 1 CONVERT(date, ENFLOGDEH) FROM TBS0803 B
						WHERE A.NFSNUM = B.ENFNUM AND A.SNESER = B.SNESER AND (ENFLOGCOD = 100 OR ENFLOGCOD = 136)
						ORDER BY ENFLOGDEH))) AND		
		A.NFSFINNFE = 1 AND -- somente as notas normais (nao entra as notas de complemento e nem ajuste)
		A.SNESER <> 2 AND -- tira as transferencias
		A.NFSENFSIT in(6, 13, 7) -- AND  -- as autorizadas e canceladas (pois no primeiro momento estava autorizada, depois cancelaram)	
	
	ORDER BY 
		A.NFSEMPCOD, 
		A.NFSDATEMI,
		A.SNESER,
		A.NFSENFSIT,
		A.NFSNUM		

--	SET STATISTICS TIME OFF; 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Contabilizar os cancelamentos de nota
	
	INSERT INTO #CABECALHONOTASVENDA
	
	SELECT 
		A.NFSEMPCOD as codigoEmpresa,
		A.NFSNUM as numeroDocumento,
		A.SNEEMPCOD as codigoEmpresaNumeroSerie,
		A.SNESER as numeroSerieDocumento,
		A.SEREMPCOD as codigoEmpresaSerie,
		A.SERCOD as codigoSerieDocumento,
		0 as caixa,		
		
		-- 'V' as tipoDocumento,
		A.NFSCLIEMP as codigoEmpresaCliente, 
		A.NFSCLICOD as codigoCliente,
		D.cgc,
		D.tipoPessoa,
		D.nomeCliente COLLATE DATABASE_DEFAULT as nomeCliente ,

		case WHEN A.NFSCLICOD IN (SELECT CODIGO FROM #CLIENTESGRUPO WHERE codigo <> @codigoDevolucao) -- cliente do grupo, indepENDente do vendedor, sempre vai contabilizar para o grupo
			THEN 'G'
			ELSE 
				case WHEN A.VENCOD IN(SELECT CODIGO FROM #VENDEDORESLOJA) -- vendedores do grupo de loja, contabiliza para a loja
					THEN 'L'
					ELSE 'C' -- vendedores diferente do grupo 2 e 6, mesmo que esteja sem vendedor, contabiliza para o corporativo.
				END 
		END as contabiliza,		
		'S' as cancelado,		
		(SELECT TOP 1 ENFCHAACE FROM TBS080 C (NOLOCK) WHERE C.ENFEMPCOD = @empresaTBS080 AND C.ENFNUM = A.NFSNUM AND C.SNEEMPCOD = A.SNEEMPCOD AND C.SNESER = A.SNESER) as chave,
		A.NFSDATCAN	as dataEmissao, -- pegarei a data de cancelamento
		ISNULL([dbo].[NotaSaidaHoraCancelamento](@empresaTBS080, A.NFSNUM, A.NFSDATCAN, A.SNEEMPCOD, A.SNESER), '18:59:59') as hora,
		A.UFESIG as uf,
		A.NFSMUNNOM as municipio,
		C.codigoEmpresaGrupoVendedor as codigoEmpresaGrupoVendedor,
		C.codigoGrupoVendedor as codigoGrupoVendedor,
		C.nomeGrupoVendedor COLLATE DATABASE_DEFAULT as nomeGrupoVendedor,
		C.codigoEmpresa as codigoEmpresaVendedor,
		A.VENCOD as codigoVendedor,
		C.nomeVendedor COLLATE DATABASE_DEFAULT as nomeVendedor,						
		ISNULL(A.NFSREQCOD, 0) as codigoRequisitante,		
		ISNULL(A.NFSREQNOM, '') as nomeRequisitante,
		A.NFSDESICMS as descontoIcms,
		ISNULL(B.NFSNFRCHA, '') as documentoReferenciado,		
		ISNULL(NFSCONICMS, D.contribuinteIcms) as contribuinteIcms,
		ISNULL(NFSUFECALDIF, 0) as calculoDifal,
		0 AS codigoOperador
	FROM TBS067 A (NOLOCK) 
		LEFT JOIN TBS0674 B (NOLOCK) ON
			A.NFSEMPCOD = B.NFSEMPCOD and
			A.SNEEMPCOD = B.SNEEMPCOD and
			A.SNESER = B.SNESER and
			A.NFSNUM = B.NFSNUM and
			B.NFSNFRTIP = 'CFE'
		INNER JOIN #VENDEDORES C (NOLOCK) ON
			A.VENEMPCOD = C.codigoEmpresa and
			A.VENCOD = C.codigoVendedor
		INNER JOIN #CLIENTES D (NOLOCK) ON
			A.NFSCLIEMP = D.codigoEmpresa and
			A.NFSCLICOD = D.codigo	
	WHERE 
		A.NFSEMPCOD = @empresaTBS067 AND 
		A.NFSDATCAN BETWEEN @dataDe AND @dataAte AND 
		A.NFSFINNFE = 1 AND -- somente as notas normais (n�o entra as notas de complemento e nem ajuste)
		A.SNESER <> 2 AND -- tira as transferencias
		A.NFSENFSIT = 7 -- AND  -- somente as canceladas
	
	ORDER BY 
		A.NFSEMPCOD,
		A.NFSDATEMI,
		A.SNESER,
		A.NFSENFSIT,
		A.NFSNUM

	-- ideia, contabilizar as notas de loja, depois contabilizar somente os cupons sem nota, mas podem querer ver o cupom que gerou a nota rs		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- Notas de saida de vendas
	
	IF OBJECT_ID('tempdb.dbo.#NOTASVENDA') IS NOT NULL
		DROP TABLE #NOTASVENDA;
	
	SELECT 
		A.*,		
		B.NFSITE as item, 
		B.PROEMPCOD as codigoEmpresaProduto,
		RTRIM(B.PROCOD) as codigoProduto,		
		case WHEN B.NFSQTDEMB = 0 THEN 0 ELSE B.NFSPRECUS END / case WHEN B.NFSQTDEMB = 0 THEN 1 ELSE B.NFSQTDEMB END as custoUnitario,				
		B.NFSQTD * B.NFSQTDEMB as quantidade,				
		[dbo].[NFSTOTITEST](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorTotal, -- alterdo dia 22/11/2021
		[dbo].[NFSVDDITE](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorDescontoTotal,		
		[dbo].[NFSVALICMSSTRET](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorIcmsSt, -- alterdo dia 22/11/2021
		[dbo].[NFSVALFCP](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorFcp,
		[dbo].[NFSFREITEVAL](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorFrete,
		[dbo].[NFSSEGITEVAL](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorSeguro,
		[dbo].[NFSDESITEVAL](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorOutrasDespesas,
		[dbo].[NFSTOTPRO](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) as valorProdutos,		
		CONVERT(decimal(11,4), ROUND(B.NFSQTD * B.NFSPRECUS,2)) as custoTotal,
		CONVERT(decimal(11,4), 
		[dbo].[NFSTOTITEST](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) +
		case WHEN descontoIcms = 'S' THEN [dbo].[NFSVDDITE](B.NFSEMPCOD, B.NFSNUM, B.SNEEMPCOD, B.SNESER, B.NFSITE) ELSE 0 END ) as valorSemDescontoIcms -- alterdo dia 22/11/2021
	
	INTO #NOTASVENDA FROM #CABECALHONOTASVENDA A (NOLOCK)
		INNER JOIN TBS0671 B (NOLOCK) ON 
			A.codigoEmpresa = B.NFSEMPCOD AND 
			A.numeroDocumento = B.NFSNUM AND 
			A.codigoEmpresaNumeroSerie = B.SNEEMPCOD AND 
			A.numeroSerieDocumento = B.SNESER	

	WHERE
		substring(B.NFSCFOP, 3, 3) COLLATE DATABASE_DEFAULT IN (SELECT CFOP FROM #CFOP_VENDAS WHERE tipo = 'S') or A.numeroSerieDocumento = 3	

	ORDER BY 
		B.NFSEMPCOD, 
		B.NFSNUM,
		B.SNEEMPCOD,
		B.SNESER,
		substring(B.NFSCFOP, 3, 3)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Cria a tabela temporaria global ##VendasNotas, com a mesma estrutura da tabela fisica DWVendas

	If OBJECT_ID('tempdb.dbo.##Vendas_Notas') IS NOT NULL
		DROP TABLE ##Vendas_Notas;

	SELECT TOP 0
		*
	INTO ##Vendas_Notas FROM DWVendas (NOLOCK)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
--	SET NOCOUNT OFF; -- Ativa a contagem de registros, para auxiliar quando fizermos testes executando diretamente a SP
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Utilizando CTE para incluir registros de vendas, e alimentar a tabela global ##Vendas_Notas, para ser usado em conjunto com a ##DWVendas	

	;WITH 
	vendas_notas AS(		
		SELECT 
			A.codigoEmpresa,
			A.numeroDocumento,
			A.codigoEmpresaNumeroSerie,
			A.numeroSerieDocumento,
			A.codigoEmpresaSerie,
			A.codigoSerieDocumento,
			A.caixa,
			A.codigoEmpresaCliente, 
			A.codigoCliente,
			A.cgc COLLATE DATABASE_DEFAULT AS cgc,
			A.tipoPessoa COLLATE DATABASE_DEFAULT AS tipoPessoa,	
			A.nomeCliente COLLATE DATABASE_DEFAULT AS nomeCliente,
			A.contabiliza COLLATE DATABASE_DEFAULT AS contabiliza,		
			A.cancelado COLLATE DATABASE_DEFAULT AS cancelado,
			A.chave COLLATE DATABASE_DEFAULT AS chave,
			A.dataEmissao,
			A.hora COLLATE DATABASE_DEFAULT AS hora,
			A.uf COLLATE DATABASE_DEFAULT AS uf,
			A.municipio COLLATE DATABASE_DEFAULT AS municipio,
			A.codigoEmpresaGrupoVendedor,
			A.codigoGrupoVendedor,
			A.nomeGrupoVendedor COLLATE DATABASE_DEFAULT AS nomeGrupoVendedor,
			A.codigoEmpresaVendedor,
			A.codigoVendedor,	
			A.nomeVendedor COLLATE DATABASE_DEFAULT AS nomeVendedor,
			A.codigoRequisitante,
			A.nomeRequisitante COLLATE DATABASE_DEFAULT AS nomeRequisitante,  
			A.descontoIcms,
			A.documentoReferenciado COLLATE DATABASE_DEFAULT AS documentoReferenciado,
			A.item, 
			A.codigoEmpresaProduto,
			A.codigoProduto COLLATE DATABASE_DEFAULT AS codigoProduto,
			B.descricaoProduto COLLATE DATABASE_DEFAULT AS descricaoProduto,
			B.codigoEmpresaMarca,
			B.codigoMarca,	
			B.nomeMarca COLLATE DATABASE_DEFAULT AS nomeMarca,
			B.unidade1 COLLATE DATABASE_DEFAULT AS unidade1,
			B.embalagem1,
			B.menorUnidadeVenda COLLATE DATABASE_DEFAULT AS menorUnidadeVenda,
			B.unidade2 COLLATE DATABASE_DEFAULT AS unidade2,
			B.embalagem2,
			B.codigoEmpresaGrupoProduto,
			B.codigoGrupo,
			B.nomeGrupo COLLATE DATABASE_DEFAULT AS nomeGrupo,
			B.codigoSubgrupo,
			B.nomeSubgrupo COLLATE DATABASE_DEFAULT AS nomeSubgrupo,
			ROUND(sum(A.valorTotal) / sum(A.quantidade), 4) as precoUnitario,
			avg(A.custoUnitario) as custoUnitario,
			sum(A.quantidade) as quantidade,
			sum(A.valorTotal) as valorTotal,
			sum(A.custoTotal) as custoTotal, 
			sum(A.valorDescontoTotal) as valorDescontoTotal,
			sum(A.valorIcmsSt) as valorIcmsSt,
			sum(A.valorFcp) as valorFcp,
			sum(A.valorFrete) as valorFrete,
			sum(A.valorSeguro) as valorSeguro,
			sum(A.valorOutrasDespesas) as valorOutrasDespesas,
			sum(A.valorProdutos) as valorProdutos, 
			sum(A.valorSemDescontoIcms) as valorSemDescontoIcms,
			case WHEN sum(custoTotal) > 0 AND sum(valorSemDescontoIcms) > 0 
				THEN ROUND( (1 - CONVERT(decimal(11,4),sum(custoTotal)) / CONVERT(decimal(11,4),sum(valorSemDescontoIcms)) ) * 100, 4)
				ELSE 0
			END margemLucro,
			case WHEN sum(custoTotal) > 0 AND sum(valorSemDescontoIcms) > 0 
				THEN ROUND( ( CONVERT(decimal(11,4),sum(custoTotal)) / CONVERT(decimal(11,4),sum(valorSemDescontoIcms)) ) * 100, 4)
				ELSE 0
			END divisaoLucro,
			case WHEN sum(custoTotal) > 0 AND sum(valorSemDescontoIcms) > 0 
				THEN ROUND(( CONVERT(decimal(11,4),CONVERT(decimal(11,4),sum(valorSemDescontoIcms)) - CONVERT(decimal(11,4),sum(custoTotal))) ) / ( CONVERT(decimal(11,4),sum(custoTotal)) / 100),4)
				ELSE 0
			END markup,		
			A.contribuinteIcms COLLATE DATABASE_DEFAULT AS contribuinteIcms,
			A.calculoDifal,
			A.codigoOperador,
			codigoGrupoSubGrupo
		FROM #NOTASVENDA A	
		INNER JOIN #PRODUTOS B ON
			A.codigoEmpresaProduto = B.codigoEmpresa AND
			A.codigoProduto COLLATE DATABASE_DEFAULT = B.codigo

		GROUP BY 
			A.codigoEmpresa,
			A.numeroDocumento,
			A.codigoEmpresaNumeroSerie,
			A.numeroSerieDocumento,
			A.codigoEmpresaSerie,
			A.codigoSerieDocumento,
			A.caixa,
			A.codigoEmpresaCliente, 
			A.codigoCliente,
			A.cgc COLLATE DATABASE_DEFAULT,
			A.tipoPessoa COLLATE DATABASE_DEFAULT,	
			A.nomeCliente,	
			A.contabiliza,		
			A.cancelado,		
			A.chave,
			A.dataEmissao,
			A.hora,
			A.uf,
			A.municipio,
			A.codigoEmpresaGrupoVendedor,
			A.codigoGrupoVendedor,
			A.nomeGrupoVendedor,
			A.codigoEmpresaVendedor,
			A.codigoVendedor,	
			A.nomeVendedor,			
			A.codigoRequisitante,
			A.nomeRequisitante, 
			A.descontoIcms,
			A.documentoReferenciado,
			A.item, 
			A.codigoEmpresaProduto,
			A.codigoProduto,
			B.descricaoProduto,
			B.codigoEmpresaMarca,
			B.codigoMarca,	
			B.nomeMarca,
			B.unidade1,
			B.embalagem1,
			B.menorUnidadeVenda,
			B.unidade2,
			B.embalagem2,
			B.codigoEmpresaGrupoProduto,
			B.codigoGrupo,
			B.nomeGrupo,
			B.codigoSubgrupo,
			B.nomeSubgrupo,
			A.contribuinteIcms, 
			A.calculoDifal,
			A.codigoOperador,
			codigoGrupoSubGrupo
		)
		-- Grava registros das vendas na tabela temporaria global, para ser mesclada com os dados da DWVendas e usadas nos relatorios do RS.
		INSERT INTO ##Vendas_Notas
		SELECT 
			* 
		FROM vendas_notas
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

END