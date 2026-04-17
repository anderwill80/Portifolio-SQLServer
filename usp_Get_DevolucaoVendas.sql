/*
====================================================================================================================================================================================
Coleta as informacoes de devolucao de vendas para "alimentar" a tabela ##Devolucao, para ser usada em relatorios em que o usuario queria dados do dia.
Nao ira mais gravar os dados do dia na DWDevolucaoVendas, para evitar as duplicaoes verificadas principalmente em Taubate, devido a execucao de relatorios com a data do dia.
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
22/04/2025 WILLIAM
	- Criacao, para permitir obter as devolucoes do dia, similiar ao "AlimentaDWDevolucaoVendas", obtendo dados da tabela de entrada TBS059, isso ira atender relatorios onde
	usuario escolhe a data do dia, onde anteriormente era feita a gravacao das vendas na DWDevolucaoVendas, porem ainda sim estava tendo duplicidade;
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_Get_DevolucaoVenda_DEBUG]
create PROC [dbo].[usp_Get_DevolucaoVendas]
	@empcod int,
	@pdataDe date = null,
	@pdataAte date = null
AS 
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date,
			@empresaTBS010 smallint, @empresaTBS014 smallint, @empresaTBS012 smallint, @empresaTBS004 smallint, @empresaTBS091 smallint,
			@empresaTBS002 smallint, @empresaTBS059 smallint,@empresaTBS067 smallint, @empresaTBS047 smallint, @empresaTBS080 smallint,			
			@nomeMunicipoEmpresa varchar(40), @temLoja bit,	@codigoDevolucao int, @dataModificacaoST datetime, 
			@sqlContabilizaGrupo varchar(4000), @hoje datetime, @municipioGz varchar(40),
			@empresaGzLoja int, @diasNaoContabilizados varchar(20), @contabilizaFeriados char(1), @GRUPOSVENDLOJA varchar(50);

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod	
	SET @dataDe = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pdataAte, GETDATE()));
		
-- Variaveis locais
	SET @nomeMunicipoEmpresa = (SELECT EMPMUNNOM FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa) -- serve para as devolu��es de cupom sem nota de saida
	SET @temLoja = dbo.ufn_Get_TemFrenteLoja(@codigoEmpresa);
	SET @codigoDevolucao = CONVERT(INT, dbo.ufn_Get_Parametro(1330));
	SET @dataModificacaoST = CONVERT(date, GETDATE()); -- Quando for colocado em vigor a alteração no ST, preciso colocar aqui a data do dia anterior a mudança	
	SET @empresaGzLoja = IIF(@temLoja = 'TRUE', CONVERT(INT, dbo.ufn_Get_Parametro(1431)), 0);
	SET @municipioGz = IIF(@temLoja = 'TRUE', @nomeMunicipoEmpresa, '');
	SET @GRUPOSVENDLOJA = RTRIM(LTRIM(dbo.ufn_Get_Parametro(1531)))	

-- Verificar se a tabela compartilhada ou exclusiva			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS014', @empresaTBS014 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS012', @empresaTBS012 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS091', @empresaTBS091 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @empresaTBS080 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS067', @empresaTBS067 output;

-- Uso da funcao fSplit(), para gerar tabelas multivalores
	IF OBJECT_ID('tempdb.dbo.#MV_GVL') IS NOT NULL
		DROP TABLE #MV_GVL;
	SELECT 
		elemento as valor
	INTO #MV_GVL FROM fSplit(@GRUPOSVENDLOJA, ',');
	IF( @GRUPOSVENDLOJA = '' )
		DELETE #MV_GVL;		

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrar os produtos na TBS010, se n�o existe produto na TBS010 não tem porque existir nas outras
		
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
		ISNULL(RTRIM(C.SUBGRUDES),'') as nomeSubgrupo	
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
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- CFOP que contabiliza as vendas e as devoluções de vendas

	IF OBJECT_ID('tempdB.dbo.#CONTABILIZACOMPRADEVOLUCAO') IS NOT NULL
		DROP TABLE #CONTABILIZACOMPRADEVOLUCAO;
	   
	CREATE TABLE #CONTABILIZACOMPRADEVOLUCAO (CFOP CHAR(3), TIPO CHAR(1))
	
	-- Entrada de devolucao	
	INSERT INTO #CONTABILIZACOMPRADEVOLUCAO VALUES ('201', 'D') -- devolucao DE VENDA DE PRODU��O DO ESTABELECIMENTO (N�O DEVERIA USAR)
	INSERT INTO #CONTABILIZACOMPRADEVOLUCAO VALUES ('202', 'D') -- devolucao DE VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIRO
	INSERT INTO #CONTABILIZACOMPRADEVOLUCAO VALUES ('411', 'D') -- devolucao DE VENDA DE MERCADORIA ADQUIRIDA OU RECEBIDA DE TERCEIROS EM OPERA��O COM MERCADORIA SUJEITA AO REGIME DE SUBSTITUIçãO TRIBUTáRIA
	INSERT INTO #CONTABILIZACOMPRADEVOLUCAO VALUES ('918', 'D') -- devolucao DE MERCADORIA REMETIDA EM CONSIGNA��O MERCANTIL OU INDUSTRIAL
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Tabela dos vendedores - Para as devolu��es

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
		LEFT JOIN TBS091 B (NOLOCK) on B.GVEEMPCOD = ISNULL(@empresaTBS091, 0) AND A.GVECOD = B.GVECOD AND A.GVEEMPCOD = B.GVEEMPCOD
	
	WHERE
		VENEMPCOD = @empresaTBS004 	

	ORDER BY 
		A.VENEMPCOD, 
		A.VENCOD
	
	-- inserir vendedor com o codigo 0, para as notas sem vendedor	
	INSERT #VENDEDORES VALUES(@empresaTBS004, 0, '', ISNULL(@empresaTBS091, 0), 0, '')

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
	-- Clientes - para as devolucoes Do grupo 
	
	IF OBJECT_ID('tempdB.dbo.#CLIENTESGRUPO') IS NOT NULL
		DROP TABLE #CLIENTESGRUPO;
	
	CREATE TABLE #CLIENTESGRUPO (CODIGO int)
	
	INSERT INTO #CLIENTESGRUPO	
	EXEC usp_Get_CodigosClientesGrupo @codigoempresa

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os dados dos clientes

	IF OBJECT_ID('tempdB.dbo.#CLIENTES') IS NOT NULL
		DROP TABLE #CLIENTES;
	
	SELECT
		CLIEMPCOD as codigoEmpresa,
		CLICOD as codigo,
		case WHEN CLITIPPES = 'J'
			THEN RTRIM(CLICGC) 
			ELSE RTRIM(CLICPF)
		END as cgc,
		CLITIPPES as tipoPessoa,
		RTRIM(CLINOM) as nomeCliente
	INTO #CLIENTES FROM TBS002 (NOLOCK)
	
	WHERE 
		CLIEMPCOD = @empresaTBS002
	
	ORDER BY
		CLIEMPCOD, 
		CLICOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- Compras e Devolucoes
	
	-- N�o poder ser contabilizado um vendedor que fez uma nota de cupom, se essa nota de saida n�o est� autorizadA.
	-- Tem que ser considerado como zero, e se foi devolucao de cupom com vendedor zero, deve-se contabilizar devolucao de loja
	-- Tenho que achar item por item, qual o valor do custo unitario do produto devolvido, pois pode haver dois itens iguais na nota de saida com pre�os de custo diferente.
	-- Se devolucao de cupom preciso agrupar os itens, pois os pre�os e custos n�o mudam.
	-- Tenho que separar dev de cupom e dev de nota, pois na dev de cupom o custo do produto nao muda, mas na dev de nota, pode haver custos diferente para o mesmo produto.
		
	-- Cabe�alhos das notas de compras e devolucao
	
	IF OBJECT_ID('tempdB.dbo.#CABECALHOCOMPRADEVOLUCAO') IS NOT NULL	
		DROP TABLE #CABECALHOCOMPRADEVOLUCAO;
	
	SELECT 
		A.NFEEMPCOD as codigoEmpresa,
		NFENUM as numeroDocumento,
		0 as codigoEmpresaNumeroSerie,
		A.NFESERDOC as numeroSerieDocumento,
		SEREMPCOD as codigoEmpresaSerie,
		'NFD' as codigoSerieDocumento,
		-- 0 as caixa,
		
		@empresaTBS002 as codigoEmpresaCliente,
		A.NFECOD as codigoCliente,
		B.cgc as cgc,
		B.tipoPessoa,
		B.nomeCliente COLLATE DATABASE_DEFAULT as nomeCliente,
		
		NFETIP as tipoDocumento,
		'N' as cancelado,
		A.NFECHAACE as chaveAcesso,
		A.NFEDATEFE as dataEfetivacao,
		A.NFEHOREFE as horaEfetivacao,
		A.NFEESTORI as estado,		
		-- chave documento auxiliar, pegar posteriormente
		A.NFETIPENT as tipoEntrada -- servir� para fazer as amarra��es no cupom ou na nota de saida 	
	INTO #CABECALHOCOMPRADEVOLUCAO	FROM TBS059 A (NOLOCK) 	
		INNER JOIN #CLIENTES B (NOLOCK) ON
			A.NFECOD = B.codigo

	WHERE 
		A.NFEEMPCOD = @empresaTBS059 AND 
		A.NFEDATEFE BETWEEN @dataDe AND @dataAte AND
		A.NFETIP = 'D'

	ORDER BY 
		A.NFEEMPCOD, 
		A.NFEDATEFE,
		A.NFETIP,
		A.NFECOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- Pagar as devolu��es canceladas 
	
	INSERT #CABECALHOCOMPRADEVOLUCAO
	
	SELECT 
		A.NFEEMPCOD as codigoEmpresa,
		NFENUM as numeroDocumento,
		0 as codigoEmpresaNumeroSerie,
		A.NFESERDOC as numeroSerieDocumento,
		SEREMPCOD as codigoEmpresaSerie,
		'CAN' as codigoSerieDocumento,		
		@empresaTBS002 as codigoEmpresaCliente,
		A.NFECOD as codigoCliente,
		B.cgc as cgc,
		B.tipoPessoa,
		B.nomeCliente COLLATE DATABASE_DEFAULT as nomeCliente,				
		NFETIP as tipoDocumento,
		'S' as cancelado,
		A.NFECHAACE as chaveAcesso,
		A.NFEDATCAN as dataCancelamento,
		A.NFEHORCAN as horaCancelamento,
		A.NFEESTORI as estado,		
		-- chave documento auxiliar, pegar posteriormente
		A.NFETIPENT as tipoEntrada -- servirá para fazer as amarrações no cupom ou na nota de saida 
	FROM TBS059 A (NOLOCK)
		INNER JOIN #CLIENTES B (NOLOCK) ON
			A.NFECOD = B.codigo 

	WHERE
		A.NFEEMPCOD = @empresaTBS059 AND 
		A.NFEDATCAN BETWEEN @dataDe AND @dataAte AND
		A.NFECAN = 'S' AND
		A.NFETIP = 'D'

	ORDER BY 
		A.NFEEMPCOD, 
		A.NFEDATEFE,
		A.NFETIP,
		A.NFECOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Compras e devolucao de notas de entrada	
	
	IF OBJECT_ID('tempdb.dbo.#DEVOLUCAONOTASSAIDA') IS NOT NULL
		DROP TABLE #DEVOLUCAONOTASSAIDA;
	
	SELECT
		A.*,
		ISNULL(D.NFSMUNNOM, '') as municipio,		
		--CASE WHEN A.tipoEntrada = 'DEV'
			--THEN
				CASE WHEN A.codigoCliente IN (select codigo FROM #ClientesGrupo WHERE codigo <> @codigoDevolucao) -- cliente do grupo, independente do vendedor, sempre vai contabilizar para o grupo
					THEN 'G'
					ELSE 
						CASE WHEN C.codigoVendedor IN(SELECT CODIGO FROM #VENDEDORESLOJA) -- or (A.tipoEntrada = 'CUP' AND B.NFENFSVENCOD = 0) -- vendedores do grupo de loja ou devolução de cupom (CUP) que não tenha vendedor atrelado, contabiliza para a loja
							THEN 'L'
							ELSE 'C' -- vendedores diferente do grupo 2, mesmo que seja uma devolução para a propria empresa, contabiliza para o corporativo. Lembrando que, o vendedor 0 é considerado sem grupo (0), logo diferente do grupo 2, desde que não seja uma devolução para a própria empresa, será contabilizado para o corporativo.
						END 
				END as contabiliza,						
		B.NFENFSNUM as numeroDocumentoAuxiliar,
		0 as numeroCaixaAuxiliar,		
		B.NFESNESER as serieDocumentoAuxiliar,	
		B.NFENFSITE as itemDocumentoAuxiliar, -- serve para as notas sem cupons, quando tiver cupom � 0			
		-- data emiss�o do documento auxiliar, pegar posteriormente		
		C.codigoEmpresaGrupoVendedor as codigoEmpresaGrupoVendedor,
		C.codigoGrupoVendedor as codigoGrupoVendedor,
		C.nomeGrupoVendedor COLLATE DATABASE_DEFAULT as nomeGrupoVendedor,
		C.codigoEmpresa as codigoEmpresaVendedor,
		C.codigoVendedor as codigoVendedor,
		C.nomeVendedor COLLATE DATABASE_DEFAULT as nomeVendedor,		
		ISNULL(D.NFSREQCOD,0) as codigoRequisitante,
		ISNULL(D.NFSREQNOM,'') as nomeRequisitante,
		ISNULL(D.NFSDESICMS, 'N') as descontoIcms,
		ISNULL((SELECT TOP 1 ENFCHAACE FROM TBS080 E (NOLOCK) WHERE E.ENFEMPCOD = @empresaTBS080 AND E.ENFNUM = B.NFENFSNUM AND E.SNESER = B.NFESNESER), '') AS documentoReferenciado,
		B.PROEMPCOD as codigoEmpresaProduto,
		B.PROCOD as codigoProduto,
		B.NFEQTD * B.NFEQTDEMB as quantidade,		
		CASE WHEN B.NFEQTD <> 0
			THEN CONVERT(decimal(11,4), B.NFETOTOPEITE / (B.NFEQTD * CASE WHEN B.NFEQTDEMB = 0 THEN 1 ELSE B.NFEQTDEMB END))
			ELSE 0
		END as precoUnitario,
		
		(SELECT TOP 1 CASE WHEN NFSQTDEMB = 0 THEN 0 ELSE NFSPRECUS END / CASE WHEN NFSQTDEMB = 0 THEN 1 ELSE NFSQTDEMB END		
			FROM TBS0671 E (NOLOCK) 
		
			WHERE
				E.NFSEMPCOD = @empresaTBS067 AND 
				E.NFSNUM = B.NFENFSNUM AND 
				E.SNESER = B.NFESNESER AND 
				E.NFSITE = B.NFENFSITE 
			
			ORDER BY 
				E.NFSEMPCOD,
				E.NFSNUM,
				E.SNESER, 
				E.NFSITE) as custoUnitario,		
		ROUND(B.NFETOTOPEITE,2) as valorTotal,
		ROUND(B.NFEVALDESITE,2) as valorDescontoTotal,
		ROUND(B.NFEVALICMSST,2) as valorIcmsSt,
		ROUND(B.NFEVALFREITE,2) as valorFrete,
		ROUND(B.NFEVALSEGITE,2) as valorSeguro,
		ROUND(B.NFEVALOUTDES,2) as valorOutrasDespesas,
		ROUND(B.NFEPRE * (B.NFEQTD * B.NFEQTDEMB),2) as valorProdutos,		
		CONVERT(decimal(11,4), ROUND(B.NFETOTOPEITE,2) + 
		CASE WHEN ISNULL(D.NFSDESICMS, 'N') = 'S' THEN ROUND(B.NFEVALDESITE,2) ELSE 0 END ) as valorSemDescontoIcms
	
	INTO #DEVOLUCAONOTASSAIDA FROM #CABECALHOCOMPRADEVOLUCAO A (NOLOCK) 
		INNER JOIN TBS0591 B (NOLOCK) ON
			A.codigoEmpresa = B.NFEEMPCOD AND 
			A.tipoDocumento COLLATE DATABASE_DEFAULT = B.NFETIP AND 
			A.numeroDocumento = B.NFENUM AND 
			A.codigoCliente = B.NFECOD AND 
			A.codigoEmpresaSerie = B.SEREMPCOD AND 
			A.codigoSerieDocumento COLLATE DATABASE_DEFAULT IN(B.SERCOD, 'NFD') 			
		INNER JOIN  #VENDEDORES C (NOLOCK) ON
			B.NFENFSVENCOD = C.codigoVendedor 		
		LEFT JOIN TBS067 D (NOLOCK) ON 
			B.NFESNESER = D.SNESER AND 
			B.NFENFSNUM = D.NFSNUM
	
	WHERE
		A.tipoEntrada COLLATE DATABASE_DEFAULT = 'DEV' AND
		substring(B.NFECFOP, 3, 3) COLLATE DATABASE_DEFAULT IN (select cfop FROM #ContabilizaCompraDevolucao WHERE tipo = 'D') AND 
		B.PROCOD COLLATE DATABASE_DEFAULT IN (select codigo FROM #PRODUTOS)
	
	ORDER BY
		A.codigoEmpresa, 
		A.dataEfetivacao,
		B.NFETIP,
		B.NFECOD,
		B.PROCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------			
	-- devolucao de cupons
	
	IF OBJECT_ID('tempdb.dbo.#DEVOLUCAOCUPOM1') IS NOT NULL	
		DROP TABLE #DEVOLUCAOCUPOM1;
	
	SELECT 
		A.*,		
		CASE WHEN A.tipoEntrada = 'CUP'
			THEN ISNULL((SELECT TOP 1 C.municipio FROM movcaixagz C (NOLOCK) WHERE C.loja = @empresaGzLoja AND status = '03' AND C.sitnf = 6 AND B.NFENUMCUP = C.cupom AND B.NFENUMCXA = C.caixa order by loja, status, caixa, cupom), @nomeMunicipoEmpresa)
			ELSE ''
		END as municipio,
				
		CASE WHEN A.codigoCliente IN (SELECT codigo FROM #CLIENTESGRUPO WHERE codigo <> @codigoDevolucao) -- cliente do grupo, independente do vendedor, sempre vai contabilizar para o grupo
			THEN 'G'
			ELSE 
				CASE WHEN C.codigoVendedor IN(SELECT CODIGO FROM #VENDEDORESLOJA) OR (A.tipoEntrada = 'CUP' AND B.NFENFSVENCOD = 0) -- vendedores do grupo de loja ou devolucao de cupom (CUP) que não tenha vendedor atrelado, contabiliza para a loja
					THEN 'L'
					ELSE 'C' -- vendedores diferente do grupo 2, mesmo que seja uma devolucao para a propria empresa, contabiliza para o corporativo. Lembrando que, o vendedor 0 é considerado sem grupo (0), logo diferente do grupo 2, desde que não seja uma devolução para a própria empresa, será contabilizado para o corporativo.
				END 
		END as contabiliza,		
		B.NFENUMCUP as numeroDocumentoAuxiliar,
		B.NFENUMCXA as numeroCaixaAuxiliar,		
		B.NFESNESER as serieDocumentoAuxiliar,			
		-- data emissão do documento auxiliar, pegar posteriormente		
		C.codigoEmpresaGrupoVendedor as codigoEmpresaGrupoVendedor,
		C.codigoGrupoVendedor as codigoGrupoVendedor,
		C.nomeGrupoVendedor COLLATE DATABASE_DEFAULT as nomeGrupoVendedor,
		C.codigoEmpresa as codigoEmpresaVendedor,
		C.codigoVendedor as codigoVendedor,
		C.nomeVendedor COLLATE DATABASE_DEFAULT as nomeVendedor,		
		ISNULL((SELECT TOP 1 C.nfce_chave FROM movcaixagz C (NOLOCK) WHERE C.loja = @empresaGzLoja AND  status = '03' AND B.NFENUMCUP = C.cupom AND B.NFENUMCXA = C.caixa order by loja, status, caixa, cupom), '') as documentoReferenciado,
		B.PROEMPCOD as codigoEmpresaProduto,
		B.PROCOD as codigoProduto,
		B.NFEQTD * B.NFEQTDEMB as quantidade,				
		ISNULL((select top 1 C.precocusto FROM movcaixagz C (NOLOCK) WHERE C.loja = @empresaGzLoja AND status = '01' AND B.NFENUMCUP = C.cupom AND B.NFENUMCXA = C.caixa AND B.PROCOD COLLATE DATABASE_DEFAULT = C.cdprod order by loja, status, caixa, cupom), 0) as custoUnitario,		
		ROUND(B.NFETOTOPEITE,2) as valorTotal,		
		ROUND(B.NFEVALDESITE,2) as valorDescontoTotal,
		ROUND(B.NFEVALICMSST,2) as valorIcmsSt,
		ROUND(B.NFEVALFREITE,2) as valorFrete,
		ROUND(B.NFEVALSEGITE,2) as valorSeguro,
		ROUND(B.NFEVALOUTDES,2) as valorOutrasDespesas,
		ROUND(B.NFEPRE * (B.NFEQTD * B.NFEQTDEMB),2) as valorProdutos		
	INTO #DEVOLUCAOCUPOM1 FROM #CABECALHOCOMPRADEVOLUCAO A (NOLOCK) 
		INNER JOIN TBS0591 B (NOLOCK) ON
			A.codigoEmpresa = B.NFEEMPCOD AND 
			A.tipoDocumento = B.NFETIP AND 
			A.numeroDocumento = B.NFENUM AND 
			A.codigoCliente = B.NFECOD AND 
			A.codigoEmpresaSerie = B.SEREMPCOD AND 
			A.codigoSerieDocumento IN(B.SERCOD, 'NFD')
		INNER JOIN #VENDEDORES C (NOLOCK) ON
			B.NFENFSVENCOD = C.codigoVendedor
	
	WHERE
		A.tipoEntrada COLLATE DATABASE_DEFAULT = 'CUP' AND -- devolucao de cupom 
		substring(B.NFECFOP, 3, 3) COLLATE DATABASE_DEFAULT IN (select cfop FROM #ContabilizaCompraDevolucao WHERE tipo = 'D') AND 
		B.PROCOD COLLATE DATABASE_DEFAULT IN (select codigo FROM #PRODUTOS)
	
	ORDER BY 
		A.codigoEmpresa, 
		A.dataEfetivacao,
		B.NFETIP,
		B.NFECOD,
		B.PROCOD
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- devolucao de cupom precisa ser agrupado, pois pode haver o mesmo item no cupom, e como o custo s�o sempre o mesmo, n�o tem problema fazer o agrupamento
	
	IF OBJECT_ID('tempdb.dbo.#DEVOLUCAOCUPOM2') IS NOT NULL
		DROP TABLE #DEVOLUCAOCUPOM2;
	
	SELECT
		A.codigoEmpresa,
		A.numeroDocumento,
		A.codigoEmpresaNumeroSerie,
		A.numeroSerieDocumento,
		A.codigoEmpresaSerie,
		A.codigoSerieDocumento,
		-- A.caixa,
		A.codigoEmpresaCliente,
		A.codigoCliente,
		A.cgc,
		A.tipoPessoa,
		A.nomeCliente,	
		A.tipoDocumento,
		cancelado,
		chaveAcesso,
		dataEfetivacao,
		horaEfetivacao,
		estado,
		tipoEntrada,
		municipio,
		contabiliza,
		numeroDocumentoAuxiliar,
		numeroCaixaAuxiliar,
		serieDocumentoAuxiliar,	
		0 as itemDocumentoAuxiliar, -- serve para as notas sem cupons, quando tiver cupom ser� 0	
		codigoEmpresaGrupoVendedor,
		codigoGrupoVendedor,
		nomeGrupoVendedor,
		codigoEmpresaVendedor,
		codigoVendedor,
		nomeVendedor,
		documentoReferenciado,
		A.codigoEmpresaProduto,
		A.codigoProduto,
		SUM(quantidade) as quantidade,
		ROUND(SUM(valorTotal) / SUM(quantidade),5) as precoUnitario, -- pode haver o mesmo item , com quantidades diferente, que tem desconto em % iguais, porem o media do pre�o (AVG) fica diferente, exemplo nf 4794
		AVG(custoUnitario) as custoUnitario,	
		SUM(valorTotal) as valorTotal,
		SUM(valorDescontoTotal) as valorDescontoTotal,
		SUM(valorIcmsSt) as valorIcmsSt,
		SUM(valorFrete) as valorFrete,
		SUM(valorSeguro) as valorSeguro,
		SUM(valorOutrasDespesas) as valorOutrasDespesas,
		SUM(valorProdutos) as valorProdutos		
	INTO #DEVOLUCAOCUPOM2 FROM #DEVOLUCAOCUPOM1 A
				
	GROUP BY
		A.codigoEmpresa,
		A.numeroDocumento,
		A.codigoEmpresaNumeroSerie,
		A.numeroSerieDocumento,
		A.codigoEmpresaSerie,
		A.codigoSerieDocumento,
		A.codigoEmpresaCliente,
		A.codigoCliente,
		A.cgc,
		A.tipoPessoa,
		A.nomeCliente,
		A.tipoDocumento,
		cancelado,
		chaveAcesso,
		dataEfetivacao,
		horaEfetivacao,
		estado,
		tipoEntrada,
		contabiliza,
		municipio,
		numeroDocumentoAuxiliar,
		numeroCaixaAuxiliar,
		serieDocumentoAuxiliar,	
		codigoEmpresaGrupoVendedor,
		codigoGrupoVendedor,
		nomeGrupoVendedor,
		codigoEmpresaVendedor,
		codigoVendedor,
		nomeVendedor,
		documentoReferenciado,
		A.codigoEmpresaProduto,
		A.codigoProduto
		
	ORDER BY
		A.codigoEmpresa,
		dataEfetivacao + horaEfetivacao,
		A.codigoProduto
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Existem notas de saida de serie 3 que foram devolvidas, o que fazer??
	-- Criar um select contendo os mesmos campos da tabela #DevolucaoNotasSaida, porem alterando os campos de tipoEntrada, numeroAux, serieAux, itemAux, agrupando os codigos
	-- Depois excluir as notas de serie 3 da tab #DevolucaoNotasSaida e colocar os itens dessa tabela #DevolucaoSerie3 na tabela de #DevolucaoCupom

	IF OBJECT_ID('tempdb.dbo.#DEVOLUCAOSERIE3') IS NOT NULL
		DROP TABLE #DEVOLUCAOSERIE3;
	
	SELECT 
		A.codigoEmpresa,
		A.numeroDocumento,
		A.codigoEmpresaNumeroSerie,
		A.numeroSerieDocumento,
		A.codigoEmpresaSerie,
		A.codigoSerieDocumento,
		A.codigoEmpresaCliente,
		A.codigoCliente,
		A.cgc,
		A.tipoPessoa,
		A.nomeCliente,
		A.tipoDocumento,
		A.cancelado,
		A.chaveAcesso,
		A.dataEfetivacao,
		A.horaEfetivacao,
		A.estado,
		'CUP' as tipoEntrada,
		A.municipio,
		A.contabiliza,
		B.cupom as numeroDocumentoAuxiliar,
		B.caixa	as numeroCaixaAuxiliar,
		0 as serieDocumentoAuxiliar,	
		0 as itemDocumentoAuxiliar, -- s� serve para as notas sem cupons, quando tiver cupom ser� 0	
		A.codigoEmpresaGrupoVendedor,
		A.codigoGrupoVendedor,
		A.nomeGrupoVendedor,
		A.codigoEmpresaVendedor,
		A.codigoVendedor,
		A.nomeVendedor,
		B.nfce_chave as documentoReferenciado,
		A.codigoEmpresaProduto,
		A.codigoProduto,
		SUM(A.quantidade) as quantidade,
		ROUND(AVG(A.precoUnitario),4) as precoUnitario,	
		ISNULL(AVG(A.custoUnitario), 0) as custoUnitario,	
		SUM(A.valorTotal) as valorTotal,
		SUM(A.valorDescontoTotal) as valorDescontoTotal,
		SUM(A.valorIcmsSt) as valorIcmsSt,
		SUM(A.valorFrete) as valorFrete,
		SUM(A.valorSeguro) as valorSeguro,
		SUM(A.valorOutrasDespesas) as valorOutrasDespesas,
		SUM(A.valorProdutos) as valorProdutos		
	INTO #DEVOLUCAOSERIE3 FROM #DEVOLUCAONOTASSAIDA A
		INNER JOIN movcaixagz B (NOLOCK) ON
			A.serieDocumentoAuxiliar = B.serienf AND 
			A.numeroDocumentoAuxiliar = B.numeronf AND 
			A.codigoProduto COLLATE DATABASE_DEFAULT = B.cdprod AND -- tem item 1 que tem codigo vaazio, ou seja, � um finalizador
			A.itemDocumentoAuxiliar = B.item
			
	WHERE 
		B.loja = @empresaGzLoja	AND 
		B.status = '01' AND -- assim n�o entra possiveis itens cancelados, que talvez tenho o mesmo numero de item e codigo que foi devolvido
		serieDocumentoAuxiliar = 3 
	
	GROUP BY 
		A.codigoEmpresa,
		A.numeroDocumento,
		A.codigoEmpresaNumeroSerie,
		A.numeroSerieDocumento,
		A.codigoEmpresaSerie,
		A.codigoSerieDocumento,
		A.codigoEmpresaCliente,
		A.codigoCliente,
		A.cgc,
		A.tipoPessoa,
		A.nomeCliente,
		A.tipoDocumento,
		A.cancelado,
		A.chaveAcesso,
		A.dataEfetivacao,
		A.horaEfetivacao,
		A.estado,
		A.tipoEntrada,
		A.municipio,
		A.contabiliza,
		B.cupom,
		B.caixa,
		A.codigoEmpresaGrupoVendedor,
		A.codigoGrupoVendedor,
		A.nomeGrupoVendedor,
		A.codigoEmpresaVendedor,
		A.codigoVendedor,
		A.nomeVendedor,
		B.nfce_chave,
		A.codigoEmpresaProduto,
		A.codigoProduto
		
	ORDER BY 
		codigoEmpresa,
		dataEfetivacao + horaEfetivacao,
		codigoProduto
				
	DELETE #DEVOLUCAONOTASSAIDA 
	WHERE
		serieDocumentoAuxiliar = 3
	
	INSERT #DEVOLUCAOCUPOM2
	select * FROM #DEVOLUCAOSERIE3
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Pegar informa��es do cupom e da nota gerada pelo cupom
	
	IF OBJECT_ID('tempdb.dbo.#NOTASCUPOM') IS NOT NULL 
		DROP TABLE #NOTASCUPOM;
	
	SELECT 
		codigoEmpresa,
		numeroDocumento,
		codigoEmpresaNumeroSerie,
		numeroSerieDocumento,
		codigoEmpresaSerie,
		codigoSerieDocumento,
		-- caixa,
		codigoEmpresaCliente,
		codigoCliente,
		A.cgc,
		tipoPessoa,
		nomeCliente,
		tipoDocumento,
		codigoEmpresaProduto,
		codigoProduto,
		ISNULL(C.NFSREQCOD,0) as codigoRequisitante,
		ISNULL(C.NFSREQNOM,'') as nomeRequisitante,
		ISNULL(C.NFSDESICMS, 'N') as descontoIcms
	INTO #NOTASCUPOM FROM #DEVOLUCAOCUPOM2 A
		INNER JOIN movcaixagz B (NOLOCK) ON
			B.loja = @empresaGzLoja AND 
			B.caixa = A.numeroCaixaAuxiliar AND 
			B.cupom = A.numeroDocumentoAuxiliar AND 
			B.status = '03'	
		LEFT JOIN TBS067 C (NOLOCK) ON 
			C.NFSEMPCOD = @empresaTBS067 AND
			B.serienf = C.SNESER AND 
			B.numeronf = C.NFSNUM 
	
	GROUP BY 
		codigoEmpresa,
		numeroDocumento,
		codigoEmpresaNumeroSerie,
		numeroSerieDocumento,
		codigoEmpresaSerie,
		codigoSerieDocumento,
		codigoEmpresaCliente,
		codigoCliente,
		A.cgc,
		tipoPessoa,
		nomeCliente,
		tipoDocumento,
		codigoEmpresaProduto,
		codigoProduto,
		ISNULL(C.NFSREQCOD,0),
		ISNULL(C.NFSREQNOM,''),
		ISNULL(C.NFSDESICMS, 'N')
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Colocar as informa��es de requisitante das notas gerada pelo cupom
	
	IF OBJECT_ID('tempdb.dbo.#DEVOLUCAOCUPOM') IS NOT NULL
		DROP TABLE #DEVOLUCAOCUPOM;
	
	SELECT
		A.codigoEmpresa,
		A.numeroDocumento,
		A.codigoEmpresaNumeroSerie,
		A.numeroSerieDocumento,
		A.codigoEmpresaSerie,
		A.codigoSerieDocumento COLLATE DATABASE_DEFAULT as codigoSerieDocumento,
		A.codigoEmpresaCliente,
		A.codigoCliente,
		A.cgc COLLATE DATABASE_DEFAULT as cgc,
		A.tipoPessoa COLLATE DATABASE_DEFAULT as tipoPessoa,
		A.nomeCliente COLLATE DATABASE_DEFAULT as nomeCliente,
		A.tipoDocumento COLLATE DATABASE_DEFAULT as tipoDocumento,
		cancelado COLLATE DATABASE_DEFAULT as cancelado,
		chaveAcesso COLLATE DATABASE_DEFAULT as chaveAcesso,
		dataEfetivacao,
		horaEfetivacao COLLATE DATABASE_DEFAULT as horaEfetivacao,
		estado COLLATE DATABASE_DEFAULT as estado,
		tipoEntrada COLLATE DATABASE_DEFAULT as tipoEntrada,
		municipio COLLATE DATABASE_DEFAULT as municipio,
		contabiliza COLLATE DATABASE_DEFAULT as contabiliza,
		numeroDocumentoAuxiliar,
		numeroCaixaAuxiliar,
		serieDocumentoAuxiliar,	
		0 as itemDocumentoAuxiliar, -- serve para as notas sem cupons, quando tiver cupom ser� 0	
		codigoEmpresaGrupoVendedor,
		codigoGrupoVendedor,
		nomeGrupoVendedor COLLATE DATABASE_DEFAULT as nomeGrupoVendedor,
		codigoEmpresaVendedor,
		codigoVendedor,
		nomeVendedor COLLATE DATABASE_DEFAULT as nomeVendedor,
		ISNULL(B.codigoRequisitante,0) as codigoRequisitante,
		ISNULL(B.nomeRequisitante,'') COLLATE DATABASE_DEFAULT as nomeRequisitante,
		ISNULL(B.descontoIcms, 'N') COLLATE DATABASE_DEFAULT as descontoIcms,
		A.documentoReferenciado COLLATE DATABASE_DEFAULT as documentoReferenciado,
		A.codigoEmpresaProduto,
		A.codigoProduto COLLATE DATABASE_DEFAULT as codigoProduto,
		SUM(quantidade) as quantidade,
		ROUND(SUM(valorTotal) / SUM(quantidade),5) as precoUnitario, -- pode haver o mesmo item , com quantidades diferente, que tem desconto em % iguais, porem o media do pre�o (AVG) fica diferente, exemplo nf 4794
		ISNULL(AVG(custoUnitario), 0) as custoUnitario,		
		SUM(A.valorTotal) as valorTotal,
		SUM(A.valorDescontoTotal) as valorDescontoTotal,
		SUM(A.valorIcmsSt) as valorIcmsSt,
		SUM(A.valorFrete) as valorFrete,
		SUM(A.valorSeguro) as valorSeguro,
		SUM(A.valorOutrasDespesas) as valorOutrasDespesas,
		SUM(A.valorProdutos) as valorProdutos,
		
		CONVERT(decimal(11,4), SUM(A.valorTotal) + 
		CASE WHEN ISNULL(B.descontoIcms, 'N') = 'S' THEN SUM(A.valorDescontoTotal) ELSE 0 END ) as valorSemDescontoIcms
	
	INTO #DEVOLUCAOCUPOM FROM #DEVOLUCAOCUPOM2 A
		LEFT JOIN #NOTASCUPOM B ON
			A.codigoEmpresa = B.codigoEmpresa AND 
			A.numeroDocumento = B.numeroDocumento AND 
			A.codigoEmpresaNumeroSerie = B.codigoEmpresaNumeroSerie AND
			A.numeroSerieDocumento = B.numeroSerieDocumento AND
			A.codigoEmpresaSerie = B.codigoEmpresaSerie AND
			A.codigoSerieDocumento = B.codigoSerieDocumento AND		
			A.codigoEmpresaCliente = B.codigoEmpresaCliente AND
			A.codigoCliente = B.codigoCliente AND
			A.tipoDocumento = B.tipoDocumento AND
			A.codigoEmpresaProduto = B.codigoEmpresaProduto AND
			A.codigoProduto = B.codigoProduto
		
	GROUP BY
		A.codigoEmpresa,
		A.numeroDocumento,
		A.codigoEmpresaNumeroSerie,
		A.numeroSerieDocumento,
		A.codigoEmpresaSerie,
		A.codigoSerieDocumento,
		A.codigoEmpresaCliente,
		A.codigoCliente,
		A.cgc,
		A.tipoPessoa,
		A.nomeCliente,
		A.tipoDocumento,
		cancelado,
		chaveAcesso,
		dataEfetivacao,
		horaEfetivacao,
		estado,
		tipoEntrada,
		municipio,
		contabiliza,
		numeroDocumentoAuxiliar,
		numeroCaixaAuxiliar,
		serieDocumentoAuxiliar,	
		codigoEmpresaGrupoVendedor,
		codigoGrupoVendedor,
		nomeGrupoVendedor,
		codigoEmpresaVendedor,
		codigoVendedor,
		nomeVendedor,
		ISNULL(B.codigoRequisitante,0),
		ISNULL(B.nomeRequisitante,''),
		ISNULL(B.descontoIcms, 'N'),
		A.documentoReferenciado,
		A.codigoEmpresaProduto,
		A.codigoProduto
	
	ORDER BY 
		A.codigoEmpresa,
		dataEfetivacao + horaEfetivacao,
		A.codigoProduto 
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Cria a tabela temporaria global ##Vendas_Cupons, com a mesma estrutura da tabela fisica DWDevolucaoVendas

	If OBJECT_ID('tempdb.dbo.##Devolucoes') IS NOT NULL
		DROP TABLE ##Devolucoes;

	SELECT TOP 0
		*
	INTO ##Devolucoes FROM DWDevolucaoVendas (NOLOCK)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- SET NOCOUNT OFF; -- Ativa a contagem de registros, para auxiliar quando fizermos testes executando diretamente a SP
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Utilizando CTE para obter as devolucoes e gravar na temporaria global ##Devolucoes

	;WITH 
	devolucao AS(
		SELECT
			A.codigoEmpresa,
			A.numeroDocumento,
			A.codigoEmpresaNumeroSerie,
			A.numeroSerieDocumento,
			A.codigoEmpresaSerie,
			A.codigoSerieDocumento,
			A.codigoEmpresaCliente,
			A.codigoCliente,
			A.cgc,
			A.tipoPessoa,
			A.nomeCliente,
			A.tipoDocumento,
			A.cancelado,
			A.chaveAcesso,
			A.dataEfetivacao,
			A.horaEfetivacao,
			A.estado,
			A.tipoEntrada,
			A.municipio,
			A.contabiliza,
			A.numeroDocumentoAuxiliar,
			A.numeroCaixaAuxiliar,
			A.serieDocumentoAuxiliar,	
			A.itemDocumentoAuxiliar, -- serve para as notas sem cupons, quando tiver cupom ser� 0	
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
			A.precoUnitario,
			ISNULL(A.custoUnitario, 0) AS custoUnitario,
			A.quantidade,
			A.valorTotal,
			ISNULL(CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2)), 0) as custoTotal,
			A.valorDescontoTotal,
			A.valorIcmsSt,
			A.valorFrete,
			A.valorSeguro,
			A.valorOutrasDespesas,
			A.valorProdutos,
			A.valorSemDescontoIcms,
			CASE WHEN ROUND(A.quantidade * A.custoUnitario,2) > 0 AND valorSemDescontoIcms > 0 
				THEN Round( (1 - (CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) / valorSemDescontoIcms) * 100, 4)
				ELSE 0
			END margemLucro,		
			CASE WHEN ROUND(A.quantidade * A.custoUnitario,2) > 0 AND valorSemDescontoIcms > 0 
				THEN Round( ((CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) / valorSemDescontoIcms) * 100, 4)
				ELSE 0
			END divisaoLucro,
			CASE WHEN ROUND(A.quantidade * A.custoUnitario,2) > 0 AND valorSemDescontoIcms > 0 
				THEN ROUND(( valorSemDescontoIcms - (CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) ) / ( (CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) / 100),4)
				ELSE 0
			END markup		
		FROM #DEVOLUCAONOTASSAIDA A (NOLOCK)		
			INNER JOIN #PRODUTOS B (NOLOCK) ON 
				A.codigoEmpresaProduto = B.codigoEmpresa AND
				A.codigoProduto COLLATE DATABASE_DEFAULT = B.codigo
		UNION
		SELECT
			A.codigoEmpresa,
			A.numeroDocumento,
			A.codigoEmpresaNumeroSerie,
			A.numeroSerieDocumento,
			A.codigoEmpresaSerie,
			A.codigoSerieDocumento,
			A.codigoEmpresaCliente,
			A.codigoCliente,
			A.cgc,
			A.tipoPessoa,
			A.nomeCliente,
			A.tipoDocumento,
			A.cancelado,
			A.chaveAcesso,
			A.dataEfetivacao,
			A.horaEfetivacao,
			A.estado,
			A.tipoEntrada,
			A.municipio,
			A.contabiliza,
			A.numeroDocumentoAuxiliar,
			numeroCaixaAuxiliar,
			A.serieDocumentoAuxiliar,	
			A.itemDocumentoAuxiliar, -- serve para as notas sem cupons, quando tiver cupom ser� 0	
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
			A.precoUnitario,
			ISNULL(A.custoUnitario, 0) AS custoUnitario,
			A.quantidade,
			A.valorTotal,
			ISNULL(CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2)), 0) as custoTotal,
			A.valorDescontoTotal,
			A.valorIcmsSt,
			A.valorFrete,
			A.valorSeguro,
			A.valorOutrasDespesas,
			A.valorProdutos,
			A.valorSemDescontoIcms,
			CASE WHEN ROUND(A.quantidade * A.custoUnitario,2) > 0 AND valorSemDescontoIcms > 0 
				THEN Round( (1 - (CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) / valorSemDescontoIcms) * 100, 4)
				ELSE 0
			END margemLucro,		
			CASE WHEN ROUND(A.quantidade * A.custoUnitario,2) > 0 AND valorSemDescontoIcms > 0 
				THEN Round( ((CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) / valorSemDescontoIcms) * 100, 4)
				ELSE 0
			END divisaoLucro,		
			CASE WHEN ROUND(A.quantidade * A.custoUnitario,2) > 0 AND valorSemDescontoIcms > 0 
				THEN ROUND(( valorSemDescontoIcms - (CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) ) / ( (CONVERT(decimal(11,4), ROUND(A.quantidade * A.custoUnitario,2))) / 100),4)
				ELSE 0
			END markup	
		FROM #DEVOLUCAOCUPOM A (NOLOCK)
			INNER JOIN #PRODUTOS B (NOLOCK) ON
				A.codigoEmpresaProduto = B.codigoEmpresa AND
				A.codigoProduto COLLATE DATABASE_DEFAULT = B.codigo	
	)
	-- Grava registros das devolucoes na tabela temporaria global, para ser mesclada com os dados da DWDevolucaoVendas e usadas nos relatorios do RS.
	INSERT INTO ##Devolucoes
	SELECT 
		* 
	FROM devolucao	
END
