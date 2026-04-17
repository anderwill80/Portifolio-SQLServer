/*
====================================================================================================================================================================================
Obtem informacao de devolucao de vendas da tabela "DWDevolucaoVendas" que ja esta refinada, dessa forma teremos um ganho de performance no relatorios que venham a usar essa SP;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
22/04/2025 WILLIAM
	- Uso das SPs "usp_Get_DevolucaoVenda", que ira obter dados de vendas da tabela TBS059, quando usuario querer vendas do dia,
	essas SPs nao gravam mais dados na DWDevolucaoVendas, elas gravam dados na sua tabela temporaria global ##Devolucoes, que sera usada para mesclar
	com os dados da DWDevolucaoVendas. Tudo isso para evitar as duplicacoes de registros verificadas principalmente na Tanby Taubate, onde eles tem o costume de ver as devolucoes do dia;
11/03/2025 WILLIAM
	- Melhoria no filtro por SubGrupo de produto, fazendo a concatenacao entre o codigo do grupo + codigo subgrupo.Ex.: 005001, ou seja grupo 5 com subgrupo 1;
	- Aumento da capacidade do parametro @pcodigoSubGrupoProduto e sua respectiva variavel, para varchar(5000), valores do reportserver já estavam em +-800 caracteres;	
28/02/2025 WILLIAM
	- Criacao;
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_Get_DWDevolucaoVendas_DEBUG]
ALTER PROC [dbo].[usp_Get_DWDevolucaoVendas]
	@empcod smallint,
	@pdataDe date = null,
	@pdataAte date = null,
	@puf varchar(50) = '',
	@pcodigoCliente varchar(100) = '',
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
	@pcontabiliza varchar(10) = '',	-- ''; 'G'; 'L'; 'C';
	@pSomenteCupom char(1) = '',	-- ''; 'S';
	@pSomenteCancelados char(1) = ''	-- ''; 'S';
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataEmissao_De date, @dataEmissao_Ate date, @uf varchar(50), @codigoCliente varchar(100), @nomeCliente varchar(60),
			@codigoRequisitante int, @nomeRequisitante varchar(60), @codigoVendedor varchar(500), @nomeVendedor varchar(60), @codigoGrupoVendedor varchar(100),
			@codigoProduto varchar(500), @descricaoProduto varchar(60), @codigoGrupoProduto varchar(100), @codigoSubGrupoProduto varchar(5000), @codigoMarca int, @nomeMarca varchar(60),
			@DesconsiderarCancelados char(1), @contabiliza varchar(10), @SomenteCupom char(1), @SomenteCancelados char(1),
			@empresaTBS059 smallint,
			@cmdSQL nvarchar(MAX), @ParmDef nvarchar(500), @DataAtual date, @ContabilizaHoje bit;

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @dataEmissao_De = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataEmissao_Ate = (SELECT ISNULL(@pdataAte, GETDATE()));
	SET @uf = RTRIM(LTRIM(@puf));
	SET @codigoCliente = RTRIM(LTRIM(@pcodigoCliente));
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
	SET @SomenteCupom = UPPER(@pSomenteCupom);
	SET @SomenteCancelados = UPPER(@pSomenteCancelados);

--	Atribuicoes locais
	SET @DataAtual = CONVERT(date, GETDATE())

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
-- Codigos dos clientes			
	IF OBJECT_ID('tempdb.dbo.#MV_CLIENTES') IS NOT NULL
		DROP TABLE #MV_CLIENTES;
	SELECT 
		elemento as valor
	INTO #MV_CLIENTES FROM fSplit(@codigoCliente, ',');
	IF( @codigoCliente = '' )
		DELETE #MV_CLIENTES;
-- Codigos dos vendedores
	IF OBJECT_ID('tempdb.dbo.#MV_VENDEDORES') IS NOT NULL
		DROP TABLE #MV_VENDEDORES;
	SELECT 
		elemento as valor
	INTO #MV_VENDEDORES FROM fSplit(@codigoVendedor, ',')
	IF( @codigoVendedor = '' )
		DELETE #MV_VENDEDORES;
-- Grupo de vendedores
	IF OBJECT_ID('tempdb.dbo.#MV_GRUPOVENDEDORES') IS NOT NULL
		DROP TABLE #MV_GRUPOVENDEDORES;
	SELECT 
		elemento as valor
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
		elemento as valor
	INTO #MV_GRUPOPRODUTOS FROM fSplit(@codigoGrupoProduto, ',');
	IF( @codigoGrupoProduto = '' )
		DELETE #MV_GRUPOPRODUTOS;
-- Sub-Grupo de Produtos
	IF OBJECT_ID('tempdb.dbo.#MV_SUBGRUPOPRODUTOS') IS NOT NULL
		DROP TABLE #MV_SUBGRUPOPRODUTOS;
	SELECT 
		elemento as valor
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
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria estrutura da tabela temporaria dos registros NAO cancelados

	If OBJECT_ID('tempdb.dbo.#DEVOLUCAO') IS NOT NULL
		DROP TABLE #DEVOLUCAO;

	SELECT TOP 0
		*
	INTO #DEVOLUCAO FROM DWDevolucaoVendas (NOLOCK)
	
	-- Obtem dados da DWDevolucaoVendas, conforme filtros, utilizando "Consulta Dinamica"
	SET @cmdSQL = N'
		INSERT INTO #DEVOLUCAO

		SELECT 
			*
		FROM DWDevolucaoVendas (NOLOCK)

		WHERE 
			codigoEmpresa = @empresaTBS059
			AND data BETWEEN @dataEmissao_De AND @dataEmissao_Ate
			'
			+
			IIF(@SomenteCancelados = 'S', ' AND cancelado = ''S''', ' AND cancelado = ''N''')
			+
			IIF(@uf = '', '', ' AND uf IN(SELECT valor FROM #MV_UFS)')
			+
			IIF(@codigoCliente = '', '', ' AND codigoCliente IN(SELECT valor FROM #MV_CLIENTES)')
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
			IIF(@codigoSubGrupoProduto = '', '', ' AND RIGHT((''000'' + LTRIM(STR(codigoGrupo))), 3) + RIGHT((''000'' + LTRIM(STR(codigoSubgrupo))), 3) IN(SELECT valor FROM #MV_SUBGRUPOPRODUTOS)')
			+
			IIF(@codigoMarca = 0, '', ' AND codigoMarca = @codigoMarca')
			+
			IIF(@nomeMarca = '', '', ' AND nomeMarca LIKE @nomeMarca')
			+			
			IIF(@contabiliza = '', '', ' AND contabiliza IN(SELECT valor FROM #MV_CONTABILIZA)')
			+
			IIF(@SomenteCupom <> 'S', '', ' AND caixa > 0')
			+
			' ORDER BY
				codigoEmpresa,
				data
			'

	-- print @cmdSQL;

	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'
		@empresaTBS059 smallint, 
		@dataEmissao_De datetime,
		@dataEmissao_Ate datetime,
		@nomeCliente varchar(60),
		@codigoRequisitante int,
		@nomeRequisitante varchar(60),
		@nomeVendedor varchar(60),
		@descricaoProduto varchar(60),
		@codigoMarca int,
		@nomeMarca varchar(60),
		@contabiliza char(1),
		@SomenteCupom char(1)'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS059, @dataEmissao_De, @dataEmissao_Ate, @nomeCliente, 
	@codigoRequisitante, @nomeRequisitante, @nomeVendedor, @descricaoProduto, @codigoMarca, @nomeMarca, @contabiliza, @SomenteCupom

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final temporaria global ##DWDevolucaoVendas, com vendas efetivas ou canceladas conforme parametro @pDesconsideCancelados

	If OBJECT_ID('tempdb.dbo.##DWDevolucaoVendas') IS NOT NULL
		DROP TABLE ##DWDevolucaoVendas;

	-- "TOP 0", apenas para criar estrutura da tabela
	SELECT TOP 0
		*
	INTO ##DWDevolucaoVendas FROM #DEVOLUCAO

	-- Se parametro passado para ignorar cancelados, significa que vai considerar a venda mesmo que tenha sido cancelada
	IF @DesconsiderarCancelados = 'S' AND @SomenteCancelados <> 'S'
	BEGIN
		-- Obter registros que estao cancelados, pois sao gravados duplicados na tabela DWDevolucaoVendas, para o select final desconsiderar eles, 
		-- ja que devemos considerar apenas registro de vendas efetivas
		If OBJECT_ID('tempdb.dbo.#CANCELADOS') IS NOT NULL
				DROP TABLE #CANCELADOS;

		SELECT
			chave
		INTO #CANCELADOS FROM DWDevolucaoVendas (NOLOCK)

		WHERE 
			codigoEmpresa = @empresaTBS059
			AND data BETWEEN @dataEmissao_De AND @dataEmissao_Ate
			AND cancelado = 'S'
		GROUP BY
			chave
		--------------------------------------------------------------------------------------------		
		INSERT INTO ##DWDevolucaoVendas

		SELECT 
			* 
		FROM #DEVOLUCAO A

		WHERE
			NOT EXISTS(SELECT chave	FROM #CANCELADOS B WHERE B.chave = A.chave) -- Desconsidera os cancelados
	END
	ELSE
	BEGIN
		-- Retorna as vendas, mesmo que tenha sido cancelado posteriormente
		INSERT INTO ##DWDevolucaoVendas

		SELECT 
			* 
		FROM #DEVOLUCAO A
	END

/*
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
A partir desse ponto, verifica se usuario quer saber as devolucoes do dia, dessa forma iremos obter os dados da tabela TBS059, e nao mais gravar os dados do dia na DWDevolucaoVendas,
pois foi verificado que esta causando duplicacao de registros, principalmente em Taubate que executam muito relatorios com dados do dia.
Dessa forma foi criado a SP "usp_Get_DevolucaoVendas", que retorna os dados do dia em tabela temporaria, para serem mescladas com dados da DWDevolucaoVendas obtidos acima.
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
*/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verifica se a "data Ate" e maior ou igual a data do dia, para "alimentar" a tabela DWDevolucaoVendas, com as vendas do dia, ja que ela so e "alimentada" a noite
	IF @ContabilizaHoje = 'TRUE'
	BEGIN 
		-- Cria temporarias para manipular os dados de vendas de notas e cupons separados, para depois juntar e aplicar os filtros

		If OBJECT_ID('tempdb.dbo.#DEVOLUCAO_HOJE') IS NOT NULL
			DROP TABLE #DEVOLUCAO_HOJE;

		SELECT TOP 0
			*
		INTO #DEVOLUCAO_HOJE FROM DWDevolucaoVendas (NOLOCK)		
	
		If OBJECT_ID('tempdb.dbo.#DEVOLUCAO_HOJE_AUX') IS NOT NULL
			DROP TABLE #DEVOLUCAO_HOJE_AUX;

		SELECT TOP 0
			*
		INTO #DEVOLUCAO_HOJE_AUX FROM DWDevolucaoVendas (NOLOCK)

		PRINT 'Contabiliza hoje'

		-- Obtem as devolucoes da tabela TBS059			
		EXEC usp_Get_DevolucaoVendas @codigoEmpresa, @DataAtual, @DataAtual;

		-- Insere os registros de vendas de notas fiscais na temporaria auxiliar
		INSERT INTO #DEVOLUCAO_HOJE_AUX

		SELECT 
			*
		FROM ##Devolucoes (NOLOCK)	-- tabela criada pela SP "usp_Get_DevolucaoVendas"			

		-- Apaga a tabela global, sem uso a partir desse ponto
		DROP TABLE ##Devolucoes

		-- ****************************************************************************************************************************
		-- Inserir na tapela temporaria final de hoje, registros de notas e cupons aplicando os mesmos filtros que foram aplicados ao
		-- obter dados da tabela DWVendas, retirando apenas o filtro pela data, ja que somente dados de hoje.
		-- ****************************************************************************************************************************
	
		SET @cmdSQL = N'
			INSERT INTO #DEVOLUCAO_HOJE

			SELECT 
				*
			FROM #DEVOLUCAO_HOJE_AUX  (NOLOCK)

			WHERE 
				codigoEmpresa = @empresaTBS059
				'
				+
				IIF(@SomenteCancelados = 'S', ' AND cancelado = ''S''', ' AND cancelado = ''N''')
				+
				IIF(@uf = '', '', ' AND uf IN(SELECT valor FROM #MV_UFS)')
				+
				IIF(@codigoCliente = '', '', ' AND codigoCliente IN(SELECT valor FROM #MV_CLIENTES)')
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
				IIF(@codigoSubGrupoProduto = '', '', ' AND RIGHT((''000'' + LTRIM(STR(codigoGrupo))), 3) + RIGHT((''000'' + LTRIM(STR(codigoSubgrupo))), 3) IN(SELECT valor FROM #MV_SUBGRUPOPRODUTOS)')
				+
				IIF(@codigoMarca = 0, '', ' AND codigoMarca = @codigoMarca')
				+
				IIF(@nomeMarca = '', '', ' AND nomeMarca LIKE @nomeMarca')
				+			
				IIF(@contabiliza = '', '', ' AND contabiliza IN(SELECT valor FROM #MV_CONTABILIZA)')
				+
				IIF(@SomenteCupom <> 'S', '', ' AND caixa > 0')


		-- Prepara e executa a consulta dinamica
		SET @ParmDef = N'
			@empresaTBS059 smallint, 
			@nomeCliente varchar(60),
			@codigoRequisitante int,
			@nomeRequisitante varchar(60),
			@nomeVendedor varchar(60),
			@descricaoProduto varchar(60),
			@codigoMarca int,
			@nomeMarca varchar(60)
			'

		EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS059, @nomeCliente, @codigoRequisitante, @nomeRequisitante, @nomeVendedor, @descricaoProduto, @codigoMarca, @nomeMarca;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
		-- Verifica os documentos cancelados...

		-- Se parametro passado para ignorar cancelados, significa que vai considerar a venda mesmo que tenha sido cancelada		
		IF @DesconsiderarCancelados = 'S' AND @SomenteCancelados <> 'S'
		BEGIN
			-- Obter registros que estao cancelados, pois sao gravados duplicados na tabela DWDevolucaoVendas, para o select final desconsiderar eles, 
			-- ja que devemos considerar apenas registro de vendas efetivas
			If OBJECT_ID('tempdb.dbo.#CANCELADOS_HOJE') IS NOT NULL
				DROP TABLE #CANCELADOS_HOJE;

			SELECT
				chave
			INTO #CANCELADOS_HOJE FROM #DEVOLUCAO_HOJE_AUX (NOLOCK)

			WHERE 
				cancelado = 'S'
			GROUP BY
				chave
			--------------------------------------------------------------------------------------------		
			INSERT INTO ##DWDevolucaoVendas

			SELECT 
				* 
			FROM #DEVOLUCAO_HOJE A

			WHERE
				NOT EXISTS(SELECT chave	FROM #CANCELADOS_HOJE B WHERE B.chave = A.chave) -- Desconsidera os cancelados
		END
		ELSE
		BEGIN
			-- Retorna as vendas de hoje, mesmo que tenha sido cancelado posteriormente
			INSERT INTO ##DWDevolucaoVendas

			SELECT 
				* 
			FROM #DEVOLUCAO_HOJE
		END
	END	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END