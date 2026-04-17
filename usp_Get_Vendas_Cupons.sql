/*
====================================================================================================================================================================================
Coleta as informacoes de vendas de cupons para "alimentar" a tabela ##Vendas_Cupons, para ser usada em relatorios em que o usuario queria dados do dia.
Nao ira mais gravar os dados do dia na DWVendas, para evitar as duplicaoes verificadas principalmente em Taubate, devido a execucao de relatorios com a data do dia.
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
25/03/2026 WILLIAM
	- Inclusao do novo atributo "codigoGrupoSubGrupo";
29/01/2026 WILLIAM
	- Melhoria no aumento da precicao de 2 para 4 ao dar round no total liquido do cupom, isso aumenta a precisão no final ao arredondar para 2 casas;
26/01/2026 WILLIAM
	- Altercao ao verificar o tamanho da stringo do campo [cgc] quando registros status = "13", registros do GZ vem com máscara('.';'-';'/') e do DJSystem vem sem;
22/04/2025 WILLIAM
	- Criacao, para permitir obter as vendas do dia, feitas via cupons fiscias, similiar ao "AlimentaDWVendas", obtendo dados da movcaixagz, isso ira atender relatorios onde
	usuario escolhe a data do dia, onde anteriormente era feita a gravacao das vendas na DWVendas, porem ainda sim estava tendo duplicidade;
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_Get_Vendas_Cupons]
	@empcod int,
	@pdataDe date = null,
	@pdataAte date = null
AS 
BEGIN 
	SET NOCOUNT ON;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date,
			@empresaTBS010 smallint, @empresaTBS004 smallint, @empresaTBS091 smallint, @empresaTBS002 smallint, @empresaTBS067 smallint, @empresaTBS080 smallint,
			@codigoDevolucao int, @municipioGz varchar(40), @empresaGzLoja int, @GRUPOSVENDLOJA varchar(50);

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod	
	SET @dataDe = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pdataAte, GETDATE()));
		
-- Variaveis locais
	SET @codigoDevolucao = CONVERT(INT, dbo.ufn_Get_Parametro(1330));
	SET @empresaGzLoja = CONVERT(INT, dbo.ufn_Get_Parametro(1431));
	SET @municipioGz = (select RTRIM(EMPMUNNOM) from TBS023 (nolock) where EMPCOD = @codigoEmpresa);
	SET @GRUPOSVENDLOJA = RTRIM(LTRIM(dbo.ufn_Get_Parametro(1531)))

	-- Verificar se a tabela e compartilhada ou exclusiva					
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS091', @empresaTBS091 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
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
	-- Obtem dados de vendas de cupons, via tabela [movcaixagz]
	
	IF OBJECT_ID('tempdb.dbo.#CUPOM') IS NOT NULL
		DROP TABLE #CUPOM;
	
	SELECT 
		@empresaTBS067 as codigoEmpresa,
		cupom as numeroDocumento,
		0 as codigoEmpresaNumeroSerie,
		0 as numeroSerieDocumento,
		0 as codigoEmpresaSerie,
		'' as codigoSerieDocumento,
		A.caixa,		
		@empresaTBS002 as codigoEmpresaCliente, 
		ISNULL(cliente,0) as codigoCliente,
		CONVERT(char(14), '') as cgc,
		'' as tipoPessoa,	
		CONVERT(char(60), '') as nomeCliente,				
		case WHEN sitnf = 6 
			THEN 
				case WHEN cliente in (select codigo from #CLIENTESGRUPO where codigo <> @codigoDevolucao) -- cliente do grupo, indepENDente do vendedor, sempre vai contabilizar para o grupo
					THEN 'G'
					ELSE 
						case WHEN vendedor IN(SELECT CODIGO FROM #VENDEDORESLOJA) -- vendedores do grupo de loja, contabiliza para a loja
							THEN 'L'
							ELSE 'C' -- vendedores diferente do grupo 2 e 6
						END 
				END
			ELSE 'L'
		END as contabiliza,
		'N' as cancelado,		
		nfce_chave as chave,
		data as dataEmissao,
		A.hora + ':00' as hora,
		'SP' as uf,
		case WHEN sitnf = 6
			THEN 
				case WHEN A.municipio = '' or A.municipio is null
					THEN @municipioGz
					ELSE A.municipio
				END 
			ELSE @municipioGz
		END as municipio,		
		ISNULL(@empresaTBS091, 0) as codigoEmpresaGrupoVendedor,
		0 as codigoGrupoVendedor,
		'' as nomeGrupoVendedor,
		@empresaTBS004 as codigoEmpresaVendedor,
		case WHEN sitnf = 6 THEN vendedor ELSE 0 END as codigoVendedor,	
		case WHEN sitnf = 6 THEN ISNULL((SELECT TOP 1 nomeVendedor FROM #VENDEDORES C (NOLOCK) WHERE C.codigoEmpresa = @empresaTBS004 AND C.codigoVendedor = A.vendedor),'') ELSE '' END COLLATE DATABASE_DEFAULT as nomeVendedor,		
		0 as codigoRequisitante,
		'' as nomeRequisitante, 
		'N' as descontoIcms,
		'' as documentoReferenciado,
		'' as contribuinteIcms,
		0 as calculoDifal,				
		0 as item, 
		@empresaTBS010 as codigoEmpresaProduto,
		RTRIM(cdprod) as codigoProduto,		
		CONVERT(decimal(11,4),precocusto) as custoUnitario,
		CONVERT(decimal(11,4),quant) as quantidade,
		ROUND((valortot - desccupom - abatpgto - descitem + acrescupom + acresitem), 4) as valorTotal,
		desccupom + abatpgto + descitem as valorDescontoTotal,
		0.0000 as valorIcmsSt,
		0.0000 as valorFcp,
		0.0000 as valorFrete,
		0.0000 as valorSeguro,
		acrescupom + acresitem as valorOutrasDespesas,
		valortot as valorProdutos,		
		CONVERT(decimal(11,4), ROUND(CONVERT(decimal(11,4),quant) * CONVERT(decimal(11,4),precocusto),2)) as custoTotal,
		CONVERT(decimal(11,4), ROUND((valortot - desccupom - abatpgto - descitem + acrescupom + acresitem),2) ) as valorSemDescontoIcms,
		operador AS codigoOperador

	INTO #CUPOM FROM movcaixagz A (NOLOCK)
	
	WHERE 
		loja = @empresaGzLoja AND 
		status = '01' AND
		data BETWEEN @dataDe AND @dataAte
		--(data BETWEEN @dataDe AND @dataAte OR CONVERT(date, datahoraproc) = @dataAte)
		
	ORDER BY 
		loja, 
		data,
		status,
		A.cancelado


--		select * from #CUPOM;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------						
	-- Pegar os cupons que estao cancelados 
	
	INSERT #CUPOM
	
	SELECT 
		@empresaTBS067 as codigoEmpresa,
		cupom as numeroDocumento,
		0 as codigoEmpresaNumeroSerie,
		0 as numeroSerieDocumento,
		0 as codigoEmpresaSerie,
		'' as codigoSerieDocumento,
		A.caixa,
		@empresaTBS002 as codigoEmpresaCliente, 
		ISNULL(cliente,0) as codigoCliente,
		CONVERT(char(14), '') as cgc,
		'' as tipoPessoa,	
		CONVERT(char(60), '') as nomeCliente,				
		case WHEN sitnf = 6 
			THEN 
				case WHEN cliente IN (select codigo from #CLIENTESGRUPO where codigo <> @codigoDevolucao) -- cliente do grupo, indepENDente do vendedor, sempre vai contabilizar para o grupo
					THEN 'G'
					ELSE 
						case WHEN vendedor IN(SELECT CODIGO FROM #VENDEDORESLOJA) -- vendedores do grupo de loja, contabiliza para a loja
							THEN 'L'
							ELSE 'C' -- vendedores diferente do grupo 2
						END 
				END
			ELSE 'L'
		END as contabiliza,
		'S' as cancelado,		
		nfce_chave as chave,
		data as dataEmissao,
		A.hora + ':00' as hora,
		'SP' as uf,		
		case WHEN sitnf = 6
			THEN 
				case WHEN A.municipio = '' or A.municipio is null
					THEN @municipioGz
					ELSE A.municipio
				END 
			ELSE @municipioGz
		END as municipio,		
		ISNULL(@empresaTBS091, 0) as codigoEmpresaGrupoVendedor,
		0 as codigoGrupoVendedor,
		'' as nomeGrupoVendedor,
		@empresaTBS004 as codigoEmpresaVendedor,
		case WHEN sitnf = 6 THEN vendedor ELSE 0 END as codigoVendedor,	
		case WHEN sitnf = 6 THEN ISNULL((SELECT TOP 1 nomeVendedor FROM #VENDEDORES C (NOLOCK) WHERE C.codigoEmpresa = @empresaTBS004 AND C.codigoVendedor = A.vendedor),'') ELSE '' END COLLATE DATABASE_DEFAULT as nomeVendedor,			
		0 as codigoRequisitante,
		'' as nomeRequisitante, 
		'N' as descontoIcms,
		'' as documentoReferenciado,
		'' as contribuinteIcms,
		0 as calculoDifal,		
		0 as item, 
		@empresaTBS010 as codigoEmpresaProduto,
		RTRIM(cdprod) as codigoProduto,
		precocusto as custoUnitario,
		quant as quantidade,
		ROUND((valortot - desccupom - abatpgto - descitem + acrescupom + acresitem), 4) as valorTotal,
		desccupom + abatpgto + descitem as valorDescontoTotal,
		0.0000 as valorIcmsSt,
		0.0000 as valorFcp,
		0.0000 as valorFrete,
		0.0000 as valorSeguro,
		acrescupom + acresitem as valorOutrasDespesas,
		valortot as valorProdutos,		
		CONVERT(decimal(11,4), ROUND(quant * precocusto,2)) as custoTotal,
		CONVERT(decimal(11,4), ROUND((valortot - desccupom - abatpgto - descitem + acrescupom + acresitem),2) ) as valorSemDescontoIcms,
		operador AS codigoOperador

	FROM movcaixagz A (NOLOCK)

	WHERE
		loja = @empresaGzLoja AND 		
		status = '01' AND 
		A.cancelado = 'S' AND
		data BETWEEN @dataDe AND @dataAte		
		--(data BETWEEN @dataDe AND @dataAte OR CONVERT(date, datahoraproc) = @dataAte)
		
	ORDER BY 
		loja, 
		data,
		status,
		A.cancelado

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------						
	-- Pegar os cupons que teve cnpj incluso, depois dar update na tabela #cupom campo tipoPessoa, se estiver vazio
	
	IF OBJECT_ID('tempdb.dbo.#CUPOMCNPJ') IS NOT NULL
		DROP TABLE #CUPOMCNPJ;
	
	SELECT 	
		CASE WHEN len(A.cgc) > 14
			THEN substring(ISNULL(replace(replace(replace(A.cgc,'.',''),'/',''),'-',''),''),2,20) 
			ELSE ISNULL(replace(replace(replace(A.cgc,'.',''),'/',''),'-',''),'')
		END as cgc,
		-- cgc,
		cupom,
		caixa,
		nfce_chave,
		status		
	INTO #CUPOMCNPJ	FROM movcaixagz A (NOLOCK) 
		
	WHERE 
		loja = @empresaGzLoja AND 
		status in ('01','13') AND
		A.cgc <> '' AND 
		A.cgc <> '000.000.000-00' AND
		data BETWEEN @dataDe AND @dataAte
		--(data BETWEEN @dataDe AND @dataAte  OR CONVERT(date, datahoraproc) = @dataAte)
		
	GROUP BY 
		loja,
		A.cgc, 
		cupom, 
		caixa,
		nfce_chave,
		status

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------						
	-- Se tiver 2 cpfs para o mesmo cupom, pegar somente o do status 1, excluir o ooutro.	

	DELETE FROM #CUPOMCNPJ
	
	WHERE 
		nfce_chave IN (		
			SELECT 
				nfce_chave 		
			FROM #CUPOMCNPJ		
			
			group by  
				cupom, 
				caixa,
				nfce_chave
		
			HAVING COUNT(*) > 1) AND 
		status = '13'
		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- update no campo cgc, para pegar todo o cpf-cnpj usado no cupom
	
	BEGIN TRAN	
		UPDATE #CUPOM SET 
			cgc = ISNULL(B.cgc,'') COLLATE DATABASE_DEFAULT
	
		FROM #CUPOM A
			LEFT JOIN #CUPOMCNPJ B ON
				A.numeroDocumento = B.cupom AND 
				A.caixa = B.caixa AND
				A.chave COLLATE DATABASE_DEFAULT = B.nfce_chave 				
	COMMIT TRAN 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Update nos campos: tipoPessoa e cgc
	-- Com base no cpf-cnpj obtidos anteriormente, ou no codigo do cliente que foi inserido atraves da nota fiscal
	
	BEGIN TRAN 	
		UPDATE #CUPOM SET 
			codigoCliente = ISNULL(ISNULL(C.codigo, B.codigo), 0),
			nomeCliente = ISNULL(ISNULL(C.nomeCliente, B.nomeCliente),'') COLLATE DATABASE_DEFAULT,
			tipoPessoa = ISNULL(ISNULL(B.tipoPessoa, C.tipoPessoa),'F') COLLATE DATABASE_DEFAULT,			
			contribuinteIcms = ISNULL(ISNULL(A.contribuinteIcms, B.contribuinteIcms), 'N') COLLATE DATABASE_DEFAULT
		
		FROM #CUPOM A 
			LEFT JOIN (SELECT max(codigo)[codigo], nomeCliente, cgc, tipoPessoa, contribuinteIcms FROM #CLIENTES GROUP BY nomeCliente, cgc, tipoPessoa, contribuinteIcms) AS B ON
				A.cgc COLLATE DATABASE_DEFAULT = B.cgc AND B.cgc <> ''
			LEFT JOIN #CLIENTES C ON
				A.codigoCliente = C.codigo		
	COMMIT TRAN

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Cria a tabela temporaria global ##Vendas_Cupons, com a mesma estrutura da tabela fisica DWVendas

	If OBJECT_ID('tempdb.dbo.##Vendas_Cupons') IS NOT NULL
		DROP TABLE ##Vendas_Cupons;

	SELECT TOP 0
		*
	INTO ##Vendas_Cupons FROM DWVendas (NOLOCK)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- SET NOCOUNT OFF; -- Ativa a contagem de registros, para auxiliar quando fizermos testes executando diretamente a SP
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Utilizando CTE para incluir registros de vendas, somente os que ainda nao foram incluidos, para evitar duplicacao na DWVendas

	;WITH 
	vendas_cupons AS(
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
			B.codigoGrupoSubGrupo
		FROM #CUPOM A
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
			A.cgc,
			A.tipoPessoa,	
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
			B.codigoGrupoSubGrupo
		)	
		-- Grava registros das vendas na tabela temporaria global, para ser mesclada com os dados da DWVendas e usadas nos relatorios do RS.
		INSERT INTO ##Vendas_Cupons
		SELECT 
			* 
		FROM vendas_cupons
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
END