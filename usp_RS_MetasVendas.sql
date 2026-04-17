/*
====================================================================================================================================================================================
WREL130 - Metas de Vendas por Vendedor
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
10/04/2025 WILLIAM	
    - Uso do parametro "@ptipoDocumento = 'N'" na chamada da SP "usp_Get_DWVendas", para obter apenas registros de notas;
25/03/2025 WILLIAM
	- Correcao incluindo funcao ISNULL() no CTE(vendas_devolucoes) nos atributos de totais;
14/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
24/02/2025 WILLIAM
	- Inclusao do codigo 119, na tabela de #CFOP;
03/02/2025 WILLIAM
	- Uso da SP "usp_Get_DiasUteis";
31/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Uso da funcao "ufn_Get_Parametro" e "ufn_Get_TemFrenteLoja";
	- Uso da SP "usp_Get_CodigosVendedores", "usp_Get_CodigosClientes", "usp_Get_CodigosProdutos";
20/12/2024 WILLIAM
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor sera o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
	- Alteracao nos parametros da chamada da SP "usp_ClientesGrupo", passando o codigo da empresa @codigoEmpresa;
	- Uso da SP "usp_GetDiasUteis" em vez da "sp_DiasUteis", para usar a nova tabela de feriados FERIADOS;
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_MetasVendas_DEBUG] 
ALTER PROCEDURE [dbo].[usp_RS_MetasVendas]
	@empcod smallint,
	@mes int,
	@ano int,
	@codigoVendedor varchar(100) = '', 
	@nomeVendedor varchar(60) = '', 
	@codigoGrupoVendedores varchar(100) = '',
	@pcontabilizaDevolucao char(1) = 'S',
	@pcontabilizaHoje char(1) = 'N',
	@pGrupoBMPT char(1) = 'S'
AS 
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @nMes int,@nAno int, @VENCOD varchar (200), @VENNOM varchar(60), @GruposVendedores varchar(100),
			@contabilizaDevolucao char(1), @contabilizaHoje char(1), @GrupoBMPT char(1), 			
			@data_De datetime, @data_Ate datetime, @contabiliza char(10),
			@qtdFeriados int, @qtdDiasUteis int, @qtdDiasCorridos int, @hoje datetime, @ufEmpresaLocal char(2), @munEmpresaLocal int,
			@empresaTBS141 smallint, @empresaTBS004 smallint;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;	
	SET @nMes = @mes;
	SET @nAno = @ano;
	SET @VENCOD = RTRIM(@codigoVendedor);
	SET @VENNOM = RTRIM(@nomeVendedor);
	SET @GruposVendedores = @codigoGrupoVendedores;
	SET @contabilizaDevolucao = @pcontabilizaDevolucao;
	SET @contabilizaHoje = @pcontabilizaHoje;
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');
	
-- Atribuicoes diversas
	SET @data_De = (SELECT LTRIM(STR(@nAno)) + RIGHT(('0' + LTRIM(STR(@nMes))),2) + '01');
	SET @data_Ate = (SELECT DATEADD(DAY, -1, (DATEADD(MONTH,1, @data_De))))	;

	SET @hoje = IIF(@contabilizaHoje = 'N', GETDATE() - 1, GETDATE())

	SELECT @ufEmpresaLocal = EMPUFESIG, @munEmpresaLocal = EMPMUNCOD FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa;		

-- Uso de funcao fSplit() para uso nas clausulas IN()
	-- Grupo de vendedores
	IF OBJECT_ID('tempdb.dbo.#MV_GRUPOSVEN') IS NOT NULL
		DROP TABLE #MV_GRUPOSVEN;	
	SELECT 
		elemento AS valor
	INTO #MV_GRUPOSVEN FROM fSplit(@GruposVendedores, ',')
	IF @GruposVendedores = ''
		DELETE #MV_GRUPOSVEN;

-- Verificar se tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;	
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS141', @empresaTBS141 output;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verifico se a data selecionada esta dentro do mes
	-- se sim : Entao pego os dias uteis corridos ate hoje e depois preencho os dias uteis e feriados
	-- se nao : Entao preencho os dias uteis e feriados, depois igualo os dias corridos aos uteis, pois o mes ja acabou.

	IF MONTH(@data_De) = MONTH(GETDATE()) AND YEAR(@data_De) = YEAR(GETDATE())
	BEGIN
		-- Obtem dias uteis da nova tabela de FERIADOS
		EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @hoje, '1,7', 'S', @qtdDiasCorridos output, @qtdFeriados output
		
		EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @data_Ate, '1,7', 'S', @qtdDiasUteis output, @qtdFeriados output					
	
		SET @data_Ate = @hoje
	END 
	ELSE
	BEGIN
		EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @data_Ate, '1,7', 'S', @qtdDiasUteis output, @qtdFeriados output				
	
		SET @qtdDiasCorridos = @qtdDiasUteis
	END
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos dos vendedores via SP, incluindo codigo 0(zero)

	IF OBJECT_ID('tempdb.dbo.#CODVEN') IS NOT NULL
		DROP TABLE #CODVEN;

	CREATE TABLE #CODVEN (VENCOD INT)
	
	INSERT INTO #CODVEN
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @VENCOD, @VENNOM, 'FALSE';

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos vendedores

	IF OBJECT_ID('tempdb.dbo.#VEND') IS NOT NULL 
		DROP TABLE #VEND;

		SELECT
			VENEMPCOD,
			VENCOD,
			RTRIM(LTRIM(STR(VENCOD))) + ' - ' + RTRIM(LTRIM(VENNOM)) as VENNOM,
			A.GVECOD,
			ISNULL(RTRIM(LTRIM(STR(A.GVECOD))) + ' - ' + RTRIM(LTRIM(GVEDES)), '0 - SEM GRUPO') AS GVEDES
		INTO #VEND FROM TBS004 A (NOLOCK)
			LEFT JOIN TBS091 C (NOLOCK) ON C.GVECOD = A.GVECOD AND C.GVEEMPCOD = A.GVEEMPCOD
		WHERE 
			VENEMPCOD = @empresaTBS004 AND
			VENCOD IN(SELECT VENCOD FROM #CODVEN) AND
			A.GVECOD IN(SELECT valor FROM #MV_GRUPOSVEN) 
		UNION
		SELECT TOP 1
			VENEMPCOD,
			0,
			'0 - SEM VENDEDOR' AS VENNOM,
			0,
			'0 - SEM GRUPO' AS GVDES
		FROM TBS004 (NOLOCK)

		WHERE
			0 IN(SELECT VENCOD FROM #CODVEN) AND
			0 IN(SELECT valor FROM #MV_GRUPOSVEN)		
	
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcodigoGrupoVendedor = @codigoGrupoVendedores,
		@pcontabiliza = @contabiliza,
		@ptipoDocumento = 'N';

/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	If OBJECT_ID('tempdb.dbo.##DWDevolucaoVendas') IS NOT NULL
		DROP TABLE ##DWDevolucaoVendas;

	-- Se usuario escolheu para nao contabilizar vendas, cria apenas a estrutura da temporaria ##DWDevolucao
	SELECT TOP 0
		*
	INTO ##DWDevolucaoVendas FROM DWDevolucaoVendas;		
	
	IF @contabilizaDevolucao = 'S'
	BEGIN
		EXEC usp_Get_DWDevolucaoVendas
			@empcod = @codigoEmpresa,
			@pdataDe = @data_De,
			@pdataAte = @data_Ate,
			@pcodigoVendedor = @VENCOD,
			@pnomeVendedor = @VENNOM,
			@pcodigoGrupoVendedor = @codigoGrupoVendedores,
			@pcontabiliza = @contabiliza
	END

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para obter informacao da tabela de METAS, e contabilizar as vendas e devolucoes por vendedor;

	;WITH
		metas AS(			
		SELECT 
			A.VENEMPCOD,
			A.VENCOD, 
			B.VENNOM,
			B.GVECOD, 
			B.GVEDES,
			MDVVAL as valorMetaVendedor, 
			MDVVAL / @qtdDiasUteis as valorMetaDiaVendedor,
			MDVMARLUC as margemMetaVendedor, 
			SUM(MDVVAL) over (partition by B.GVECOD) as valorMetaGrupoVendedor,
			SUM(MDVVAL / @qtdDiasUteis) over (partition by B.GVECOD) as valorMetaDiaGrupoVendedor,
			avg(MDVMARLUC) over (partition by B.GVECOD) as margemMetaGrupoVendedor,
			SUM(MDVVAL) over () as valorMetaTotal,
			SUM(MDVVAL / @qtdDiasUteis) over () as valorMetaDiaTotal,
			avg(MDVMARLUC) over () as margemMetaTotal
		FROM TBS1411 A
			INNER JOIN #VEND B ON A.VENEMPCOD = B.VENEMPCOD AND A.VENCOD = B.VENCOD 
		WHERE
			MDVEMPCOD = @empresaTBS141 AND
			MDVANO = @nAno AND 
			MDVMES = @nMes 
		),
		-- vendas agrupados por vendedor
		vendas AS(
			SELECT
				data,			
				codigoVendedor,
				nomeVendedor,
				SUM(valorTotal) AS valorTotal,	
				SUM(custoTotal) AS custoTotal,
				SUM(valorSemDescontoIcms) AS valorSemDescontoIcms								
			FROM ##DWVendas

			GROUP BY
				data,			
				codigoVendedor,
				nomeVendedor
		),			
		-- devolucoes agrupados por vendedor
		devolucoes AS(
			SELECT
				data,
				codigoVendedor,
				nomeVendedor,
				SUM(valorTotal) AS valorTotal,	
				SUM(custoTotal) AS custoTotal,
				SUM(valorSemDescontoIcms) AS valorSemDescontoIcms
			FROM ##DWDevolucaoVendas

			GROUP BY
				data,
				codigoVendedor,
				nomeVendedor
		),
		-- Juntas as duas tabelas, vendas e devolucao, com FULL JOIN, para pegar devolucoes em dias que nao houve vendas	
		vendas_devolucoes AS(
			SELECT
				ISNULL(V.data, D.data) AS DATA,
				ISNULL(V.codigoVendedor, D.codigoVendedor) AS VENCOD,
				ISNULL(V.nomeVendedor, D.nomeVendedor) AS VENNOM,

				ISNULL(V.valorTotal, 0) AS NFSTOTITEST,	
				ISNULL(V.custoTotal, 0) AS NFSCUSITE,
				ISNULL(V.valorSemDescontoIcms, 0) AS NFSTOTITE,

				ISNULL(D.valorTotal, 0) AS NFETOTOPEITE,	
				ISNULL(D.custoTotal, 0) AS NFSCUSITEDEV,
				ISNULL(D.valorSemDescontoIcms, 0) AS NFETOTOPEITESEMST

			FROM vendas V
				FULL JOIN devolucoes D ON V.data = D.data AND V.codigoVendedor = D.codigoVendedor
		)		
		-- Tabela final
		SELECT
			@qtdDiasCorridos as diasCorridos,
			@qtdDiasUteis as diasUteis, 
			@qtdFeriados as qtdFeriados,
			@data_De as dataDe, 
			@data_Ate as dataAte,
			@hoje as diaAte,
			ISNULL(DATA, @data_De) AS DATA,
			GVECOD,
			GVEDES,
			M.VENCOD,
			M.VENNOM,
			ISNULL(valorMetaVendedor, 0) as valorMetaVendedor, 
			ISNULL(valorMetaDiaVendedor, 0) as valorMetaDiaVendedor, 
			ISNULL(margemMetaVendedor, 0) as margemMetaVendedor, 
			ISNULL(valorMetaGrupoVendedor, 0) as valorMetaGrupoVendedor, 
			ISNULL(valorMetaDiaGrupoVendedor, 0) as valorMetaDiaGrupoVendedor, 
			ISNULL(margemMetaGrupoVendedor, 0) as margemMetaGrupoVendedor, 
			ISNULL(valorMetaTotal, 0) as valorMetaTotal, 
			ISNULL(valorMetaDiaTotal, 0) as valorMetaDiaTotal, 
			ISNULL(margemMetaTotal, 0) as margemMetaTotal, 
			ISNULL(NFSTOTITEST, 0) AS NFSTOTITEST,
			ISNULL(NFSTOTITE, 0) AS NFSTOTITE, -- valorSemDescontoIcms de vendas
			ISNULL(NFETOTOPEITE, 0) AS NFETOTOPEITE,
			ISNULL(NFETOTOPEITESEMST, 0) AS NFETOTOPEITESEMST, -- valorSemDescontoIcm de devolucao
			ISNULL(NFSCUSITE, 0) AS NFSCUSITE, 	-- Custo da venda
			ISNULL(NFSCUSITEDEV, 0) AS NFSCUSITEDEV, -- custo da devolucao

			ISNULL(NFSCUSITE, 0) - ISNULL(NFSCUSITEDEV, 0) AS custoTotalLiquido,

			-- SUM(ISNULL(SomarDesconto, 0)) as SomarDesconto,
			0 AS SomarDesconto, -- ?? Verificar o impacto desse campo no RS

			CASE WHEN ISNULL(NFSTOTITEST, 0) = ISNULL(NFETOTOPEITE, 0)
				THEN 0
				ELSE
					CASE WHEN ISNULL(NFSTOTITEST, 0) > 0
						THEN ROUND( (1 - (CONVERT(DECIMAL(12,4), ISNULL(NFSCUSITE, 0) - ISNULL(NFSCUSITEDEV, 0))) / (CONVERT(DECIMAL(12,4), ISNULL(NFSTOTITE, 0) - ISNULL(NFETOTOPEITESEMST, 0))) ) * 100, 4) * CASE WHEN ISNULL(NFSTOTITEST, 0) < ISNULL(NFETOTOPEITE, 0) THEN -1 ELSE 1 END
						ELSE ROUND( (1 + (CONVERT(DECIMAL(12,4), ISNULL(NFSCUSITE, 0) - ISNULL(NFSCUSITEDEV, 0))) / (CONVERT(DECIMAL(12,4), ISNULL(NFSTOTITE, 0) - ISNULL(NFETOTOPEITESEMST, 0))) ) * -100, 4)
					END
			END AS MARGEM

		FROM metas M
			LEFT JOIN vendas_devolucoes VD ON VD.VENCOD = M.VENCOD

		ORDER BY 
			M.VENCOD;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END
GO