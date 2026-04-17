/*
====================================================================================================================================================================================
WREL152 - METAS POR GRUPO DE PRODUTOS
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
09/04/2025 WILLIAM
	- Inclusao de comando para apagar as tabelas temporarias globais ##DWVendas e ##DWDevolucaoVendas, ao final do script;
10/03/2025 WILLIAM
	- Udo da SP "usp_Get_DWVendas" e usp_Get_DWDevolucaoVendas, para obter as informacoes de vendas e devolucao de vendas, respectivamente, 
	deixando o codigo mais "limpo";
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes;
	- Retirada de codigo sem uso;
12/04/2024	WILLIAM
	- Udo da nova SP(usp_GetDiasUteis) que recebe o codigo IBGE do municipio da empresa consultando a nova tabela de feriados(dbo.FERIADOS);
09/04/2024	ANDERSON WILLIAM			
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela";
11/03/2024	ANDERSON WILLIAM			
	- Conversao para Stored procedure
	- Uso de querys dinamicas utilizando a "sp_executesql" para executar comando sql com par�metros										 
	- Uso da "usp_GetDiasUteis" em vez da "sp_DiasUteis"										
	- Uso da "usp_AlimentaDWVendas" em vez da "sp_AlimentaDWVendas"
	- Uso da "usp_AlimentaDWDevolucaoVenda" em vez da "usp_AlimentaDWDevolucaoVenda"
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_MetasGrupoProduto_DEBUG]
ALTER PROC [dbo].[usp_RS_MetasGrupoProduto]
	@empcod smallint,
	@ano smallint,
	@mes smallint,
	@codigoGrupoProdutos varchar(500),
	@contabilizaDevolucao char(1),
	@contabilizaHoje char(1)	
AS BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	declare @codigoEmpresa smallint, @data_De date, @data_Ate date, @anoatual smallint,	@mesatual smallint, @GruposProdutos varchar(500),
			@contaDevolucao char(1), @contaHoje char(1),
			@ufEmpresaLocal char(2), @munEmpresaLocal int,
			@qtdFeriados int, @qtdDiasUteis int, @qtdDiasCorridos int, @hoje datetime, @contabiliza char(1),
			@empresaTBS012 smallint, @empresaTBS145 smallint;

	-- Desativando a detecao de parametros(Parameter Sniffing)	
	SET @codigoEmpresa	= @empcod
	SET @anoatual		= @ano
	SET @mesatual		= @mes
	SET @GruposProdutos	= @codigoGrupoProdutos
	SET @contaDevolucao	= @contabilizaDevolucao
	SET @contaHoje		= @contabilizaHoje

	SET @data_De = (select ltrim(str(@anoatual)) + right(('0' + ltrim(str(@mesatual))),2) + '01') -- '20191001'
	SET @data_Ate = (select dateadd(day, -1, (dateAdd(month,1, @data_De))))
	SET @hoje = (select case when @contaHoje = 'N' then getdate() - 1 else getdate() end)

	SELECT @ufEmpresaLocal = EMPUFESIG, @munEmpresaLocal = EMPMUNCOD FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa

-- Uso da função fSplit(), para a clausula IN()
	IF OBJECT_ID('tempdb.dbo.#MV_GRUPOSPRODUTO') IS NOT NULL
		DROP TABLE #MV_GRUPOSPRODUTO;

    SELECT
		elemento as valor
	Into #MV_GRUPOSPRODUTO From fSplit(@GruposProdutos, ',')

-- Verificar se tabela compartilhada ou exclusiva			
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS012', @empresaTBS012 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS145', @empresaTBS145 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verifico se a data selecionada esta dentro do mes
	-- se sim : Entao pego os dias uteis corridos ate hoje e depois preencho os dias uteis e feriados
	-- se nao : Entao preencho os dias uteis e feriados, depois igualo os dias corridos aos uteis, pois o mes ja acabou.

	IF month(@data_De) = month(getdate()) AND year(@data_De) = year(getdate())
	BEGIN
		EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @hoje, '1', 'S',  @diasUteis = @qtdDiasCorridos output, @feriados = @qtdFeriados output
	
		EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @data_Ate, '1', 'S',  @diasUteis = @qtdDiasUteis output, @feriados = @qtdFeriados output
	
		SET @data_Ate = @hoje
	END
		ELSE
	BEGIN
		EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @data_Ate, '1', 'S', @diasUteis = @qtdDiasUteis output, @feriados = @qtdFeriados output
		SET @qtdDiasCorridos = @qtdDiasUteis
	END

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrar Grupo de produtos, para aplicar na tabela de Metas

	IF OBJECT_ID('tempdb.dbo.#GRUPOPRODUTOS') IS NOT NULL
		DROP TABLE #GRUPOPRODUTOS;

	CREATE TABLE #GRUPOPRODUTOS(
		codigoEmpresa int,
		codigo int,
		descricao varchar(20)
		)

	INSERT #GRUPOPRODUTOS

	SELECT 
		GRUEMPCOD,
		GRUCOD,
		RTRIM(GRUDES) AS GRUDES
	FROM TBS012 A (NOLOCK)

	WHERE
		A.GRUEMPCOD	= @empresaTBS012 AND 
		A.GRUCOD IN (SELECT valor FROM #MV_GRUPOSPRODUTO)
	ORDER BY 
		A.GRUEMPCOD,
		A.GRUCOD

	IF 0 in (SELECT valor FROM #MV_GRUPOSPRODUTO)
	Begin 
		INSERT #GRUPOPRODUTOS
	
		select 
			0,
			0,
			'SEM GRUPO'
	END

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoGrupoProduto = @GruposProdutos,
		@pcontabiliza = 'L'

/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	IF @contaDevolucao = 'S'
		EXEC usp_Get_DWDevolucaoVendas
			@empcod = @codigoEmpresa,
			@pdataDe = @data_De,
			@pdataAte = @data_Ate,
			@pcodigoGrupoProduto = @GruposProdutos,
			@pcontabiliza = 'L';
	ELSE	
		-- Se usuario escolheu para nao contabilizar vendas, cria apenas a estrutura da temporaria ##DWDevolucao
		SELECT TOP 0
			*
		INTO ##DWDevolucaoVendas FROM DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes

	;WITH 
		metasgrupoproduto AS(

		SELECT 
			A.MDGEMPCOD AS codigoEmpresa, 
			A.GRUCOD AS codigo,
			B.descricao,
			MDGVAL as valorMetaGrupo, 
			MDGVAL / @qtdDiasUteis as valorMetaGrupoDia,
			MDGMARLUC as margemMetaGrupo, 
			-- Caso um dia colocar os subgrupos
			/*sum(MDGVAL) over (partition by a.GRUEMPCOD, a.GRUCOD) as valorMetaGrupoVendedor,
			sum(MDGVAL / @qtdDiasUteis) over (partition by B.GVECOD) as valorMetaDiaGrupoVendedor,
			avg(MDGMARLUC) over (partition by B.GVECOD) as margemMetaGrupoVendedor,*/
			sum(MDGVAL) over () as valorMetaTotal,
			sum(MDGVAL / @qtdDiasUteis) over () as valorMetaDiaTotal,
			avg(MDGMARLUC) over () as margemMetaTotal

		FROM TBS1451 A (NOLOCK)
			INNER JOIN #GRUPOPRODUTOS B (NOLOCK) ON A.GRUCOD = B.codigo

		WHERE
			MDGEMPCOD = @empresaTBS145 AND
			MDGANO = @anoatual AND 
			MDGMES = @mesatual
		),

		-- vendas contabilizadas para a loja
		vendas AS(
			SELECT
				codigoGrupo,
				nomeGrupo AS descricao,
				SUM(valorTotal) AS valorTotalVendas,	
				SUM(custoTotal) AS custoTotalVendas,	
				SUM(valorSemDescontoIcms) AS valorSemDescontoIcmsVenda				
			FROM ##DWVendas

			WHERE 
				documentoReferenciado = ''

			GROUP BY
				codigoGrupo,
				nomeGrupo
		),

		-- vendas contabilizadas para a loja
		devolucoes AS(
			SELECT
				codigoGrupo,
				nomeGrupo AS descricao,
				SUM(valorTotal) AS valorTotalDevolucao,	
				SUM(custoTotal) AS custoTotalDevolucao,	
				SUM(valorSemDescontoIcms) AS valorSemDescontoIcmsDevolucao
			FROM ##DWDevolucaoVendas

			-- WHERE 
			-- 	documentoReferenciado = ''

			GROUP BY
				codigoGrupo,
				nomeGrupo
		)		

		-- Select final, partindo da tabel de Metas
		SELECT
			@qtdDiasCorridos AS diasCorridos,
			@qtdDiasUteis AS diasUteis, 
			@qtdFeriados AS qtdFeriados,
			@data_De AS dataDe, 
			@data_Ate AS dataAte,
			@hoje AS diaAte,

			codigo AS codigoGrupo,
			A.descricao as descricaoGrupo,
			ISNULL(valorMetaGrupo, 0) AS valorMetaGrupo, 
			ISNULL(valorMetaGrupoDia, 0) AS valorMetaGrupoDia, 
			ISNULL(margemMetaGrupo, 0) AS margemMetaGrupo, 
			ISNULL(valorMetaTotal, 0) AS valorMetaTotal, 
			ISNULL(valorMetaDiaTotal, 0) AS valorMetaDiaTotal, 
			ISNULL(margemMetaTotal, 0) AS margemMetaTotal, 
			
			ISNULL(valorTotalVendas, 0) AS valorTotalVendas,
			ISNULL(valorTotalDevolucao, 0) AS valorTotalDevolucao,
			ISNULL(valorTotalVendas, 0) - ISNULL(valorTotalDevolucao, 0) AS valorTotalLiquido,
			ISNULL(custoTotalVendas, 0) AS custoTotalVendas,
			ISNULL(custoTotalDevolucao, 0) AS custoTotalDevolucao,
			ISNULL(custoTotalVendas, 0) - ISNULL(custoTotalDevolucao, 0) AS custoTotalLiquido,
			ISNULL(valorSemDescontoIcmsVenda, 0) AS valorSemDescontoIcmsVenda,
			ISNULL(valorSemDescontoIcmsDevolucao, 0) AS valorSemDescontoIcmsDevolucao,
			ISNULL(valorSemDescontoIcmsVenda, 0) - ISNULL(valorSemDescontoIcmsDevolucao, 0) AS custoTotalLiquido,

			CASE WHEN ISNULL(valorTotalVendas, 0) = ISNULL(valorTotalDevolucao, 0)
				THEN 0
				ELSE
					CASE WHEN ISNULL(valorTotalVendas, 0) > 0
						THEN ROUND( (1 - (CONVERT(DECIMAL(12,4), ISNULL(custoTotalVendas, 0) - ISNULL(custoTotalDevolucao, 0))) / (CONVERT(DECIMAL(12,4), ISNULL(valorSemDescontoIcmsVenda, 0) - ISNULL(valorSemDescontoIcmsDevolucao, 0))) ) * 100, 4) * CASE WHEN ISNULL(valorTotalVendas, 0) < ISNULL(valorTotalDevolucao, 0) THEN -1 ELSE 1 END
						ELSE ROUND( (1 + (CONVERT(DECIMAL(12,4), ISNULL(custoTotalVendas, 0) - ISNULL(custoTotalDevolucao, 0))) / (CONVERT(DECIMAL(12,4), ISNULL(valorSemDescontoIcmsVenda, 0) - ISNULL(valorSemDescontoIcmsDevolucao, 0))) ) * -100, 4)
					END
			END AS margemlucro

		FROM metasgrupoproduto A
			LEFT JOIN vendas B ON B.codigoGrupo = codigo
			LEFT JOIN devolucoes C ON C.codigoGrupo = codigo
		
		ORDER BY
			codigo	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga tabela temporia sem uso a partir desse ponto do codigo

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------				
END