/*
====================================================================================================================================================================================
WREL129 - Entradas por Produto 
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
21/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Uso da SP "usp_ClientesGrupo" e "usp_FornecedoresGrupo";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_EntradasPorProduto]
--ALTER PROCEDURE [dbo].[usp_RS_EntradasPorProduto]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
	@tipoNota varchar(100),
	@codigoLocalEstoque varchar(50),
	@codigoProduto varchar(500),
	@descricaoProduto varchar(60),
    @codigoMarca varchar(100),
	@nomeMarca varchar(60),
	@localizacaoEspecifica varchar(50),
	@localizacaoGeral varchar(50),    
	@setorEspecifico varchar(50),
    @setorGeral varchar(50),
	@cfop varchar(5000)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint,
			@data_De datetime, @data_Ate datetime, @TiposNotaFiscal varchar(100), @LocaisEstoque varchar(50), @PROCOD varchar(500), @PRODES varchar(60),
			@marca varchar(8000), @MARNOM varchar(60), @localizacao varchar(8000), @localGeral varchar(50), @setores varchar(8000), @setoresGeral varchar(50), @CFOPs varchar(5000),
			@codigoDevolucao int;
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @TiposNotaFiscal = @tipoNota;
	SET @LocaisEstoque = @codigoLocalEstoque;
	SET @PRODES = RTRIM(LTRIM(UPPER(@descricaoProduto)));
	SET @PROCOD = @codigoProduto;
	SET @marca = replace(replace(@codigoMarca,',',''','''),' ','');
	SET @MARNOM = RTRIM(LTRIM(UPPER(@nomeMarca)));
	SET @localizacao = replace(replace(@localizacaoEspecifica,',',''','''),' ','');
	SET @localGeral = @localizacaoGeral;
	SET @setores = replace(replace(@setorEspecifico,',',''','''),' ','');
	SET @setoresGeral = @setorGeral;
	SET @CFOPs = @cfop;
	
	SET @codigoDevolucao = (SELECT RTRIM(LTRIM(PARVAL)) FROM TBS025 (NOLOCK) WHERE PARCHV = 1330)

-- Uso da funcao fSplit, para filtros com clausula IN()
	--Tipos de notas
	IF object_id('TempDB.dbo.#TIPOSNOTAS') IS NOT NULL
		DROP TABLE #TIPOSNOTAS;
    SELECT 
		elemento as valor
	INTO #TIPOSNOTAS FROM fSplit(@TiposNotaFiscal, ',');
	--Locais de estoque
	IF object_id('TempDB.dbo.#LOCAISEST') IS NOT NULL
		DROP TABLE #LOCAISEST;
    SELECT 
		elemento as valor
	INTO #LOCAISEST FROM fSplit(@LocaisEstoque, ',');
	-- CFOPs
	IF object_id('TempDB.dbo.#CFOPS') IS NOT NULL
		DROP TABLE #CFOPS;
    SELECT 
		elemento as valor
	INTO #CFOPS FROM fSplit(@CFOPs, ',');

--	SELECT valor FROM #CFOPS
--	SELECT * FROM #TIPOSNOTAS;
--	SELECT * FROM #LOCAISEST;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrando locais do estoque

	IF object_id('tempdb.dbo.#LOCALESTOQUE') IS NOT NULL 	
		DROP TABLE #LOCALESTOQUE;

	SELECT 
		LESCOD as codigoLocalEstoque,
		rtrim(ltrim(str(LESCOD))) + ' - ' + dbo.PrimeiraMaiuscula(LESDES) as descricaoLocalEstoque
	INTO #LOCALESTOQUE FROM TBS034 (NOLOCK) 

	WHERE 
		LESCOD IN (SELECT valor FROM #LOCAISEST)

--	SELECT * FROM #LOCALESTOQUE
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos produtos via SP
	IF object_id('tempdb.dbo.#CODIGOS') IS NOT NULL 	
		DROP TABLE #CODIGOS;
	
	CREATE TABLE #CODIGOS (codigoProduto varchar(15))

	INSERT INTO #CODIGOS
	EXEC usp_GetCodigosProdutos @codigoEmpresa, @PROCOD, @PRODES, 0, ''

--	SELECT * FROM #CODIGOS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrando as localizações

	declare @sqlLocalizacao varchar (8000)

	if @localizacao <> ''

	begin
 
		set @sqlLocalizacao =
		'SELECT rtrim(ltrim(PROCOD)) PROCOD 
	
		FROM TBS010 (NOLOCK) 

		WHERE 
		PROLOCFIS IN ('''+rtrim(ltrim(replace(upper(@localizacao),' ','')))+''') and
		PROLOCFIS in (case when '''+@localGeral+''' = '''' then PROLOCFIS else rtrim(upper('''+@localGeral+''')) end)'

	end

	else 

	begin 
 
		set @sqlLocalizacao = 
		'SELECT RTRIM(PROCOD) PROCOD FROM TBS010 (NOLOCK)
	
		where 
		PROLOCFIS in (case when '''+@localGeral+''' = '''' then PROLOCFIS else rtrim(upper('''+@localGeral+''')) end)'

	end 

	if object_id('tempdb.dbo.#Localizacoes') is not null
	begin 
		drop table #Localizacoes
	end 

	create table #Localizacoes (codigoProduto varchar(15))
	INSERT INTO #Localizacoes
	EXEC(@sqlLocalizacao)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrando os setores 

	declare @sqlSetores varchar (8000)

	if @setores <> ''

	begin
 
		set @sqlSetores = 
		'SELECT rtrim(ltrim(PROCOD)) PROCOD 
	
		FROM TBS010 (NOLOCK) 

		WHERE 
		PROSETLOJ1 IN ('''+rtrim(ltrim(replace(upper(@setores),' ','')))+''') OR PROSETLOJ2 IN ('''+rtrim(ltrim(replace(upper(@setores),' ','')))+''') and 
		(PROSETLOJ1 like(case when '''+@setoresGeral+''' = '''' then PROSETLOJ1 else rtrim(upper('''+@setoresGeral+''')) end) or PROSETLOJ2 like(case when '''+@setoresGeral+''' = '''' then PROSETLOJ2 else rtrim(upper('''+@setoresGeral+''')) end) )'

	end

	else 

	begin 
 
		set @sqlSetores = 
		'SELECT RTRIM(PROCOD) PROCOD FROM TBS010 (NOLOCK)
	
		where 
		(PROSETLOJ1 like(case when '''+@setoresGeral+''' = '''' then PROSETLOJ1 else rtrim(upper('''+@setoresGeral+''')) end) or PROSETLOJ2 like(case when '''+@setoresGeral+''' = '''' then PROSETLOJ2 else rtrim(upper('''+@setoresGeral+''')) end) )'

	end 

	if object_id('tempdb.dbo.#Setores') is not null
	begin 
		drop table #Setores
	end 

	create table #Setores (codigoProduto varchar(15))
	INSERT INTO #Setores
	EXEC(@sqlSetores)

	-- select * from #Setores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Filtrando os codigos das marcas 

	declare @sqlCodigoMarca varchar (8000)

	if @sqlCodigoMarca <> ''

	begin
 
		set @sqlCodigoMarca = '	
		SELECT MARCOD
	
		FROM TBS014 (NOLOCK) 

		WHERE 
		MARCOD IN ('''+rtrim(ltrim(@marca))+''')
	
		union 
	
		select top 1 0 as MARCOD from TBS014 (nolock) where 0 in ('''+rtrim(ltrim(@marca))+''') '

	end

	else 

	begin 
 
		set @sqlCodigoMarca = 'SELECT MARCOD FROM TBS014 (NOLOCK) union SELECT top 1 0 as MARCOD FROM TBS014 (NOLOCK)'

	end 

	if object_id('tempdb.dbo.#CodigosMarcas') is not null
	begin 
		drop table #CodigosMarcas
	end 

	create table #CodigosMarcas (codigoMarca int)
	INSERT INTO #CodigosMarcas
	EXEC(@sqlCodigoMarca)

	-- select * from #CodigosMarcas
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrando as marcas 

	if object_id('tempdb.dbo.#Marcas') is not null 
	begin 
		drop table #Marcas
	end 

	select 
	MARCOD as codigoMarca

	into #Marcas
	from TBS014 (nolock)

	where
	MARCOD in (select codigoMarca from #CodigosMarcas) and 
	MARNOM LIKE (CASE WHEN @MARNOM = '' THEN MARNOM ELSE @MARNOM END )

	union 

	select 
	top 1
	0 as codigoMarca

	from TBS014 (nolock) 

	where 
	0 in (select codigoMarca from #CodigosMarcas) and 
	'SEM MARCA' LIKE (CASE WHEN @MARNOM = '' THEN 'SEM MARCA' ELSE @MARNOM END )

	-- select * from #Marcas
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- Por algum motivo o servidor de Taubaté não consegue processar o where na TBS010 da seguinte forma 
	--where 
	--PROCOD collate database_default in (select codigoProduto from #CODIGOS) and 
	--PROCOD collate database_default in (select codigoProduto from #Localizacoes) and 
	--PROCOD collate database_default in (select codigoProduto from #Setores) 

	-- Sendo assim tenho que criar essa tabela abaixo

	if object_id('tempdb.dbo.#ProdutosCodigos') is not null 
	begin 
		drop table #ProdutosCodigos
	end 

	select codigoProduto into #ProdutosCodigos from #CODIGOS
	union all
	select codigoProduto from #Localizacoes
	union all
	select codigoProduto from #Setores

--	SELECT * FROM #ProdutosCodigos
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Juntando os codigos de produto filtrados acima 

	IF object_id('tempdb.dbo.#CODIGOSPRODUTOS') IS NOT NULL 
		DROP TABLE #CODIGOSPRODUTOS;

	SELECT 
		rtrim(PROCOD) as codigoProduto
	INTO #CODIGOSPRODUTOS FROM TBS010 (NOLOCK)

	WHERE 
		PROCOD COLLATE DATABASE_DEFAULT IN (select codigoProduto from #ProdutosCodigos group by codigoProduto having count(codigoProduto) = 3) 
		/* Em taubaté não da para rodar dessa forma, trava o select
		PROCOD collate database_default in (select codigoProduto from #CODIGOS) and 
		PROCOD collate database_default in (select codigoProduto from #Localizacoes) and 
		PROCOD collate database_default in (select codigoProduto from #Setores) and 
		MARCOD in (select codigoMarca from #CodigosMarcas) and */
		--PRODES COLLATE DATABASE_DEFAULT LIKE (CASE WHEN @PRODES = '' THEN PRODES ELSE @PRODES END ) -- JA esta sendo filtrado pela SP "usp_GetCodigosProdutos"

--	SELECT * FROM #CODIGOSPRODUTOS

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Separar as compras\devoluyções normais das do grupo

	-- Selecionando os clientes do grupo via SP

	IF object_id('tempdb.dbo.#CLIENTESGRUPOS') IS NOT NULL	
		DROP TABLE #CLIENTESGRUPOS;

	CREATE TABLE #CLIENTESGRUPOS (codigoCliente int)

	INSERT INTO #CLIENTESGRUPOS
	EXEC usp_ClientesGrupo @codigoempresa;

--	select * from #CLIENTESGRUPOS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Selecionando os fornecedores do grupo

	IF object_id('tempdb.dbo.#FORNECEDORESGRUPOS') IS NOT NULL	
		DROP TABLE #FORNECEDORESGRUPOS;

	CREATE TABLE #FORNECEDORESGRUPOS (codigoFornecedor int)

	INSERT INTO #FORNECEDORESGRUPOS
	EXEC usp_FornecedoresGrupo @codigoempresa;

--	select * from #FORNECEDORESGRUPOS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atributos necessarios da TBS010 

	IF object_id('tempdb.dbo.#PRODUTOS') IS NOT NULL 
		DROP TABLE #PRODUTOS;

	SELECT 
		rtrim(PROCOD) as codigoProduto,
		rtrim(PRODES) as descricaoProduto,
		MARCOD as codigoMarca,
		case when MARCOD = 0 then 'SEM MARCA' else rtrim(MARNOM) end as nomeMarca,
		case when PROUM1QTD = 1
			then isnull((select rtrim(UNIDES) from TBS011 B (nolock) where A.PROUM1 = B.UNICOD),rtrim(PROUM1))
			else
				case when PROUM1QTD > 1 
				then rtrim(PROUM1) + ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) 
				else '' 
			end 
		end as menorUnidade,
		rtrim(PROLOCFIS) as localizacao,
		rtrim(PROSETLOJ1) as setor1,
		rtrim(PROSETLOJ2) as setor2
	INTO #PRODUTOS FROM TBS010 A (NOLOCK)

	WHERE 
		PROCOD IN (select codigoProduto from #CODIGOSPRODUTOS)

--	select * from #PRODUTOS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TBS080 TABELA DE AUTORIZAÇÃO
	-- Para as notas de entrada posso filtrar a data na TBS080 pois as notas de devolução feita pela propria empresa são autorizadas somente depois na TBS080

	IF object_id('tempdb.dbo.#NOTASAUTORIZADAS') IS NOT NULL
		DROP TABLE #NOTASAUTORIZADAS;	
   
	SELECT 
		ENFNUM,
		SNEEMPCOD,
		SNESER,
		ENFTIPDOC,
		ENFFINEMI,
		ENFCODDES
	INTO #NOTASAUTORIZADAS FROM TBS080 (NOLOCK)

	WHERE 
		ENFDATEMI BETWEEN @data_De AND @data_Ate AND 
		ENFSIT = 6 AND 
		ENFFINEMI IN (1,4) AND
		ENFTIPDOC = 0 

--	select * from #NOTASAUTORIZADAS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Notas de entrada
	-- Precios agrupar por codigo de fornecedor\cliente, para saber se é do grupo ou não

	IF object_id('tempdb.dbo.#NOTASENTRADAS1') IS NOT NULL
		DROP TABLE #NOTASENTRADAS1;

	SELECT
		case when A.NFETIP = 'D' and A.NFECOD in (select codigoCliente from #CLIENTESGRUPOS)
			then 'A'
			else 
				case when A.NFETIP = 'N' and A.NFECOD in (select codigoFornecedor from #FORNECEDORESGRUPOS)
					then 'B'
					else A.NFETIP
				end
		end as tipoNota,

		case when A.NFETIP = 'D' and A.NFECOD in (select codigoCliente from #CLIENTESGRUPOS)
			then 'Devolucao Grupo'
			else 
				case when A.NFETIP = 'D' and A.NFECOD not in (select codigoCliente from #CLIENTESGRUPOS)
					then 'Devolucao'
					else
						case when A.NFETIP = 'N' and A.NFECOD in (select codigoFornecedor from #FORNECEDORESGRUPOS)
							then 'Compra Grupo'
							else 
								case when A.NFETIP = 'N' and A.NFECOD not in (select codigoFornecedor from #FORNECEDORESGRUPOS)
									then 'Compra'
									else 
										case A.NFETIP 
											when 'T' then 'Tranferencia'
											when 'C' then 'Complemento'
											else ''
								
										end
								end 
						end
				end
		end as tipoNotaDescricao,	
		B.LESCOD as codigolocalEstoque,
		rtrim(B.PROCOD) as codigoProduto,

		sum(B.NFEQTD * B.NFEQTDEMB) as quantidade,
		sum(B.NFETOTOPEITE) as valorTotalOperacao

	INTO #NOTASENTRADAS1 FROM TBS059 A (NOLOCK) 
		INNER JOIN TBS0591 B (nolock) on A.NFEEMPCOD = B.NFEEMPCOD and A.NFECOD = B.NFECOD and A.NFENUM = B.NFENUM and A.NFETIP = B.NFETIP and A.SERCOD = B.SERCOD and A.SEREMPCOD = B.SEREMPCOD
		LEFT JOIN #NOTASAUTORIZADAS D (nolock) on A.NFENUM = D.ENFNUM and A.NFECOD = D.ENFCODDES 

	WHERE 
		(D.ENFTIPDOC = 0 OR NFENOSFOR <> 'S') AND
		A.NFECAN <> 'S' and
		A.NFEDATEFE BETWEEN @data_De AND @data_Ate AND
		B.PROCOD IN (SELECT codigoProduto FROM #CODIGOSPRODUTOS) AND 
		B.LESCOD IN (SELECT valor FROM #LOCAISEST) AND
		SUBSTRING(B.NFECFOP,3,4) IN (SELECT valor FROM #CFOPS)

	GROUP BY 
		A.NFETIP,
		A.NFECOD,
		B.LESCOD,
		B.PROCOD

--	select * from #NOTASENTRADAS1
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Agrupamento final das notas de entrada

	IF object_id('tempdb.dbo.#NOTASENTRADAS') IS NOT NULL
		DROP TABLE #NOTASENTRADAS;

	SELECT 
		tipoNota,
		tipoNotaDescricao,	
		codigolocalEstoque,
		codigoProduto,
		sum(quantidade) as quantidade,
		sum(valorTotalOperacao) as valorTotalOperacao
	INTO #NOTASENTRADAS FROM #NOTASENTRADAS1

	WHERE 
		tipoNota IN (SELECT valor FROM #TIPOSNOTAS)
	GROUP BY 
		tipoNota,
		tipoNotaDescricao,	
		codigolocalEstoque,
		codigoProduto

	-- select * from #NotasEntradas
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		A.*,
		tipoNota,
		tipoNotaDescricao,
		b.codigolocalEstoque,
		descricaoLocalEstoque,
		quantidade,
		valorTotalOperacao
	FROM #PRODUTOS A 
		INNER JOIN #NOTASENTRADAS b on A.codigoProduto = b.codigoProduto
		INNER JOIN #LOCALESTOQUE c (nolock) on b.codigolocalEstoque = c.codigoLocalEstoque
END