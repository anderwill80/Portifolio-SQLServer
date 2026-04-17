/*
====================================================================================================================================================================================
Obtem informacao de vendas da tabela "DWVendas" que ja esta refinada, dessa forma teremos um ganho de performance no relatorios que venham a usar essa SP;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
25/03/2026 WILLIAM
	Alteracao no filtro por codigo do sub grupo de produtos, onde agora temos um atributo proprio "codigoGrupoSubGrupo" contendo a juncao do codigo do grupo + sub grupo,
	deixando o SQL mais eficiente, pois nao teremos mais as funcoes RIGTH() no WHERE;
19/02/2026 WILLIAM
	- Inclusao de parametro de entrada, para obter apenas registros com codigo de cliente preenchido, ou seja, clientes cadastrado no sistema;
09/02/2026 WILLIAM
	- Alteracao para retornar os atributos "uf" e "municipio", para relatorios que recisem filtrar por estado e/ou cidade;
	- Conversao do parametro de entrada de varchar para int: @codigoCliente;
30/07/2025 WILLIAM
	- Alteracao do tipo smallint para int, ao criar tabelas temporarias de multvalor, usando o fsplit(), estava causando estouro de capacidade ao utilizar código de clientes
	maior que 32.768, que é o limite do smallint;
07/05/2025 WILLIAM
	- Correcao ao explicitar atributos quando dados do dia;
05/05/2025 WILLIAM
	- Inclusão explicita do nome das colunas a serem retornadas no select da DWVendas, reduzindo o numero de informacoes, consequentemente aumenta a performance;
22/04/2025 WILLIAM
	- Uso das SPs "usp_Get_Vendas_Notas" e "usp_Get_Vendas_Cupons", que ira obter dados de vendas da tabela TBS067 e movcaixagz respectivamente, quando usuario querer vendas do dia,
	essas SPs nao gravam mais dados na DWVendas, elas gravam dados nas suas respectivas tabelas temporarias globais ##Vendas_Notas e ##Vendas_Cupons, que sera usada para mesclar
	com os dados da DWVendas. Tudo isso para evitar as duplicacoes de registros verificadas principalmente na Tanby Taubate, onde eles tem o costume de ver as vendas do dia;
05/04/2025 WILLIAM
	- Uso das SP "AlimentaDWVendas_Notas" e "AlimentaDWVendas_Cupons", pois tem relatorios que so exigem dados de notas e nao de cupons, resultando em uma maior performance
	quando usuario querer dados do dia;
	- Novo parametro de entrada "@ptipoDocumento", para indicar se chama o "AlimentaDWVendas_Notas" ou "AlimentaDWVendas_Cupons";
	- Uso da funcao "CONVERT(smallint, elemento)", nos "SELECT INTO" ao usar a funcao fSplit(), para criar as tabelas multi-valores para atributos numericos;
	- Uso da funcao "ufn_Get_TemFrenteLoja" para saber se empresa tem frente de loja, para chamar ou nao a SP "AlimentaDWVendas_Cupons", para evietar processamento desnecessário;
25/03/2025 WILLIAM
	- Aumento da capacidade do parametro de entrada @puf de 50 para 100, todos as UFs ultrapassam os 50 caracteres;
11/03/2025 WILLIAM
	- Melhoria no filtro por SubGrupo de produto, fazendo a concatenacao entre o codigo do grupo + codigo subgrupo.Ex.: 005001, ou seja grupo 5 com subgrupo 1;
	- Aumento da capacidade do parametro @pcodigoSubGrupoProduto e sua respectiva variavel, para varchar(5000), valores do reportserver já estavam em +-800 caracteres;
26/02/2025 WILLIAM
	- Inclusao do hint "OPTION(MAXRECURSION 0)", apos a chamada da funcao fSplit() para lista de valores do subgrupo, pois tem mais de 100 itens;
24/02/2025 WILLIAM
	- Inclusao do parametro @pSomenteCancelados, para filtrar somente registros cancelados, trabalhando em conjunto com o @pDesconsideCancelados;
14/02/2025 WILLIAM
	- Inclusao do parametro @pDesconsideCancelados, para desconsiderar no select final, as vendas que foram canceladas, ou seja, so vendas efetivas;
13/02/2025 WILLIAM
	- Inclusao da chamada a SP "usp_AlimentaDWVendas", quando identificar que o parametro de "data ate" necessita dados da data do dia;
	- Correcao para considerar o parametro {contabiliza} como multivalor, para a clausula IN();
	- Retirada do parametro @cancelado, a SP e de registros de vendas efetivas, desconsiderando os cancelados;
	- Inclusao da leitura apenas dos registros cancelados, para serem desconsiderados no select final;
07/02/2025 WILLIAM
	- Criacao;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_Get_DWVendas_DEBUG]
ALTER PROC [dbo].[usp_Get_DWVendas]
	@empcod smallint,
	@pdataDe date = null,
	@pdataAte date = null,
	@puf varchar(100) = '',
	@pcodigoCliente int = 0,
	@pnomeCliente varchar(60) = '',
	@pcodigoRequisitante int = 0,
	@pnomeRequisitante varchar(60) = '',
	@pcodigoVendedor varchar(500) = '',
	@pnomeVendedor varchar(60) = '',
	@pcodigoGrupoVendedor varchar(100) = '',
	@pcodigoProduto varchar(500) = '',
	@pdescricaoProduto varchar(60) = '',
	@pcodigoGrupoProduto varchar(100) = '',
	@pcodigoSubGrupoProduto varchar(5000) = '',		
	@pcodigoMarca int = 0,
	@pnomeMarca varchar(60) = '',
	@pDesconsiderarCancelados char(1) = 'S',
	@pcontabiliza varchar(10) = '',		-- ''; 'G'; 'L'; 'C';
	@pSomenteCancelados char(1) = '',	-- ''; 'S';
	@ptipoDocumento char(1) = '',		-- ''; 'N'; 'C'; Tipo de documento para saber qual SP do "AlimentaDWVendas" chamar;
	@pSomenteComClientes char(1) = ''	-- Se 'S'im, ira obter somente vendas com clientes cadastrados no sistema
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataEmissao_De date, @dataEmissao_Ate date, @uf varchar(100), @codigoCliente int, @nomeCliente varchar(60),
			@codigoRequisitante int, @nomeRequisitante varchar(60), @codigoVendedor varchar(500), @nomeVendedor varchar(60), @codigoGrupoVendedor varchar(100),
			@codigoProduto varchar(500), @descricaoProduto varchar(60), @codigoGrupoProduto varchar(100), @codigoSubGrupoProduto varchar(5000), @codigoMarca int, @nomeMarca varchar(60),
			@DesconsiderarCancelados char(1), @contabiliza varchar(10), @tipoDocumento char(1), @SomenteCancelados char(1), @SomenteComClientes char(1),
			@empresaTBS067 smallint, @temLoja bit,
			@cmdSQL nvarchar(MAX), @ParmDef nvarchar(500), @DataAtual date, @ContabilizaHoje bit;

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @dataEmissao_De = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataEmissao_Ate = (SELECT ISNULL(@pdataAte, GETDATE() - 1));
	SET @uf = RTRIM(LTRIM(@puf));
	SET @codigoCliente = @pcodigoCliente;
	SET @nomeCliente = RTRIM(LTRIM(UPPER(@pnomeCliente)));
	SET @codigoRequisitante = @pcodigoRequisitante;
	SET @nomeRequisitante = RTRIM(LTRIM(UPPER(@pnomeRequisitante)));
	SET @codigoVendedor = RTRIM(LTRIM(@pcodigoVendedor));
	SET @nomeVendedor = RTRIM(LTRIM(UPPER(@pnomeVendedor)));
	SET @codigoGrupoVendedor = RTRIM(LTRIM(@pcodigoGrupoVendedor));
	SET @codigoProduto = RTRIM(LTRIM(@pcodigoProduto));
	SET @descricaoProduto = RTRIM(LTRIM(UPPER(@pdescricaoProduto)));
	SET @codigoGrupoProduto = RTRIM(LTRIM(@pcodigoGrupoProduto));
	SET @codigoSubGrupoProduto = RTRIM(LTRIM(@pcodigoSubGrupoProduto));
	SET @codigoMarca = @pcodigoMarca;	
	SET @nomeMarca = RTRIM(LTRIM(UPPER(@pnomeMarca)));
	SET @DesconsiderarCancelados = UPPER(@pDesconsiderarCancelados);
	SET @contabiliza = UPPER(@pcontabiliza);
	SET @SomenteCancelados = UPPER(@pSomenteCancelados);
	SET @tipoDocumento = UPPER(@pTipoDocumento);
	SET @SomenteComClientes = @pSomenteComClientes;

--	Atribuicoes locais
	SET @DataAtual = CONVERT(date, GETDATE())
	SET @temLoja = dbo.ufn_Get_TemFrenteLoja(@codigoEmpresa)	-- para saber se empresa tem frente de loja, para chamar ou nao a SP "AlimentaDWVendas_Cupons"	

	--	Verifica se a "data ate" e maior ou igual a data do dia, para indicar o flag "contabilizahoje"
	SET @ContabilizaHoje = IIF(CONVERT(date, @dataEmissao_Ate) >= @DataAtual, 1, 0);

-- Uso da funcao fSplit(), para as clausulas IN(), dos parametros multi-valores
-- UFs	
	IF OBJECT_ID('tempdb.dbo.#MV_UFS') IS NOT NULL
		DROP TABLE #MV_UFS;
	SELECT 
		elemento as valor
	INTO #MV_UFS FROM fSplit(@uf, ',');
	IF( @uf = '' )
		DELETE #MV_UFS;
-- Codigos dos vendedores
	IF OBJECT_ID('tempdb.dbo.#MV_VENDEDORES') IS NOT NULL
		DROP TABLE #MV_VENDEDORES;
	SELECT 
		CONVERT(int, elemento) as valor
	INTO #MV_VENDEDORES FROM fSplit(@codigoVendedor, ',')
	IF( @codigoVendedor = '' )
		DELETE #MV_VENDEDORES;
-- Grupo de vendedores
	IF OBJECT_ID('tempdb.dbo.#MV_GRUPOVENDEDORES') IS NOT NULL
		DROP TABLE #MV_GRUPOVENDEDORES;
	SELECT 
		CONVERT(int, elemento) as valor
	INTO #MV_GRUPOVENDEDORES FROM fSplit(@codigoGrupoVendedor, ',')
	IF( @codigoGrupoVendedor = '' )
		DELETE #MV_GRUPOVENDEDORES;
-- Produtos
	IF OBJECT_ID('tempdb.dbo.#MV_PRODUTOS') IS NOT NULL
		DROP TABLE #MV_PRODUTOS;
	SELECT 
		elemento as valor
	INTO #MV_PRODUTOS FROM fSplit(@codigoProduto, ',')
	IF( @codigoProduto = '' )
		DELETE #MV_PRODUTOS;
-- Grupo de Produtos
	IF OBJECT_ID('tempdb.dbo.#MV_GRUPOPRODUTOS') IS NOT NULL
		DROP TABLE #MV_GRUPOPRODUTOS;
	SELECT 
		CONVERT(int, elemento) as valor
	INTO #MV_GRUPOPRODUTOS FROM fSplit(@codigoGrupoProduto, ',');
	IF( @codigoGrupoProduto = '' )
		DELETE #MV_GRUPOPRODUTOS;
	--select * from #MV_GRUPOPRODUTOS;
-- Sub-Grupo de Produtos
	IF OBJECT_ID('tempdb.dbo.#MV_SUBGRUPOPRODUTOS') IS NOT NULL
		DROP TABLE #MV_SUBGRUPOPRODUTOS;
	SELECT 
		CONVERT(int, elemento) as valor
	INTO #MV_SUBGRUPOPRODUTOS FROM fSplit(@codigoSubGrupoProduto, ',') OPTION(MAXRECURSION 0);
	IF( @codigoSubGrupoProduto = '' )
		DELETE #MV_SUBGRUPOPRODUTOS;
-- Contabiliza, grupo, loja ou corporativo
	IF OBJECT_ID('tempdb.dbo.#MV_CONTABILIZA') IS NOT NULL
		DROP TABLE #MV_CONTABILIZA;
	SELECT 
		elemento as valor
	INTO #MV_CONTABILIZA FROM fSplit(@contabiliza, ',')
	IF( @contabiliza = '' )
		DELETE #MV_CONTABILIZA;		

-- Verificar se a tabela e compartilhada ou exclusiva			
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS067', @empresaTBS067 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela temporaria auxiliar, com a mesma estrutura da DWVendas

	If OBJECT_ID('tempdb.dbo.#VENDAS') IS NOT NULL
		DROP TABLE #VENDAS;

	SELECT TOP 0		
		codigoEmpresa,
		chave,

		data,
		hora,
		caixa,
		numeroDocumento,
		numeroSerieDocumento,
		codigoOperador,
		codigoVendedor,
		nomeVendedor,
		codigoGrupoVendedor,
		codigoCliente,
		nomeCliente,
		cgc,
		tipoPessoa,
		codigoProduto,
		descricaoProduto,
		unidade1,
		quantidade,
		documentoReferenciado,
		contabiliza,
		valorTotal,
		valorDescontoTotal,
		custoTotal,
		custoUnitario,
		valorSemDescontoIcms,
		precoUnitario,
		valorProdutos,
		codigoMarca,
		nomeMarca,
		codigoGrupo,
		nomeGrupo,
		codigoSubgrupo,
		nomeSubgrupo,
		margemLucro,
		cancelado,
		uf,
		municipio,
		codigoGrupoSubGrupo
	INTO #VENDAS FROM DWVendas (NOLOCK)	

	-- Obtem dados da DWVendas, conforme filtros, utilizando "Consulta Dinamica"
	SET @cmdSQL = N'
		INSERT INTO #VENDAS

		SELECT 
			codigoEmpresa,
			chave,
			
			data,
			hora,
			caixa,
			numeroDocumento,
			numeroSerieDocumento,
			codigoOperador,
			codigoVendedor,
			nomeVendedor,
			codigoGrupoVendedor,
			codigoCliente,
			nomeCliente,
			cgc,
			tipoPessoa,
			codigoProduto,
			descricaoProduto,
			unidade1,
			quantidade,
			documentoReferenciado,
			contabiliza,
			valorTotal,
			valorDescontoTotal,
			custoTotal,
			custoUnitario,
			valorSemDescontoIcms,
			precoUnitario,
			valorProdutos,
			codigoMarca,
			nomeMarca,
			codigoGrupo,
			nomeGrupo,
			codigoSubgrupo,
			nomeSubgrupo,
			margemLucro,
			cancelado,
			uf,
			municipio,
			codigoGrupoSubGrupo
		FROM DWVendas (NOLOCK)

		WHERE 
			codigoEmpresa = @empresaTBS067
			AND data BETWEEN @dataEmissao_De AND @dataEmissao_Ate
			'
			+
			IIF(@SomenteCancelados = 'S', ' AND cancelado = ''S''', ' AND cancelado = ''N''')
			+
			IIF(@uf = '', '', ' AND uf IN(SELECT valor FROM #MV_UFS)')
			+
			IIF(@codigoCliente = 0, '', ' AND codigoCliente = @codigoCliente')
			+
			IIF(@nomeCliente = '', '', ' AND nomeCliente LIKE @nomeCliente')
			+
			IIF(@codigoRequisitante = 0, '', ' AND codigoRequisitante = @codigoRequisitante')
			+
			IIF(@nomeRequisitante = '', '', ' AND nomeRequisitante LIKE @nomeRequisitante')
			+
			IIF(@codigoVendedor = '', '', ' AND codigoVendedor IN(SELECT valor FROM #MV_VENDEDORES)')
			+
			IIF(@nomeVendedor = '', '', ' AND nomeVendedor LIKE @nomeVendedor')
			+
			IIF(@codigoGrupoVendedor = '', '', ' AND codigoGrupoVendedor IN(SELECT valor FROM #MV_GRUPOVENDEDORES)')
			+
			IIF(@codigoProduto = '', '', ' AND codigoProduto IN(SELECT valor FROM #MV_PRODUTOS)')
			+
			IIF(@descricaoProduto = '', '', ' AND descricaoProduto LIKE @descricaoProduto')
			+
			IIF(@codigoGrupoProduto = '', '', ' AND codigoGrupo IN(SELECT valor FROM #MV_GRUPOPRODUTOS)')
			+
			IIF(@codigoSubGrupoProduto = '', '', ' AND codigoGrupoSubGrupo IN(SELECT valor FROM #MV_SUBGRUPOPRODUTOS)')
			+
			IIF(@codigoMarca = 0, '', ' AND codigoMarca = @codigoMarca')
			+
			IIF(@nomeMarca = '', '', ' AND nomeMarca LIKE @nomeMarca')
			+			
			IIF(@contabiliza = '', '', ' AND contabiliza IN(SELECT valor FROM #MV_CONTABILIZA)')
			+
			IIF(@tipoDocumento = '', '', IIF(@tipoDocumento = 'C', ' AND caixa > 0', IIF(@tipoDocumento = 'N', ' AND caixa = 0', '')))
			+
			IIF(@SomenteComClientes <> 'S', '' , ' AND codigoCliente > 0')
			+
			' ORDER BY
				codigoEmpresa,
				data
			'
	--print @cmdSQL;

	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'
		@empresaTBS067 smallint, 
		@dataEmissao_De datetime,
		@dataEmissao_Ate datetime,
		@codigoCliente int,
		@nomeCliente varchar(60),
		@codigoRequisitante int,
		@nomeRequisitante varchar(60),
		@nomeVendedor varchar(60),
		@descricaoProduto varchar(60),
		@codigoMarca int,
		@nomeMarca varchar(60),
		@contabiliza char(1)
		'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS067, @dataEmissao_De, @dataEmissao_Ate, @codigoCliente, @nomeCliente, 
	@codigoRequisitante, @nomeRequisitante, @nomeVendedor, @descricaoProduto, @codigoMarca, @nomeMarca, @contabiliza

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final temporaria global ##DWVendas, com vendas efetivas ou canceladas conforme parametro @pDesconsideCancelados

	If OBJECT_ID('tempdb.dbo.##DWVendas') IS NOT NULL
		DROP TABLE ##DWVendas;

	-- "TOP 0", apenas para criar estrutura da tabela
	SELECT TOP 0
		*
	INTO ##DWVendas FROM #VENDAS

	-- Se parametro passado para ignorar cancelados, significa que vai considerar a venda mesmo que tenha sido cancelada
	IF @DesconsiderarCancelados = 'S' AND @SomenteCancelados <> 'S'
	BEGIN
		-- Obter registros que estao cancelados, pois sao gravados duplicados na tabela DWVendas, para o select final desconsiderar eles, 
		-- ja que devemos considerar apenas registro de vendas efetivas
		If OBJECT_ID('tempdb.dbo.#CANCELADOS') IS NOT NULL
				DROP TABLE #CANCELADOS;

		SELECT
			chave
		INTO #CANCELADOS FROM DWVendas (NOLOCK)

		WHERE 
			codigoEmpresa = @empresaTBS067
			AND data BETWEEN @dataEmissao_De AND @dataEmissao_Ate
			AND cancelado = 'S'
		GROUP BY
			chave
		--------------------------------------------------------------------------------------------		
		INSERT INTO ##DWVendas

		SELECT 
			* 
		FROM #VENDAS A

		WHERE
			NOT EXISTS(SELECT chave	FROM #CANCELADOS B WHERE B.chave = A.chave) -- Desconsidera os cancelados
	END
		ELSE
	BEGIN
		-- Retorna as vendas, mesmo que tenha sido cancelado posteriormente
		INSERT INTO ##DWVendas

		SELECT 
			* 
		FROM #VENDAS A
	END

/*
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
A partir desse ponto, verifica se usuario quer saber as vendas do dia, dessa forma iremos obter os dados da tabela TBS067, e nao mais gravar os dados do dia na DWVendas,
pois foi verificado que esta causando duplicacao de registros, principalmente em Taubate que executam muito relatorios com dados do dia.
Dessa forma foi criado a SP "usp_Get_Vendas_Notas" e "usp_Get_Vendas_Cupons", que retornam os dados do dia em tabelas temporarias, para serem mescladas com dados da DWVendas,
obtidos acima 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
*/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verifica se usuario quer vendas do dia...

	IF @ContabilizaHoje = 'TRUE'
	BEGIN 
		-- Cria temporarias para manipular os dados de vendas de notas e cupons separados, para depois juntar e aplicar os filtros

		If OBJECT_ID('tempdb.dbo.#VENDAS_HOJE') IS NOT NULL
			DROP TABLE #VENDAS_HOJE;

		SELECT TOP 0
			codigoEmpresa,
			chave,
			
			data,
			hora,
			caixa,
			numeroDocumento,
			numeroSerieDocumento,
			codigoOperador,
			codigoVendedor,
			nomeVendedor,
			codigoGrupoVendedor,
			codigoCliente,
			nomeCliente,
			cgc,
			tipoPessoa,
			codigoProduto,
			descricaoProduto,
			unidade1,
			quantidade,
			documentoReferenciado,
			contabiliza,
			valorTotal,
			valorDescontoTotal,
			custoTotal,
			custoUnitario,
			valorSemDescontoIcms,
			precoUnitario,
			valorProdutos,
			codigoMarca,
			nomeMarca,
			codigoGrupo,
			nomeGrupo,
			codigoSubgrupo,
			nomeSubgrupo,
			margemLucro,
			cancelado,
			uf,
			municipio,
			codigoGrupoSubGrupo
		INTO #VENDAS_HOJE FROM DWVendas (NOLOCK)		
	
		If OBJECT_ID('tempdb.dbo.#VENDAS_HOJE_AUX') IS NOT NULL
			DROP TABLE #VENDAS_HOJE_AUX;

		SELECT TOP 0
			codigoEmpresa,
			chave,
			
			data,
			hora,
			caixa,
			numeroDocumento,
			numeroSerieDocumento,
			codigoOperador,
			codigoVendedor,
			nomeVendedor,
			codigoGrupoVendedor,
			codigoCliente,
			nomeCliente,
			cgc,
			tipoPessoa,
			codigoProduto,
			descricaoProduto,
			unidade1,
			quantidade,
			documentoReferenciado,
			contabiliza,
			valorTotal,
			valorDescontoTotal,
			custoTotal,
			custoUnitario,
			valorSemDescontoIcms,
			precoUnitario,
			valorProdutos,
			codigoMarca,
			nomeMarca,
			codigoGrupo,
			nomeGrupo,
			codigoSubgrupo,
			nomeSubgrupo,
			margemLucro,
			cancelado,
			uf,
			municipio,
			codigoGrupoSubGrupo
		INTO #VENDAS_HOJE_AUX FROM DWVendas (NOLOCK)

		PRINT 'Contabiliza hoje'

		-- Verifica se e para obter dados de notas fiscais da tabela TBS067
		IF @tipoDocumento = 'N' OR @tipoDocumento = ''
		BEGIN
			PRINT 'vendas de notas...';
			EXEC usp_Get_Vendas_Notas @codigoEmpresa, @DataAtual, @DataAtual;

			-- Insere os registros de vendas de notas fiscais na temporaria auxiliar
			INSERT INTO #VENDAS_HOJE_AUX

			SELECT 
				codigoEmpresa,
				chave,
				
				data,
				hora,
				caixa,
				numeroDocumento,
				numeroSerieDocumento,
				codigoOperador,
				codigoVendedor,
				nomeVendedor,
				codigoGrupoVendedor,
				codigoCliente,
				nomeCliente,
				cgc,
				tipoPessoa,
				codigoProduto,
				descricaoProduto,
				unidade1,
				quantidade,
				documentoReferenciado,
				contabiliza,
				valorTotal,
				valorDescontoTotal,
				custoTotal,
				custoUnitario,
				valorSemDescontoIcms,
				precoUnitario,
				valorProdutos,
				codigoMarca,
				nomeMarca,
				codigoGrupo,
				nomeGrupo,
				codigoSubgrupo,
				nomeSubgrupo,
				margemLucro,
				cancelado,
				uf,
				municipio,
				codigoGrupoSubGrupo
			FROM ##Vendas_Notas (NOLOCK)	-- tabela criada pela SP "usp_Get_Vendas_Notas"			

			-- Apaga a tabela global, sem uso a partir desse ponto
			DROP TABLE ##Vendas_Notas
		END;

		-- Se obtem novos dados de cupons
		IF (@tipoDocumento = 'C' OR @tipoDocumento = '') AND @temLoja = 'TRUE'
		BEGIN
			PRINT 'vendas de cupons...';
			EXEC usp_Get_Vendas_Cupons @codigoEmpresa, @DataAtual, @DataAtual;
			
			-- Insere os registros de vendas de notas fiscais na temporaria auxiliar
			INSERT INTO #VENDAS_HOJE_AUX

			SELECT 
				codigoEmpresa,
				chave,
				
				data,
				hora,
				caixa,
				numeroDocumento,
				numeroSerieDocumento,
				codigoOperador,
				codigoVendedor,
				nomeVendedor,
				codigoGrupoVendedor,
				codigoCliente,
				nomeCliente,
				cgc,
				tipoPessoa,
				codigoProduto,
				descricaoProduto,
				unidade1,
				quantidade,
				documentoReferenciado,
				contabiliza,
				valorTotal,
				valorDescontoTotal,
				custoTotal,
				custoUnitario,
				valorSemDescontoIcms,
				precoUnitario,
				valorProdutos,
				codigoMarca,
				nomeMarca,
				codigoGrupo,
				nomeGrupo,
				codigoSubgrupo,
				nomeSubgrupo,
				margemLucro,
				cancelado,
				uf,
				municipio,
				codigoGrupoSubGrupo
			FROM ##Vendas_Cupons (NOLOCK)	-- tabela criada pela SP "usp_Get_Vendas_Notas"			

			-- Apaga a tabela global, sem uso a partir desse ponto
			DROP TABLE ##Vendas_Cupons			
		END;

		-- ****************************************************************************************************************************
		-- Inserir na tapela temporaria final de hoje, registros de notas e cupons aplicando os mesmos filtros que foram aplicados ao
		-- obter dados da tabela DWVendas, retirando apenas o filtro pela data, ja que somente dados de hoje.
		-- ****************************************************************************************************************************
	
		SET @cmdSQL = N'
			INSERT INTO #VENDAS_HOJE

			SELECT 
				*
			FROM #VENDAS_HOJE_AUX (NOLOCK)

			WHERE 
				codigoEmpresa = @empresaTBS067
				'
				+
				IIF(@SomenteCancelados = 'S', ' AND cancelado = ''S''', ' AND cancelado = ''N''')
				+
				IIF(@uf = '', '', ' AND uf IN(SELECT valor FROM #MV_UFS)')
				+
				IIF(@codigoCliente = 0, '', ' AND codigoCliente = @codigoCliente')
				+
				IIF(@nomeCliente = '', '', ' AND nomeCliente LIKE @nomeCliente')
				+
				IIF(@codigoRequisitante = 0, '', ' AND codigoRequisitante = @codigoRequisitante')
				+
				IIF(@nomeRequisitante = '', '', ' AND nomeRequisitante LIKE @nomeRequisitante')
				+
				IIF(@codigoVendedor = '', '', ' AND codigoVendedor IN(SELECT valor FROM #MV_VENDEDORES)')
				+
				IIF(@nomeVendedor = '', '', ' AND nomeVendedor LIKE @nomeVendedor')
				+
				IIF(@codigoGrupoVendedor = '', '', ' AND codigoGrupoVendedor IN(SELECT valor FROM #MV_GRUPOVENDEDORES)')
				+
				IIF(@codigoProduto = '', '', ' AND codigoProduto IN(SELECT valor FROM #MV_PRODUTOS)')
				+
				IIF(@descricaoProduto = '', '', ' AND descricaoProduto LIKE @descricaoProduto')
				+
				IIF(@codigoGrupoProduto = '', '', ' AND codigoGrupo IN(SELECT valor FROM #MV_GRUPOPRODUTOS)')
				+
				IIF(@codigoSubGrupoProduto = '', '', ' AND codigoGrupoSubGrupo IN(SELECT valor FROM #MV_SUBGRUPOPRODUTOS)')
				+
				IIF(@codigoMarca = 0, '', ' AND codigoMarca = @codigoMarca')
				+
				IIF(@nomeMarca = '', '', ' AND nomeMarca LIKE @nomeMarca')
				+			
				IIF(@contabiliza = '', '', ' AND contabiliza IN(SELECT valor FROM #MV_CONTABILIZA)')
				+
				IIF(@SomenteComClientes <> 'S', '' , ' AND codigoCliente > 0')							

		-- Prepara e executa a consulta dinamica
		SET @ParmDef = N'
			@empresaTBS067 smallint, 
			@codigoCliente int,
			@nomeCliente varchar(60),
			@codigoRequisitante int,
			@nomeRequisitante varchar(60),
			@nomeVendedor varchar(60),
			@descricaoProduto varchar(60),
			@codigoMarca int,
			@nomeMarca varchar(60)
		'

		EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS067, @codigoCliente, @nomeCliente, @codigoRequisitante, @nomeRequisitante, @nomeVendedor, @descricaoProduto, @codigoMarca, @nomeMarca;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
		-- Verifica os documentos cancelados...

		-- Se parametro passado para ignorar cancelados, significa que vai considerar a venda mesmo que tenha sido cancelada		
		IF @DesconsiderarCancelados = 'S' AND @SomenteCancelados <> 'S'
		BEGIN
			-- Obter registros que estao cancelados, pois sao gravados duplicados na tabela DWVendas, para o select final desconsiderar eles, 
			-- ja que devemos considerar apenas registro de vendas efetivas
			If OBJECT_ID('tempdb.dbo.#CANCELADOS_HOJE') IS NOT NULL
				DROP TABLE #CANCELADOS_HOJE;

			SELECT
				chave
			INTO #CANCELADOS_HOJE FROM #VENDAS_HOJE_AUX (NOLOCK)

			WHERE 
				cancelado = 'S'
			GROUP BY
				chave
			--------------------------------------------------------------------------------------------		
			INSERT INTO ##DWVendas

			SELECT 
				* 
			FROM #VENDAS_HOJE A

			WHERE
				NOT EXISTS(SELECT chave	FROM #CANCELADOS_HOJE B WHERE B.chave = A.chave) -- Desconsidera os cancelados
		END
		ELSE
		BEGIN
			-- Retorna as vendas de hoje, mesmo que tenha sido cancelado posteriormente
			INSERT INTO ##DWVendas

			SELECT 
				* 
			FROM #VENDAS_HOJE
		END
	END	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END